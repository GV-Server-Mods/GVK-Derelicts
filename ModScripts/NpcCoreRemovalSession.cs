using System;
using System.Collections.Generic;
using Sandbox.ModAPI;
using VRage.Game.Components;
using VRage.Game.ModAPI;
using VRage.ModAPI;
using VRage.Utils;
using VRageMath;

namespace GVK_Derelicts.NpcCoreRemoval
{
    /// <summary>
    /// Removes the core beacons of a defeated NPC, so Ship Core's no-core limits reach the wreck
    /// (GVK-Settings#786; design: Docs/design/npc-core-removal.md, note 49).
    /// MES reports every RivalAI action just before it runs. When GVK-Universal-Action-Disabled runs,
    /// the grid is queued; a few ticks later, in this component's own update on the game thread, every
    /// NPC-owned core beacon in the grid's mechanical group, and in the pieces split off the same original
    /// grid, is removed. MES sends that report from inside
    /// the game's damage, grind and close callbacks, so the handler only queues and never throws.
    /// </summary>
    [MySessionComponentDescriptor(MyUpdateOrder.AfterSimulation)]
    public class NpcCoreRemovalSession : MySessionComponentBase
    {
        // MES mod id: MES sends its API dictionary to this message handler id once, at BeforeStart
        private const long MesModId = 1521905890;

        // GVK's defeat action (GVK-Universal-Behavior.sbc); static encounters never run it
        private const string DefeatActionId = "GVK-Universal-Action-Disabled";

        // Wait 10 ticks (~0.17 s at 60 UPS) after the action, so it and MES's own work finish first
        private const int DelayTicks = 10;

        private const string LogPrefix = "[GVK NpcCoreRemoval] ";

        // Every Ship Core core subtype in the GVK pack (GVK_ShipCoreFramework Content/Data/*_core.xml).
        // Zone beacons (ZoneBlock, DrillBlocker, LimitedProdZone, GVK_No*Zone) and cargo scanners are not cores.
        private static readonly HashSet<string> CoreSubtypes = new HashSet<string>
        {
            "LargeBlockBeacon_NPC", "SmallBlockBeacon_NPC",
            "LargeBlockBeacon_NPCNoConceal", "SmallBlockBeacon_NPCNoConceal",
            "DisposableNpcBeaconLarge", "DisposableNpcBeaconSmall",
            "LargeBlockBeacon", "SmallBlockBeacon",
            "LargeBlockBeacon_Scrap", "SmallBlockBeacon_Scrap",
            "LargeBlockBeacon_MediumCore", "LargeBlockBeacon_HeavyCore", "LargeBlockBeacon_Fortress",
            "LargeBlockBeacon_Pipeline", "LargeBlockBeacon_ShieldCore", "LargeBlockBeacon_SupportCore",
        };

        // Grid id -> tick it was queued. Written by the MES handler (any thread), read in the update.
        private readonly object _queueLock = new object();
        private readonly Dictionary<long, int> _queued = new Dictionary<long, int>();
        private int _tick;

        // Split pieces: piece grid id -> id of the grid it first split from. After a split MES follows
        // the piece holding the remote, so the beacons may be on another piece of the same NPC.
        // Split and close events can come from a worker thread, so these are under _queueLock too.
        private readonly Dictionary<long, long> _splitRoot = new Dictionary<long, long>();
        private readonly HashSet<long> _splitWatched = new HashSet<long>();

        // Reusable collections (game thread only)
        private readonly List<long> _due = new List<long>();
        private readonly List<long> _family = new List<long>();
        private readonly List<IMyCubeGrid> _group = new List<IMyCubeGrid>();
        private readonly HashSet<IMyCubeGrid> _seenGrids = new HashSet<IMyCubeGrid>();
        private readonly List<IMySlimBlock> _blocks = new List<IMySlimBlock>();
        private readonly List<IMySlimBlock> _toRemove = new List<IMySlimBlock>();

        private Action<bool, Action<IMyRemoteControl, string, string, IMyEntity, Vector3D>> _registerWatcher;
        private Action<IMyRemoteControl, string, string, IMyEntity, Vector3D> _actionHandler;
        private Action<IMyCubeGrid, IMyCubeGrid> _splitHandler;
        private Action<IMyEntity> _closeHandler;
        private Func<IMySlimBlock, bool> _isNpcCore;
        private bool _isServer;
        private bool _watching;
        private bool _scannedExistingGrids;

