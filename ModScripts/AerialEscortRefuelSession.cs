using System;
using System.Collections.Generic;
using Sandbox.Definitions;
using Sandbox.Game;
using Sandbox.Game.Entities;
using Sandbox.ModAPI;
using VRage.Game;
using VRage.Game.Components;
using VRage.Game.Entity;
using VRage.Game.ModAPI;
using VRage.ModAPI;
using VRageMath;

namespace GVK_Derelicts.AerialRefueling
{
    [MySessionComponentDescriptor(MyUpdateOrder.BeforeSimulation)]
    public class AerialEscortRefuelSession : MySessionComponentBase
    {
        // Stepped tick interval: 300 ticks = ~5.0 seconds at 60 UPS
        private const int CheckIntervalTicks = 300;

        // Refuel tether radius around the escort
        private const double RefuelRadius = 500.0;
        private const double RefuelRadiusSq = RefuelRadius * RefuelRadius;

        // In-flight trickle rate per 5-second step (+5% per cycle = 100% in ~100s)
        private const double TrickleFillRatio = 0.05;

        // Notification cooldown per player: 60 seconds (prevents boundary spam)
        private const int NotifyCooldownSeconds = 60;

        // RemoteControl code used by Coalition Route E aerial escort
        private const string EscortRemoteControlCode = "COALITIONRouteE";

        // Behavior subtype ID of the Route E aerial escort
        private const string EscortBehaviorSubtype = "GVK-CargoShip-Air-COALITION-Behavior-EscortE";

        // Beacon substring fallback for aerial escorts
        private const string EscortBeaconIdentifier = "Aerial Escort";

        // CustomName tag allowing any grid to act as an aerial tanker
        private const string EscortRefuelTag = "[GVK-AerialRefueling]";

        // Tracked active escort grids in the world
        private readonly List<IMyCubeGrid> _trackedEscorts = new List<IMyCubeGrid>();

        // Reusable query and block collections (zero GC allocation in simulation)
        private readonly List<MyEntity> _nearbyEntities = new List<MyEntity>();
        private readonly List<IMySlimBlock> _gridBlocks = new List<IMySlimBlock>();
        private readonly List<IMySlimBlock> _escortScanBlocks = new List<IMySlimBlock>();
        private readonly List<IMyPlayer> _players = new List<IMyPlayer>();
        private readonly HashSet<IMyEntity> _scanBuffer = new HashSet<IMyEntity>();
        private readonly List<long> _pruneKeysBuffer = new List<long>();

        // Notification timestamp tracking per player identity
        private readonly Dictionary<long, DateTime> _lastNotifyTimes = new Dictionary<long, DateTime>();

        private int _tickCounter;
        private int _coldScanCounter;
        private bool _isServer;

        public override void LoadData()
        {
            _isServer = MyAPIGateway.Session != null && MyAPIGateway.Session.IsServer;
            if (!_isServer)
                return;

            MyEntities.OnEntityAdd += OnEntityAdded;
            MyEntities.OnEntityRemove += OnEntityRemoved;
        }

        protected override void UnloadData()
        {
            if (_isServer)
            {
                MyEntities.OnEntityAdd -= OnEntityAdded;
                MyEntities.OnEntityRemove -= OnEntityRemoved;
            }

            _trackedEscorts.Clear();
            _nearbyEntities.Clear();
            _gridBlocks.Clear();
            _escortScanBlocks.Clear();
            _players.Clear();
            _scanBuffer.Clear();
            _pruneKeysBuffer.Clear();
            _lastNotifyTimes.Clear();
        }

        public override void UpdateBeforeSimulation()
        {
            if (!_isServer)
                return;

            // Only run every 300 ticks (~5.0 seconds)
            if (++_tickCounter < CheckIntervalTicks)
                return;

            _tickCounter = 0;

            // Cold-path maintenance every 600 ticks (~10s)
            if (++_coldScanCounter >= 2)
            {
                _coldScanCounter = 0;
                DateTime checkTime = DateTime.UtcNow;
                PruneExpiredNotifications(checkTime);

                if (_trackedEscorts.Count == 0)
                {
                    ScanForEscorts();
                }
            }

            if (_trackedEscorts.Count == 0)
                return;

            DateTime now = DateTime.UtcNow;

            for (int e = _trackedEscorts.Count - 1; e >= 0; e--)
            {
                IMyCubeGrid escort = _trackedEscorts[e];
                if (escort == null || escort.Closed || escort.MarkedForClose)
                {
                    _trackedEscorts.RemoveAt(e);
                    continue;
                }

                ProcessEscortRefueling(escort, now);
            }
        }

