using System;
using System.Collections.Generic;
using VRageMath;

namespace GVK_Derelicts.WeeklyScheduler
{
    /// <summary>
    /// Mirrors System.DayOfWeek values (Sunday=0 ... Saturday=6) but defined
    /// in our namespace to avoid the SE prohibited-type restriction.
    /// </summary>
    public enum ScheduleDayOfWeek
    {
        Sunday    = 0,
        Monday    = 1,
        Tuesday   = 2,
        Wednesday = 3,
        Thursday  = 4,
        Friday    = 5,
        Saturday  = 6,
    }

    /// <summary>
    /// Pairs a SpawnGroup SubtypeId with its own dedicated spawn location.
    /// Used in ScheduledEvent.SpawnEntries for per-group coordinate control.
    /// </summary>
    public class SpawnEntry
    {
        /// <summary>SpawnGroup SubtypeId. Must have [RivalAiSpawn:true] in its SpawnConditions profile.</summary>
        public string SpawnGroup;

        /// <summary>World-space coordinates this group spawns at.</summary>
        public Vector3D SpawnCoords;

        /// <summary>Optional forward direction. Defaults to Vector3D.Forward if Zero.</summary>
        public Vector3D SpawnForward = Vector3D.Zero;

        /// <summary>Optional up direction. Defaults to Vector3D.Up if Zero.</summary>
        public Vector3D SpawnUp = Vector3D.Zero;
    }

    public class ScheduledEvent
    {
        /// <summary>Unique ID used for persistence. Never change this after first use.</summary>
        public string EventId;

        /// <summary>UTC day of week to fire on.</summary>
        public ScheduleDayOfWeek Day;

        /// <summary>UTC time of day to fire at, e.g. new TimeSpan(18, 0, 0) = 18:00 UTC.</summary>
        public TimeSpan TimeUtc;

        /// <summary>
        /// List of SpawnGroup SubtypeIds to pick from (MES picks one randomly).
        /// SpawnGroups must have [RivalAiSpawn:true] in their SpawnConditions profile.
        /// Leave empty if using BehaviorCommandCode instead.
        /// </summary>
        public List<string> SpawnGroups = new List<string>();

        /// <summary>World-space coordinates to spawn at (or broadcast from).</summary>
        public Vector3D SpawnCoords;

        /// <summary>
        /// Optional forward direction for the spawn matrix.
        /// Defaults to Vector3D.Forward if left as Zero.
        /// </summary>
        public Vector3D SpawnForward = Vector3D.Zero;

        /// <summary>
        /// Optional up direction for the spawn matrix.
        /// Defaults to Vector3D.Up if left as Zero.
        /// </summary>
        public Vector3D SpawnUp = Vector3D.Zero;

        /// <summary>
        /// Per-entry spawn list — each entry has its own SpawnGroup + dedicated coords.
        /// Behaviour depends on SpawnAllEntries:
        ///   false (default) — one entry is chosen at random each fire.
        ///   true            — every entry spawns simultaneously each fire.
        /// SpawnGroups / SpawnCoords are ignored when SpawnEntries is non-empty.
        /// </summary>
        public List<SpawnEntry> SpawnEntries = new List<SpawnEntry>();

        /// <summary>
        /// Controls how SpawnEntries are processed when the event fires.
        ///   false (default) — pick one entry at random.
        ///   true            — spawn every entry in the list simultaneously.
        /// </summary>
        public bool SpawnAllEntries = false;

        /// <summary>
        /// If set, broadcasts this command code to any NPCs in range instead of
        /// spawning a new group. The NPC behavior must have a CommandReceive trigger
        /// with a matching CommandReceiveCode. Leave null to use CustomSpawnRequest.
        /// </summary>
        public string BehaviorCommandCode = null;

        /// <summary>Broadcast range in meters for BehaviorCommandCode. Ignored for spawns.</summary>
        public double BroadcastRange = 10000;

        /// <summary>
        /// How many minutes after the scheduled time the event is still allowed to fire.
        /// Increase this if your server has occasional downtime during the event window.
        /// </summary>
        public int FireWindowMinutes = 10;
    }
}