        public override void LoadData()
        {
            _isServer = MyAPIGateway.Session != null && MyAPIGateway.Session.IsServer;
            if (!_isServer)
                return;

            _actionHandler = OnActionRun;
            _splitHandler = OnGridSplit;
            _closeHandler = OnGridClose;
            _isNpcCore = IsNpcCore;
            MyAPIGateway.Utilities.RegisterMessageHandler(MesModId, OnMesMessage);
            MyAPIGateway.Entities.OnEntityAdd += OnEntityAdd;
        }

        protected override void UnloadData()
        {
            if (!_isServer)
                return;

            MyAPIGateway.Utilities.UnregisterMessageHandler(MesModId, OnMesMessage);
            MyAPIGateway.Entities.OnEntityAdd -= OnEntityAdd;

            // The MES watcher is a static event, so it outlives this world unless it is removed
            if (_watching)
            {
                try
                {
                    _registerWatcher(false, _actionHandler);
                }
                catch (Exception e)
                {
                    MyLog.Default.WriteLineAndConsole(LogPrefix + "Could not unregister from MES: " + e.Message);
                }
            }

            _watching = false;
            lock (_queueLock)
            {
                _queued.Clear();
                _splitRoot.Clear();
                _splitWatched.Clear();
            }
        }

        public override void UpdateAfterSimulation()
        {
            if (!_isServer)
                return;

            // Grids loaded with the world may have been added before OnEntityAdd was hooked
            if (!_scannedExistingGrids)
            {
                _scannedExistingGrids = true;
                var existing = new HashSet<IMyEntity>();
                MyAPIGateway.Entities.GetEntities(existing, e => e is IMyCubeGrid);
                foreach (var entity in existing)
                    WatchGrid(entity as IMyCubeGrid);
            }

            lock (_queueLock)
            {
                _tick++;
                if (_queued.Count == 0)
                    return;

                foreach (var pair in _queued)
                {
                    if (_tick - pair.Value >= DelayTicks)
                        _due.Add(pair.Key);
                }

                foreach (long id in _due)
                    _queued.Remove(id);
            }

            foreach (long id in _due)
            {
                try
                {
                    RemoveCores(id);
                }
                catch (Exception e)
                {
                    MyLog.Default.WriteLineAndConsole(LogPrefix + "Failed on grid " + id + ": " + e);
                }
            }

            _due.Clear();
        }

        // MES API delivery (server only, once at MES BeforeStart)
        private void OnMesMessage(object data)
        {
            try
            {
                var dict = data as Dictionary<string, Delegate>;
                if (dict == null || _watching)
                    return;

                Delegate register;
                if (!dict.TryGetValue("BehaviorTriggerActivationWatcher", out register))
                {
                    MyLog.Default.WriteLineAndConsole(LogPrefix + "WARNING: this MES build has no BehaviorTriggerActivationWatcher; defeated NPCs keep their cores.");
                    return;
                }

                _registerWatcher = register as Action<bool, Action<IMyRemoteControl, string, string, IMyEntity, Vector3D>>;
                if (_registerWatcher == null)
                {
                    MyLog.Default.WriteLineAndConsole(LogPrefix + "WARNING: MES BehaviorTriggerActivationWatcher has an unexpected type; defeated NPCs keep their cores.");
                    return;
                }

                _registerWatcher(true, _actionHandler);
                _watching = true;
                MyLog.Default.WriteLineAndConsole(LogPrefix + "Watching for " + DefeatActionId + ".");
            }
            catch (Exception e)
            {
                MyLog.Default.WriteLineAndConsole(LogPrefix + "MES API failed to load: " + e.Message);
            }
        }

        // Called by MES just before each RivalAI action runs, often inside a game callback and
        // possibly off the game thread: only queue the grid id here.
        private void OnActionRun(IMyRemoteControl remote, string triggerId, string actionId, IMyEntity target, Vector3D waypoint)
        {
            try
            {
                if (actionId != DefeatActionId || remote == null)
                    return;

                var grid = remote.CubeGrid;
                if (grid == null)
                    return;

                long id = grid.EntityId;
                lock (_queueLock)
                {
                    // Keep the first time: the 2-second Timer triggers run Disabled again and again
                    if (!_queued.ContainsKey(id))
                        _queued[id] = _tick;
                }
            }
            catch
            {
                // An exception here would stop MES's own actions for this NPC, so it is swallowed
            }
        }

        private void OnEntityAdd(IMyEntity entity)
        {
            WatchGrid(entity as IMyCubeGrid);
        }