        private void ProcessEscortRefueling(IMyCubeGrid escort, DateTime now)
        {
            Vector3D escortPos = escort.PositionComp.GetPosition();
            BoundingSphereD sphere = new BoundingSphereD(escortPos, RefuelRadius);

            _nearbyEntities.Clear();
            MyGamePruningStructure.GetAllTopMostEntitiesInSphere(ref sphere, _nearbyEntities);

            for (int i = 0; i < _nearbyEntities.Count; i++)
            {
                IMyCubeGrid targetGrid = _nearbyEntities[i] as IMyCubeGrid;
                if (targetGrid == null || targetGrid == escort || targetGrid.Closed || targetGrid.MarkedForClose)
                    continue;

                // Squared distance check
                if (Vector3D.DistanceSquared(targetGrid.PositionComp.GetPosition(), escortPos) > RefuelRadiusSq)
                    continue;

                // Do not refuel enemy grids (e.g. hostile Gaalsien raiders)
                if (IsHostileToEscort(escort, targetGrid))
                    continue;

                // Refuel hydrogen tanks on target grid
                RefuelGridHydrogenTanks(targetGrid);
            }
            _nearbyEntities.Clear();

            // Refuel suits and send enter HUD notification for players physically within 500m
            RefuelAndNotifyPlayers(escort, escortPos, now);
        }

        private bool RefuelGridHydrogenTanks(IMyCubeGrid grid)
        {
            bool anyRefueled = false;
            _gridBlocks.Clear();
            grid.GetBlocks(_gridBlocks);

            for (int b = 0; b < _gridBlocks.Count; b++)
            {
                IMySlimBlock slim = _gridBlocks[b];
                if (slim.FatBlock == null)
                    continue;

                IMyGasTank tank = slim.FatBlock as IMyGasTank;
                if (tank == null || tank.Closed || tank.MarkedForClose || !tank.IsWorking)
                    continue;

                // Verify the tank is configured for Hydrogen
                MyGasTankDefinition tankDef = MyDefinitionManager.Static.GetCubeBlockDefinition(tank.BlockDefinition) as MyGasTankDefinition;
                if (tankDef == null || tankDef.StoredGasId.SubtypeName != "Hydrogen")
                    continue;

                if (tank.FilledRatio < 1.0)
                {
                    double newRatio = Math.Min(1.0, tank.FilledRatio + TrickleFillRatio);
                    tank.ChangeFilledRatio(newRatio, true);
                    anyRefueled = true;
                }
            }
            _gridBlocks.Clear();

            return anyRefueled;
        }

        private void RefuelAndNotifyPlayers(IMyCubeGrid escort, Vector3D escortPos, DateTime now)
        {
            _players.Clear();
            MyAPIGateway.Multiplayer.Players.GetPlayers(_players);

            long escortOwner = (escort.BigOwners != null && escort.BigOwners.Count > 0) ? escort.BigOwners[0] : 0L;

            for (int p = 0; p < _players.Count; p++)
            {
                IMyPlayer player = _players[p];
                if (player == null || player.Character == null)
                    continue;

                // Distance check: must be physically within 500m of the escort
                Vector3D playerPos = player.GetPosition();
                if (Vector3D.DistanceSquared(playerPos, escortPos) > RefuelRadiusSq)
                    continue;

                // Check relations: do not refuel or notify enemies
                if (escortOwner != 0L)
                {
                    MyRelationsBetweenPlayers relation = MyIDModule.GetRelationPlayerPlayer(escortOwner, player.IdentityId);
                    if (relation == MyRelationsBetweenPlayers.Enemies)
                        continue;
                }

                // Top off suit jetpack while connected to aerial refueler
                MyVisualScriptLogicProvider.SetPlayersHydrogenLevel(player.IdentityId, 1.0f);

                // Send enter notification if cooldown elapsed (prevents boundary flutter spam)
                DateTime lastNotify;
                if (!_lastNotifyTimes.TryGetValue(player.IdentityId, out lastNotify) ||
                    (now - lastNotify).TotalSeconds >= NotifyCooldownSeconds)
                {
                    _lastNotifyTimes[player.IdentityId] = now;
                    MyVisualScriptLogicProvider.ShowNotification(
                        "[Escort] In-Flight Refueling Connected (+5% H2)",
                        4000,
                        "Green",
                        player.IdentityId);
                }
            }
            _players.Clear();
        }

