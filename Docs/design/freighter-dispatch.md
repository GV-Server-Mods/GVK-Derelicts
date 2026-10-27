---
title: Freighter dispatch and supply depots
notes: [45]
covers:
  - Content/Data/Encounters/Alliance/Freighters/*.sbc
  - Content/Data/Encounters/Alliance/GVK-Alliance-TriggerGroup-SupplyDepotZone.sbc
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
