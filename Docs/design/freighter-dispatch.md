---
title: Freighter dispatch and supply depots
notes: [45]
covers:
  - Content/Data/Encounters/Alliance/Freighters/*.sbc
  - Content/Data/Encounters/Alliance/GVK-Alliance-TriggerGroup-SupplyDepotZone.sbc
checked: 2026-11-08
checked-against: MES d500922
---

# Freighter dispatch and supply depots

## Note 45

Freighter dispatch follows Supply Depot demand.
- **Demand counter:** the sandbox counter `<FACTION>_DepotDemand` counts that faction's owned depots whose restock is due.
  - **Up 1:** when an owned depot is captured, and again every 3 hours after its last restock. That happens once; the grid boolean `DemandRaised<FACTION>` stops it counting twice.
  - **Down 1:** when a Freighter's restock command reaches the depot, or when the depot changes hands or leaves every zone. Depots are invulnerable and permanent, so there is no destroyed or removed case.
- **Spawning:** the `GVK-Alliance-Event-SpawnFreighter-<FACTION>` event checks every minute and spawns a Freighter while the counter is at least 1. A faction with no owned depot, or none due, gets none.
- **One Freighter at a time:** it serves every due depot at once. Only due depots answer its waypoint requests, and up to 4 are queued and visited in the order they answered. The spawn condition (remote control code `Freighter_<FACTION>`, minimum distance 999999) keeps a second Freighter from spawning while one is flying.
- **Late depots:** a depot that becomes due after the Freighter has collected its waypoints waits for the next Freighter, which spawns once the current one is gone.
- **Testing:** `/MES.Debug.ChangeCounter.<FACTION>_DepotDemand.1` raises the demand by hand (undo with `.-1`).
- **Ownership:** comes from the faction zone that covers the depot, not from Influence directly.
- **Restock timing:** MES offers no inventory check, so "needs restocking" is the timer, not the cargo contents.
- **Missing counter:** the counter is created by the first depot request; a missing counter never passes the event condition.
- **Flight:** a Freighter spawns 100-200 m up near its HQ and cruises at 2 km (Primary autopilot), dropping to 100 m within 3 km of a Supply Depot (Secondary). So it climbs nearly straight up after spawning and after each depot. Both autopilots fly level (`FlyLevelWithGravity`) and don't bank into turns (GVK-Settings#763). They banked up to 15 degrees until 2026-11-08, when the owner reported Freighters that wobbled in place and never climbed. In level mode MES cuts all thrust while the grid tilts more than `HoverUpAngle` (10 degrees), and a bank turns the nose away from a waypoint far above, so the bank never eased off (MES `ThrustSystem.cs` `CalculateHoverThrust`, `RotationSystem.cs` `CalculateGyroRotation`, `AircraftFlightModel.cs` `ApplyRollIntoTurns`).
- **Defenses fly with it:** since 2026-11-08 a Freighter has four escort slots, all 100 m to the side: two level with its Remote Control and 20 m up, two 150 m back and 50 m up (`[EscortOffsets:]`, `GVK-Universal-TriggerGroup-LeashSlots`). Its Defenses (Interceptors or Strike Fighters) fly in them when they aren't fighting, break off at their normal combat range, and rejoin afterwards. Before that they patrolled around a centre that MES never moved, so they were left behind (GVK-Settings#764; parent leash, note 46).
