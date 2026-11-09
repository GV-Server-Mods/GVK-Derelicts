---
title: Server build requirements (MES release)
notes: [43]
covers:
  - Content/Data/Encounters/GVK-Universal-TriggerGroup-LeashBeacon.sbc
  - Content/Data/Encounters/Unit/Unit-All-TriggerGroup-Leash.sbc
  - Content/Data/Encounters/Unit/Unit-All-TriggerGroup-PeerEscort-*.sbc
checked-against: MES a1895d9
checked: 2026-11-09
---

# Server build requirements (MES release)

## Note 43

Server build: GVK needs an MES release made after master `a1895d9` (2026-10-24). Workshop 2.75.01 is not enough. Older builds ignore the tags or read them differently:
- **`MatchReceiverParent`/`Escort`/`Leader`** (MeridiusIX/Modular-Encounters-Systems#386, 2.75.00): escort, leader and Defense refund commands. Without them a command reaches every same-owner grid in range, and `GVK_LeaderDead` would strip unrelated escorts.
- **`MaxVelocityAngleForSpeedControl:180`** (#402, 2.75.00): before it, a grid drifting away from its waypoint "braked" itself further away.
- **`UseAircraftFlightModel`** (#390, 2.75.00): the Unit aircraft autopilots.
- **`AllowTargetFarWithoutTarget`** (#410, after 2.75.01): the `Patrol<Name>` groups return a Unit to Patrol through it. Without it, a Unit whose target is gone stays in combat.
- **`LeaveEscortSlot`** (#408, after 2.75.01): escorts free their leader's slot (note 40). Without it, a peer leader that lost its wing offers a slot MES still counts as taken, and a Unit that leaves a Freighter's escort slot to fight keeps it (note 46).
- **`UseCommandWaypointAsPatrolReference`** (#441, after 2.75.01): leashed Units patrol around where their parent was when each patrol leg began (note 46). Without it, they patrol around their spawn point. It doesn't keep up with a moving parent (GVK-Settings#764), so Freighters use escort slots.
