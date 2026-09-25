using System;
using System.Collections.Generic;
using Sandbox.ModAPI;
using VRage.Game.ModAPI;
using VRage.ModAPI;
using VRage.Utils;
using VRageMath;

namespace GVK_Derelicts.WeeklyScheduler
{
    /// <summary>
    /// Minimal MES API wrapper — only exposes what the WeeklyScheduler needs.
    /// Sourced from MESReferences/Data/Scripts/ModularEncountersSystems/API/MESApi.cs
    /// </summary>
    public class MesApi
    {
        public bool MESApiReady { get; private set; }

        private const long MesModId = 1521905890;

        private Func<List<string>, MatrixD, Vector3, bool, string, string, bool> _customSpawnRequest;
        private Action<List<string>, Vector3D, string, double, long>             _sendBehaviorCommand;

        public MesApi()
        {
            MyAPIGateway.Utilities.RegisterMessageHandler(MesModId, ApiListener);
        }

        public void Unload()
        {
            MyAPIGateway.Utilities.UnregisterMessageHandler(MesModId, ApiListener);
        }

        /// <summary>
        /// Spawns a random SpawnGroup from the provided list at the given matrix.
        /// SpawnGroup must have [RivalAiSpawn:true] in its conditions.
        /// </summary>
        public bool CustomSpawnRequest(
            List<string> spawnGroups,
            MatrixD      spawningMatrix,
            Vector3      velocity,
            bool         ignoreSafetyCheck,
            string       factionOverride,
            string       spawnProfileId)
        {
            return _customSpawnRequest?.Invoke(
                spawnGroups, spawningMatrix, velocity,
                ignoreSafetyCheck, factionOverride, spawnProfileId) ?? false;
        }

        /// <summary>
        /// Broadcasts a command code to all MES NPCs within range that have a
        /// CommandReceive trigger listening for the matching code.
        /// </summary>
        public void SendBehaviorCommand(
            List<string> commandCodes,
            Vector3D     broadcastPosition,
            string       senderFactionTag,
            double       broadcastRange,
            long         senderIdentityId)
        {
            _sendBehaviorCommand?.Invoke(
                commandCodes, broadcastPosition,
                senderFactionTag, broadcastRange, senderIdentityId);
        }

        private void ApiListener(object data)
        {
            try
            {
                var dict = data as Dictionary<string, Delegate>;
                if (dict == null) return;

                MESApiReady         = true;
                _customSpawnRequest = (Func<List<string>, MatrixD, Vector3, bool, string, string, bool>)dict["CustomSpawnRequest"];
                _sendBehaviorCommand = (Action<List<string>, Vector3D, string, double, long>)dict["SendBehaviorCommand"];
            }
            catch (Exception e)
            {
                MyLog.Default.WriteLineAndConsole("[GVK WeeklyScheduler] MES API failed to load: " + e.Message);
            }
        }
    }
}