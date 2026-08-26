using System;
using System.Collections.Generic;
using Sandbox.ModAPI;
using VRage.Game.Components;
using VRage.Utils;
using VRageMath;

namespace GVK_Derelicts.WeeklyScheduler
{
    [MySessionComponentDescriptor(MyUpdateOrder.AfterSimulation)]
    public class WeeklySchedulerSession : MySessionComponentBase
    {
        // Sandbox variable key — persists last-fire times across server restarts
        private const string StorageKey = "GVK_WeeklyScheduler_v1";

        // Check schedule every 10 seconds (600 ticks at 60 UPS)
        private const int CheckIntervalTicks = 600;

        // Minimum hours between re-fires of the same event (prevents double-fire
        // on the same day if the server restarts within the fire window)
        private const double MinHoursBetweenFires = 160.0; // ~6.67 days

        private MesApi _mesApi;
        private Dictionary<string, DateTime> _lastFireTimes;
        private int _tickCounter;
        private bool _initialized;
        private Random _random;

        // -------------------------------------------------------

        public override void LoadData()
        {
            _lastFireTimes = new Dictionary<string, DateTime>();
            _mesApi = new MesApi();
            _random = new Random();
        }

        protected override void UnloadData()
        {
            _mesApi?.Unload();
        }

        public override void UpdateAfterSimulation()
        {
            // Server-side only
            if (MyAPIGateway.Session == null || !MyAPIGateway.Session.IsServer)
                return;

            // One-time init after session is ready
            if (!_initialized)
            {
                LoadStoredFireTimes();
                _initialized = true;
            }

            // Wait for MES API to be ready
            if (!_mesApi.MESApiReady)
                return;

            // Rate-limit schedule checks
            _tickCounter++;
            if (_tickCounter < CheckIntervalTicks)
                return;

            _tickCounter = 0;
            CheckSchedule();
        }

        // -------------------------------------------------------

        // Computes the current UTC day of week as an int (0=Sunday ... 6=Saturday)
        // using only DateTime.Ticks to avoid the prohibited System.DayOfWeek type.
        // Formula: Jan 1, 0001 was a Monday (value 1), so (daysSinceEpoch + 1) % 7
        // maps ticks to the same integer values as System.DayOfWeek.
        private static int GetUtcDayOfWeek(DateTime utcNow)
        {
            long daysSinceEpoch = utcNow.Ticks / TimeSpan.TicksPerDay;
            return (int)((daysSinceEpoch + 1L) % 7L);
        }

        private void CheckSchedule()
        {
            var now = DateTime.UtcNow;
            int todayDow = GetUtcDayOfWeek(now);

            foreach (var evt in EventSchedule.Events)
            {
                // Day-of-week filter
                if (todayDow != (int)evt.Day)
                    continue;

                // Time-of-day window filter
                var scheduledTime = now.Date + evt.TimeUtc;
                var minutesSinceScheduled = (now - scheduledTime).TotalMinutes;

                if (minutesSinceScheduled < 0 || minutesSinceScheduled > evt.FireWindowMinutes)
                    continue;

                // Prevent double-fire within the same weekly slot
                DateTime lastFire;
                if (_lastFireTimes.TryGetValue(evt.EventId, out lastFire))
                {
                    if ((now - lastFire).TotalHours < MinHoursBetweenFires)
                        continue;
                }

                FireEvent(evt, now);
            }
        }

        private void FireEvent(ScheduledEvent evt, DateTime fireTime)
        {
            MyLog.Default.WriteLineAndConsole(
                "[GVK WeeklyScheduler] Firing event: " + evt.EventId +
                " at " + fireTime.ToString("u"));

            if (!string.IsNullOrEmpty(evt.BehaviorCommandCode))
            {
                // Broadcast a command code — activates CommandReceive triggers on nearby NPCs
                _mesApi.SendBehaviorCommand(
                    new List<string> { evt.BehaviorCommandCode },
                    evt.SpawnCoords,
                    "",    // empty = any faction
                    evt.BroadcastRange,
                    -1L);
            }
            else if (evt.SpawnEntries.Count > 0)
            {
                if (evt.SpawnAllEntries)
                {
                    // Spawn every entry simultaneously
                    foreach (var entry in evt.SpawnEntries)
                    {
                        SpawnEntry(entry, evt.EventId);
                    }
                }
                else
                {
                    // Pick one entry at random
                    var entry = evt.SpawnEntries[_random.Next(evt.SpawnEntries.Count)];
                    SpawnEntry(entry, evt.EventId);
                }
            }
            else if (evt.SpawnGroups.Count > 0)
            {
                // Legacy: single coords, MES picks group from the list
                var forward = evt.SpawnForward != Vector3D.Zero ? evt.SpawnForward : Vector3D.Forward;
                var up      = evt.SpawnUp      != Vector3D.Zero ? evt.SpawnUp      : Vector3D.Up;
                var matrix  = MatrixD.CreateWorld(evt.SpawnCoords, forward, up);

                _mesApi.CustomSpawnRequest(
                    evt.SpawnGroups,
                    matrix,
                    Vector3.Zero,
                    false,
                    null,
                    "GVK_WeeklyScheduler");
            }
            else
            {
                MyLog.Default.WriteLineAndConsole(
                    "[GVK WeeklyScheduler] WARNING: Event '" + evt.EventId +
                    "' has no SpawnEntries, no SpawnGroups, and no BehaviorCommandCode — nothing to do.");
                return;
            }

            // Record the fire time and persist
            _lastFireTimes[evt.EventId] = fireTime;
            SaveFireTimes();
        }

        private void SpawnEntry(SpawnEntry entry, string eventId)
        {
            var forward = entry.SpawnForward != Vector3D.Zero ? entry.SpawnForward : Vector3D.Forward;
            var up      = entry.SpawnUp      != Vector3D.Zero ? entry.SpawnUp      : Vector3D.Up;
            var matrix  = MatrixD.CreateWorld(entry.SpawnCoords, forward, up);

            MyLog.Default.WriteLineAndConsole(
                "[GVK WeeklyScheduler]   -> Spawning entry: " + entry.SpawnGroup +
                " (event: " + eventId + ")");

            _mesApi.CustomSpawnRequest(
                new List<string> { entry.SpawnGroup },
                matrix,
                Vector3.Zero,
                false,
                null,
                "GVK_WeeklyScheduler");
        }

        // -------------------------------------------------------
        // Format: "EventId|ticks;EventId|ticks;..."
        // -------------------------------------------------------

        private void LoadStoredFireTimes()
        {
            string data;
            if (!MyAPIGateway.Utilities.GetVariable(StorageKey, out data) || string.IsNullOrEmpty(data))
                return;

            var entries = data.Split(';');
            foreach (var entry in entries)
            {
                if (string.IsNullOrEmpty(entry)) continue;
                var parts = entry.Split('|');
                if (parts.Length != 2) continue;

                long ticks;
                if (long.TryParse(parts[1], out ticks))
                    _lastFireTimes[parts[0]] = new DateTime(ticks, DateTimeKind.Utc);
            }

            MyLog.Default.WriteLineAndConsole(
                "[GVK WeeklyScheduler] Loaded " + _lastFireTimes.Count + " stored fire time(s).");
        }

        private void SaveFireTimes()
        {
            var parts = new List<string>();
            foreach (var kv in _lastFireTimes)
                parts.Add(kv.Key + "|" + kv.Value.Ticks.ToString());

            MyAPIGateway.Utilities.SetVariable(StorageKey, string.Join(";", parts));
        }
    }
}