        private void WatchGrid(IMyCubeGrid grid)
        {
            if (grid == null)
                return;

            lock (_queueLock)
            {
                if (!_splitWatched.Add(grid.EntityId))
                    return;
            }

            grid.OnGridSplit += _splitHandler;
            grid.OnClose += _closeHandler;
        }

        // Only records ids: split events come from the engine's disconnect check, possibly off the game thread
        private void OnGridSplit(IMyCubeGrid original, IMyCubeGrid piece)
        {
            try
            {
                if (original == null || piece == null)
                    return;

                lock (_queueLock)
                {
                    long root;
                    if (!_splitRoot.TryGetValue(original.EntityId, out root))
                        root = original.EntityId;
                    _splitRoot[piece.EntityId] = root;
                }
            }
            catch
            {
                // Never let an exception escape into the engine's split handling
            }
        }

        private void OnGridClose(IMyEntity entity)
        {
            try
            {
                entity.OnClose -= _closeHandler;
                var grid = entity as IMyCubeGrid;
                if (grid != null)
                    grid.OnGridSplit -= _splitHandler;

                lock (_queueLock)
                {
                    _splitWatched.Remove(entity.EntityId);
                    _splitRoot.Remove(entity.EntityId);
                }
            }
            catch
            {
                // Never let an exception escape into the entity close
            }
        }

        private void RemoveCores(long gridId)
        {
            var grid = MyAPIGateway.Entities.GetEntityById(gridId) as IMyCubeGrid;
            if (grid == null || grid.MarkedForClose || grid.Closed)
                return;

            string gridName = grid.CustomName;

            // The defeated grid plus every piece split from the same original grid
            _family.Clear();
            lock (_queueLock)
            {
                long root;
                if (!_splitRoot.TryGetValue(gridId, out root))
                    root = gridId;

                _family.Add(root);
                foreach (var pair in _splitRoot)
                {
                    if (pair.Value == root)
                        _family.Add(pair.Key);
                }
            }

            if (!_family.Contains(gridId))
                _family.Add(gridId);

            // Collect first, remove after: never remove blocks while a grid is being enumerated
            _seenGrids.Clear();
            _toRemove.Clear();
            foreach (long id in _family)
            {
                var piece = MyAPIGateway.Entities.GetEntityById(id) as IMyCubeGrid;
                if (piece == null || piece.MarkedForClose || piece.Closed)
                    continue;

                _group.Clear();
                MyAPIGateway.GridGroups.GetGroup(piece, GridLinkTypeEnum.Mechanical, _group);
                if (_group.Count == 0)
                    _group.Add(piece);

                foreach (var member in _group)
                {
                    if (member == null || member.MarkedForClose || member.Closed || !_seenGrids.Add(member))
                        continue;

                    _blocks.Clear();
                    member.GetBlocks(_blocks, _isNpcCore);
                    _toRemove.AddRange(_blocks);
                }
            }

            _blocks.Clear();
            _group.Clear();
            _seenGrids.Clear();
            _family.Clear();

            // All in one tick. Ship Core handles each removal as it happens (it may promote a remaining
            // beacon for a moment); after the last one it has no core left and applies the no-core profile.
            int removed = 0;
            foreach (var slim in _toRemove)
            {
                var owner = slim.CubeGrid;
                if (owner == null || owner.MarkedForClose || owner.Closed || owner.GetCubeBlock(slim.Min) != slim)
                    continue;

                // updatePhysics true keeps the server's collision in step; it needs a physics body
                owner.RemoveBlock(slim, owner.Physics != null);
                removed++;
            }

            _toRemove.Clear();

            if (removed > 0)
                MyLog.Default.WriteLineAndConsole(LogPrefix + "Removed " + removed + " core beacon(s) from defeated NPC '" + gridName + "' (" + gridId + ").");
        }

        private static bool IsNpcCore(IMySlimBlock slim)
        {
            var block = slim.FatBlock;
            if (block == null || block.MarkedForClose)
                return false;

            return CoreSubtypes.Contains(block.BlockDefinition.SubtypeName) && IsNpcIdentity(block.OwnerId);
        }

        // Same test MES uses for an NPC owner: no Steam id, and a faction made only of NPCs
        private static bool IsNpcIdentity(long identityId)
        {
            if (identityId == 0 || MyAPIGateway.Players.TryGetSteamId(identityId) != 0)
                return false;

            var faction = MyAPIGateway.Session.Factions.TryGetPlayerFaction(identityId);
            return faction != null && faction.IsEveryoneNpc();
        }
    }
}
