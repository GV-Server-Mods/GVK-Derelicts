// ============================================================
//  GVK DERELICTS — WEEKLY EVENT SCHEDULE
//  Edit this file to add, remove, or reschedule NPC events.
//
//  TimeUtc — new TimeSpan(hours, minutes, seconds), always UTC.
//    Examples:
//      new TimeSpan( 0,  0, 0)  =  00:00 UTC  (midnight)
//      new TimeSpan(14, 30, 0)  =  14:30 UTC  (2:30 PM UTC)
//      new TimeSpan(20,  0, 0)  =  20:00 UTC  (8:00 PM UTC)
//    To convert your local time to UTC, subtract your UTC offset.
//    e.g. US Central (UTC-6): 6:00 PM local = 00:00 UTC next day.
//
//  FireWindowMinutes — how many minutes AFTER the scheduled time
//    the event is still allowed to fire. This exists to handle
//    server downtime: if the server was offline at 18:00 but
//    comes back up at 18:07, the event still fires as long as
//    7 <= FireWindowMinutes. Once the window expires the event
//    is skipped entirely until next week.
//    Recommended: 10–30 min for servers with occasional restarts.
//    Set to 1 if you want the event to fire only on-the-dot.
//
//  SpawnCoords — world-space GPS coordinates for the spawn point.
//    In-game: Shift+F10 (admin tools) or a GPS bookmark
//    to find your coords, then paste X/Y/Z here.
//
//  SpawnGroups / SpawnEntries:
//    SpawnGroups + SpawnCoords  →  simple mode, single location,
//                                  MES picks one group at random.
//    SpawnEntries               →  each entry has its own group
//                                  AND its own dedicated coords;
//                                  the scheduler picks one at random.
//
//  BehaviorCommandCode — instead of spawning, broadcasts a command
//    code to nearby NPCs that have a CommandReceive trigger with a
//    matching CommandReceiveCode. Leave null to spawn instead.
// ============================================================

using System;
using System.Collections.Generic;
using VRageMath;

namespace GVK_Derelicts.WeeklyScheduler
{
    public static class EventSchedule
    {
        public static readonly List<ScheduledEvent> Events = new List<ScheduledEvent>
        {
            // --------------------------------------------------
            // EXAMPLE 1: Pick ONE of 5 spawn groups at random, each at its own location.
            // SpawnAllEntries = false  →  scheduler rolls the dice, only one fires.
            // --------------------------------------------------
            new ScheduledEvent
            {
                EventId           = "MondayRaiders",
                Day               = ScheduleDayOfWeek.Monday,
                TimeUtc           = new TimeSpan(18, 0, 0),
                FireWindowMinutes = 10,
                SpawnAllEntries   = false, // pick one at random
                SpawnEntries      = new List<SpawnEntry>
                {
                    new SpawnEntry { SpawnGroup = "GVK-Raider-Wave-Alpha",   SpawnCoords = new Vector3D( 12345.0,  6789.0, -1122.0) },
                    new SpawnEntry { SpawnGroup = "GVK-Raider-Wave-Bravo",   SpawnCoords = new Vector3D(-20000.0,  4500.0,  8800.0) },
                    new SpawnEntry { SpawnGroup = "GVK-Raider-Wave-Charlie", SpawnCoords = new Vector3D(  5000.0, -3000.0, 15000.0) },
                    new SpawnEntry { SpawnGroup = "GVK-Raider-Wave-Delta",   SpawnCoords = new Vector3D( 30000.0,  1200.0, -9000.0) },
                    new SpawnEntry { SpawnGroup = "GVK-Raider-Wave-Echo",    SpawnCoords = new Vector3D( -8500.0,  7700.0,  2200.0) },
                },
            },

            // --------------------------------------------------
            // EXAMPLE 2: Spawn ALL entries simultaneously, each at its own location.
            // SpawnAllEntries = true  →  every entry in the list fires at once.
            // --------------------------------------------------
            new ScheduledEvent
            {
                EventId           = "WednesdayPatrol",
                Day               = ScheduleDayOfWeek.Wednesday,
                TimeUtc           = new TimeSpan(20, 30, 0),
                FireWindowMinutes = 15,
                SpawnAllEntries   = true, // spawn every entry simultaneously
                SpawnEntries      = new List<SpawnEntry>
                {
                    new SpawnEntry { SpawnGroup = "GVK-Patrol-Group-A", SpawnCoords = new Vector3D(-5000.0, 2000.0,  8800.0) }, // [RivalAiSpawn:true]
                    new SpawnEntry { SpawnGroup = "GVK-Patrol-Group-B", SpawnCoords = new Vector3D( 7500.0, 1500.0, -3000.0) }, // [RivalAiSpawn:true]
                },
            },

            // --------------------------------------------------
            // EXAMPLE 3: Spawn one of two possible patrol groups Wednesday 20:30 UTC
            // MES picks randomly from the list.
            // --------------------------------------------------
            new ScheduledEvent
            {
                EventId           = "WednesdayPatrol",
                Day               = ScheduleDayOfWeek.Wednesday,
                TimeUtc           = new TimeSpan(20, 30, 0),
                SpawnGroups       = new List<string>
                {
                    "GVK-Patrol-Group-A",
                    "GVK-Patrol-Group-B",
                },
                SpawnCoords       = new Vector3D(-5000.0, 2000.0, 8800.0),
                SpawnForward      = new Vector3D(1, 0, 0), // optional: face east
                FireWindowMinutes = 15,
            },

            // --------------------------------------------------
            // EXAMPLE 4: Broadcast a command to existing NPCs (no new spawn)
            // Every Friday at 22:00 UTC — activates CommandReceive triggers
            // on any NPC within 15km that is listening for "WeeklyAlarmSignal".
            // --------------------------------------------------
            new ScheduledEvent
            {
                EventId              = "FridayAlarm",
                Day                  = ScheduleDayOfWeek.Friday,
                TimeUtc              = new TimeSpan(22, 0, 0),
                SpawnGroups          = new List<string>(), // empty — using command broadcast
                SpawnCoords          = new Vector3D(0.0, 0.0, 0.0), // broadcast origin
                BehaviorCommandCode  = "WeeklyAlarmSignal",
                BroadcastRange       = 15000,
                FireWindowMinutes    = 10,
            },
        };
    }
}