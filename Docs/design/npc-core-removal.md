---
title: Defeated NPC core removal
notes: [49]
covers:
  - ModScripts/NpcCoreRemovalSession.cs
  - Content/Data/Encounters/GVK-Universal-Behavior.sbc
checked-against: MES d500922
checked: 2026-11-13
---

# Defeated NPC core removal

## Note 49

A defeated NPC loses every core beacon it has, so Ship Core's no-core profile applies to the wreck (GVK-Settings#786; checked against MES `d500922`). Before this, the defeat action only switched the beacons off, and Ship Core kept a switched-off beacon as the grid's core, with the NPC core's empty limit list.

- **When:** whenever an NPC runs `GVK-Universal-Action-Disabled`, GVK's defeat action. It runs from Compromised and Timer triggers alike, mostly through the `DefeatedAndAttacked` trigger group. Static encounters, KOTH sites and trade stations never run it, and neither does the Coalition trader heading off to despawn.
- **What goes:** every NPC-owned block whose subtype is a Ship Core core in the GVK pack: `_NPC`, `_NPCNoConceal` and Disposable NPC beacons, and vanilla or player core beacons an NPC still owns. It looks in the grid's mechanical group (subgrids included) and in every piece split off the same original grid since the server started, because after a split MES follows the piece with the remote, which may not be the piece with the beacons. `ZoneBlock`s (NPC-owned or unowned) go too: the defeat action used to raze them itself, inside the same callback. Other zone beacons (`DrillBlocker`, `LimitedProdZone`, `GVK_No*Zone`) and cargo scanners stay.
- **Ship Core's side:** all the beacons go in one tick, but Ship Core handles each removal as it happens. With several beacons it may promote a remaining one to main core for a moment; after the last it has no core left, logs "removed with no replacement" and applies the no-core profile at once.
- **How:** MES reports each RivalAI action just before it runs (the `BehaviorTriggerActivationWatcher` API). That report comes from inside the game's damage, grind and close callbacks, where removing blocks crashed the server, so the defeat action razes nothing. The script only queues the grid there; 10 ticks later its own update removes the blocks on the game thread with `RemoveBlock`, which reaches clients.
- **What players see:** a defeated NPC's weapons, production, tools, rotors, pistons, H2 engines and shield generators are damaged to 50% by the no-core `Restricted` limit, and Ship Core shows players within 20 km one combat-log line per removed beacon ("Main core of grid ... was destroyed!" or "A backup core ..."). The wreck has no core beacon left, so the daily Essentials cleanup, which keeps only grids with one, deletes it (owner, 2026-11-13).
- **Also on success:** a few behaviors run the defeat action when a mission succeeds or times out (the Coalition distress wreck, the Large Coalition Depot, Recovery, the Research Lab upload). Those grids lose their cores the same way.
- **Not covered:** a grid defeated in the 10 ticks before a restart keeps its beacons, and an NPC whose remote was already broken when the server started never runs the action again. Splits from before a restart are forgotten, so a piece cut off then keeps its beacons.