        private static bool IsHostileToEscort(IMyCubeGrid escort, IMyCubeGrid target)
        {
            if (escort.BigOwners == null || escort.BigOwners.Count == 0 ||
                target.BigOwners == null || target.BigOwners.Count == 0)
                return false;

            long escortOwner = escort.BigOwners[0];
            long targetOwner = target.BigOwners[0];

            MyRelationsBetweenPlayers relation = MyIDModule.GetRelationPlayerPlayer(escortOwner, targetOwner);
            return relation == MyRelationsBetweenPlayers.Enemies;
        }

        private void ScanForEscorts()
        {
            _scanBuffer.Clear();
            MyAPIGateway.Entities.GetEntities(_scanBuffer);

            foreach (IMyEntity entity in _scanBuffer)
            {
                IMyCubeGrid grid = entity as IMyCubeGrid;
                if (grid != null && IsEscortGrid(grid) && !_trackedEscorts.Contains(grid))
                {
                    _trackedEscorts.Add(grid);
                }
            }

            _scanBuffer.Clear();
        }

        private void OnEntityAdded(IMyEntity entity)
        {
            IMyCubeGrid grid = entity as IMyCubeGrid;
            if (grid == null)
                return;

            if (IsEscortGrid(grid) && !_trackedEscorts.Contains(grid))
            {
                _trackedEscorts.Add(grid);
            }
        }

        private void OnEntityRemoved(IMyEntity entity)
        {
            IMyCubeGrid grid = entity as IMyCubeGrid;
            if (grid == null)
                return;

            _trackedEscorts.Remove(grid);
        }

        private bool IsEscortGrid(IMyCubeGrid grid)
        {
            if (grid == null || grid.Closed || grid.MarkedForClose)
                return false;

            // Check CustomName tag or Carryall prefab name
            if (grid.CustomName != null)
            {
                if (grid.CustomName.IndexOf(EscortRefuelTag, StringComparison.OrdinalIgnoreCase) >= 0 ||
                    grid.CustomName.IndexOf("Carryall", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    return true;
                }
            }

            // Check blocks for Remote Control code or Beacon name
            _escortScanBlocks.Clear();
            grid.GetBlocks(_escortScanBlocks);

            for (int i = 0; i < _escortScanBlocks.Count; i++)
            {
                IMySlimBlock slim = _escortScanBlocks[i];
                if (slim.FatBlock == null)
                    continue;

                // Check Remote Control for escort code or behavior subtype
                IMyRemoteControl rc = slim.FatBlock as IMyRemoteControl;
                if (rc != null)
                {
                    if (rc.CustomData != null && (
                        rc.CustomData.IndexOf(EscortRemoteControlCode, StringComparison.OrdinalIgnoreCase) >= 0 ||
                        rc.CustomData.IndexOf(EscortBehaviorSubtype, StringComparison.OrdinalIgnoreCase) >= 0))
                    {
                        _escortScanBlocks.Clear();
                        return true;
                    }

                    if (rc.CustomName != null && (
                        rc.CustomName.IndexOf(EscortRemoteControlCode, StringComparison.OrdinalIgnoreCase) >= 0 ||
                        rc.CustomName.IndexOf(EscortBehaviorSubtype, StringComparison.OrdinalIgnoreCase) >= 0))
                    {
                        _escortScanBlocks.Clear();
                        return true;
                    }
                }

                // Check Beacon for "Aerial Escort" name
                IMyBeacon beacon = slim.FatBlock as IMyBeacon;
                if (beacon != null)
                {
                    if (beacon.CustomName != null && beacon.CustomName.IndexOf(EscortBeaconIdentifier, StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        _escortScanBlocks.Clear();
                        return true;
                    }

                    if (beacon.HudText != null && beacon.HudText.IndexOf(EscortBeaconIdentifier, StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        _escortScanBlocks.Clear();
                        return true;
                    }
                }
            }

            _escortScanBlocks.Clear();
            return false;
        }

        private void PruneExpiredNotifications(DateTime now)
        {
            _pruneKeysBuffer.Clear();

            foreach (KeyValuePair<long, DateTime> kvp in _lastNotifyTimes)
            {
                if ((now - kvp.Value).TotalSeconds > NotifyCooldownSeconds * 2)
                {
                    _pruneKeysBuffer.Add(kvp.Key);
                }
            }

            for (int i = 0; i < _pruneKeysBuffer.Count; i++)
            {
                _lastNotifyTimes.Remove(_pruneKeysBuffer[i]);
            }

            _pruneKeysBuffer.Clear();
        }
    }
}

