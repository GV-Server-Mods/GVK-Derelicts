# GVK-Derelicts
Global Bools:
- `LargeWrecksEnabled`
- `SpawnStaticTown`
- `MassiveSignalEligible`
- `LargeWreckActive`
- `ConvoyInactive`

Run command `/MES.Debug.ChangeBool.Value1.true/false` to change bools. LargeWrecksEnabled should be turned on about 1 to 2 weeks in.
SpawnStaticTown needs to be false when clearing all static grids so they don't spawn too many at once. Then set to true after the trade stations spawn in.

Global Counters:
- `KHAANEPH_Points`
- `SOBAN_Points`

Alliance zone size is driven by these counters through `GVK-Alliance-Events-ZoneSize.sbc` (one MES Event per faction, 12 conditions mapped 1:1 to 12 actions):

| Points | Zone radius |
| --- | --- |
| `< 200` | 10 km |
| `200 - 399` | 20 km |
| `400 - 599` | 30 km |
| `600 - 799` | 40 km |
| `800 - 999` | 50 km |
| `>= 1000` | 55 km |

Counters are clamped to a floor of 0 and a ceiling of 1200 every evaluation cycle, and every chat message names the direction the territory moved.

Run command `/MES.Debug.ChangeCounter.Value1.Value2` to adjust counters. This is an additive command, so use positive or negative ammounts.


https://github.com/MeridiusIX/Modular-Encounters-Systems/wiki/Admin-&-Configuration:-Admin-&-Debug-Options#debug

`/MES.Info.GetGridBehavior` or `/MES.Info.GetGridData` are not currently on the admin debug command wiki

To get large grids to spawn: `/MES.Debug.ChangeBool.LargeWreckActive.false`

To get Convoy to spawn: `/MES.Debug.ChangeBool.ConvoyInactive.true`

Other useful commands:
`/MES.Debug.ClearUniqueEncounters`
`/MES.Debug.ClearStaticEncounters`

### Profile Naming Convention:
`GVK-<SpawnType>-<SubType>-<ProfileType>-<UniqueTag>`


Example: `GVK-Drone-Encounter-Behavior-ProductionCruiserHorsefly`


Prefab naming:
- Only use the 4-letter tag for prefab names to reduce text spill in targeting.
```NCS	[NPC CargoShip]		"NCS [COAL] Trader"
NAS (NPC Alliance Station)  "NAS [KHAA] Carrier"
NCO	(NPC Convoy)	    	"NCO [COAL] Cargo Cruiser"
NDR	(NPC Drone)	        	"NDR [GAAL] Salvager"
NKO	(NPC KOTH)	        	"NKO [KOTH] Khar Toba"
NMI	(NPC Mission)	    	"NMI [COAL] Support Cruiser"
NST	(NPC Static)	    	"NST [COAL] South Signpost"
NWL	(NPC Large Wreck)    	"NWL [DERE] Mammoth"
NWM	(NPC Med Wreck)	    	"NWM [GAAL] Outpost"  
NWS	(NPC Small Wreck)    	"NWS [COAL] Turtle"
NTS	(NPC Trade Station)	    "NTS [COAL] Rusty's"
NLO	(NPC Loot)	        	"NLO [COAL] Cargo Drop"

NOU	(NPC Outpost)	    	Out of date
NSN	(NPC Station)	    	Out of date
```
## All behavior inits:
`[CustomStrings:EncounterType,DroneSmall]`

`[CustomStrings:EncounterDisplayName,aircraft]`

Additional Bool:
`[SetBooleansTrue:GVK_MobilityType_Aircraft]`

## Encounter Types for custom string inits:
| EncounterType  | EncounterDisplayName | DefenseSpawn_Limit | GVK_MobilityType_Aircraft |
| --- | --- | --- | --- |
| CustomStrings | CustomStrings | CustomCountersVariables | SetBooleansTrue |
| **Alliance**  |  |  |  |
| - AllianceBase  | Base  | 8 |  |
| - AllianceOutpost | Outpost | 4 |  |
| **Wrecks** |  |  |
| - WreckLarge | large signal* | 8 |  |
| - WreckMedium | medium signal* | 4 |  |
| - WreckSmall | small signal | 0 |  |
| **Drones** |  |  |
| - DroneElite | Elite cruiser* |  |  |
| - DroneLarge | cruiser* |  |  |
| - DroneMedium | craft* |  | true* |
| - DroneSmall | craft* |  | true* |

## Factions:
- KHAANEPH
- GAALSIEN
- COALITION
- SOBAN
- DERELICT

## Reputaiton Changes:
Reputation can be changed using a plugin (I think it is Crunch Utils, or might be Crunch Econ V3) with the following commands:
`!faction rep change OPA SOBAN 1500`. NPC rep should be as follows:
- Set reputation between GAALSIEN and KOTH to friendly `!faction rep change GAALSIEN KOTH 1500`
- Set reputation between COALITION and GAALSIEN to enemy `!faction rep change GAALSIEN COALITION -1500`
- Set reputation between KHAANEPH and SOBAN to enemy `!faction rep change KHAANEPH SOBAN -1500`
- Set reputation between KHAANEPH and KOTH to friendly `!faction rep change KHAANEPH KOTH 1500`
- Set reputation between SOBAN and KOTH to friendly `!faction rep change SOBAN KOTH 1500`

## Thanks Yous:
- Nekron910 https://steamcommunity.com/sharedfiles/filedetails/?id=2650194963&tscn=1643638039
- Engineered Coffee https://steamcommunity.com/id/EngineeredCoffee/myworkshopfiles/
- Rayman11NL https://steamcommunity.com/profiles/76561198210730607/myworkshopfiles/

# Notes
1. Chat SendToAllPlayers will also be received by SEDB when set to send server messages.
2. To avoid this, use `SendToAllOnlinePlayers:false`, `IgnoreAntennaRequirement:true`, and a very large override range.
3. Don't use UseSurfaceHoverThrustMode at the same time as FlyLevelWithGravity.
4. When using UseSurfaceHoverThrustMode, ensure WaypointTolerance is less than HoverPathStepDistance.
5. The UseSurfaceHoverThrustMode works well for wheeled rovers on planets, but use HoverPathStepDistance less than 100 for rougher terrains.
6. Planet rovers with suspension need hidden NPC thrusters and gyros to operate because MES has no suspension controls.
7. Set the planet rover suspension friction very low, like 12% or less, to allow it to turn reasonably.
8. Use Patrol behavior for random encounters and a trigger sequence to switch between aggressive behaviors with secondary autopilots.
9. Use a Manual Trigger where multiple triggers need to operate the same action to prevent repeated trigger actions.
10. KPLs disappear quickly for unknown reasons; when using KPLs, plan them to work for a few minutes or less at a time.
11. `UseFailCondition` and `UseElseActions` don't appear to work with Timer Triggers because the timer always succeeds.
12. Particles can be played similarly to sounds, but are undocumented in the wiki.
13. Condition Profiles do not work correctly with some static SpawnGroups; instead, use those tags in the SpawnGroup directly.
14. Do not raze blocks that could be on subgrids; this can lead to a crash.
15. Do not use the GenerateExplosion and raze functions simultaneously near the same block (like RAI Remote); this can lead to a crash.
16. `BountyOnKill=3000000;` can be put directly in the behavior profile when using this mod https://steamcommunity.com/sharedfiles/filedetails/?id=2812148664
17. `ResetThisStaticEncounter:true` and `ForceDespawn:true` can remove and reset static encounters, but are undocumented in the wiki.
18. Strike behavior needs a good amount of distance to line up and attack, and use min and max offset distances of around 2km.
19. StrikeBeginPlanetAttackRunDistance is measured from the min and max offset distance waypoint; keep this low, around 100m.
20. If IdealPlanetAltitude is way higher than MinimumPlanetAltitude, it will climb too sharply and disturb its angle of attack.
21. NPCs are awful at aiming at targets. Use Keen AI blocks instead of RAI autopilot if accuracy is critical.
22. `ProcessAsAdminSpawn:true` is available for Spawner profiles to bypass some restrictions.
23. Use `[IgnoreCleanupRules:true]` on all NPCs with aggressive MES CleanUp settings to help delete debris that doesn't have an active RAI block.
24. Use `[DebugMessage: enter text here]` in action profiles for a quick way to send a message to chat for testing purposes.
25. Do not use RazeBlocks on an RAI remote control block; doing so can cause a crash at UpdateShape() if the block is split from its parent grid.
26. `MaxActions` is one-way. Once `TriggerCount >= MaxActions` the trigger is force-disabled on every evaluation and RivalAI has no tag to reset the count, so `[EnableTriggers:true]` cannot revive it. Any trigger that must fire again (3h cooldowns, repeatable terminals) must use `[MaxActions:-1]` and disable itself from its own action.
27. `[ActionExecution:Condition]` with `[UseAnyPassingCondition:true]` runs only the action whose index matches the last satisfied condition, so `ConditionIds` and `ActionIds` must be index-aligned and equal in length. This is how one event can host a whole tier ladder instead of one event per tier. Order matters: list clamp conditions last so a clamp wins the tie against a simultaneous tier change.
28. State for MES event tier ladders: use a stateless integer marker, not a boolean matrix. Keep one `<FACTION>_Tier` sandbox counter holding the currently-announced radius. Conditions are pure counter tests: points in band AND `Tier != band` AND direction (`Tier < band` = up-entry, `Tier > band` = down-entry), so every transition announces exactly once with a truthful direction and same-tier re-fires are impossible. Clamps never write the tier marker - the transition action owns it (single writer), so a clamp that resets points gets its zone + chat on the next cycle. The top band must be open-ended (`>= 1000`, no upper bound): the ceiling clamp parks points at exactly the max, so a bounded top band leaves that value dead - no band matches, the zone never resizes, and downstream zone-gated triggers silently refuse. A condition referencing a counter that was never written to sandbox storage ALWAYS fails (MES checks the `GetVariable` success flag - the 0 default does not help), so a one-shot `UniqueEvent:true` bootstrap event whose conditions touch only the Points counters must create the Tier markers first; `RunCount` is serialized, so it fires exactly once per world.
29. RivalAI `[SetBooleansTrue/False]` and `[SetCounters]/[IncreaseCounters]` are grid-scoped, not sandbox. Anything that a MES Event, plugin, or HUD must read needs the `[SetSandboxBooleansTrue/False]`, `[IncreaseSandboxCounters]` etc. variants instead.
30. Preset base deployment (`GVK-Alliance-PresetBases-*`) keeps one live base per site purely through the SpawnCondition RC code gate: `[RemoteControlCode:GVK-Alliance-Base]` with `[RemoteControlCodeMinDistance:1100]`. 1100 must stay above `2 x` the spawner `MaxDistance` (500) or a redeploy can land outside the gate; tower sites are 7.9 km apart at minimum, so the gate never leaks across sites. There is no per-site cooldown: the site frees itself when the base grid is destroyed, and pressing the terminal while a base exists is a silent no-op (the base's own "constructed" chat is the success feedback).
31. MES Event chat messages only substitute `{PlayerName}`. `IdsReplacer` tokens (`{Faction}`, `{EncounterDisplayName}`, sandbox counters, zone names) are applied to sandbox variable names/values, zone names, spawn replace keys and `DebugChatMessage`, but not to event chat text.
32. MES zone radius vs Zone 0: the SOBAN zone centre is 37.2 km and KHAANEPH is 47.0 km from Crossroads Tower, so the 40-55 km tiers overlap the starter hub. NPC spawning there is already gated server-side (COALITION only), but hub players will see alliance zone enter/leave announcements.
33. Known upstream MES issue: `TriggerSystem.ProcessButtonTriggers` skips panels on other grids only when they are in the same logical group, so a player-built panel with a matching name can fire another grid's triggers. Needs an MES-side fix; SBC workarounds are limited to tightening the trigger's player/zone/reputation conditions.
34. MES/RivalAI sandbox variables are ONE session-global namespace: two events writing the same bare name fight over the same storage. Live incident: the ZoneSize ladder used bare `Tier10..Tier55` booleans in both the KHAANEPH and SOBAN events; each faction's transitions cleared the other's flags and the two events ping-ponged "decreased to 10km" / "increased to 55km" announcements forever (plus a `-10000` debug counter nudge as the trigger). Prefix every variable that anything else touches with its owner (`KHAANEPH_Tier`, not `Tier`), and keep one writer per variable.
35. The zone ladder's Tier marker tracks the last *announced* radius, not the live zone. Manually resetting/deactivating a zone via debug desyncs the two - the ladder will never re-assert (all band conditions require `Tier != band`), so the zone stays shrunk until points cross a boundary. Recovery: drop the marker below the current band (`/MES.Debug.ChangeCounter.SOBAN_Tier.-45`) and the ladder re-Sets the radius within one 5 s cycle.
36. MES substituted `{Faction}` (the NPC's own faction tag) into RivalAI sandbox counters and booleans (`TriggerSystem.SetSandboxCounter`/`SetSandboxBool`), so own-faction counter changes are faction-agnostic: `GVK-Alliance-TriggerTags-Points.sbc` Despawned/Awarded triggers were consolidated to one pair per encounter type using `[DecreaseSandboxCounters:{Faction}_Points]` / `[IncreaseSandboxCounters:{Faction}_Points]`, and their trigger tags dropped the faction suffix (hub now references `...-{EncounterType}` only). `[SetSandboxStrings]` and `[SetCustomStrings]` values run the full IdsReplacer, so `[CustomStrings:DecreaseFactionName,{Faction}]` feeds the shared chat profiles. The Compromised transfer (decrease own + increase rival) still needs one pair per faction: `SetSandboxCounter` only substitutes `{Faction}`, there is no rival/opposing-faction token, and trigger `[Actions:]` references resolve statically at profile load. Revisit if MES adds full IdsReplacer (or `{OpposingFaction}`/CustomStrings support) to `SetSandboxCounter` - `{Faction}`-based lines will need no rework when that lands.


## Helpful MES examples:
- Enenra's MSB https://github.com/enenra/mes-shared-behaviors
- Enenra's GFA https://github.com/enenra/gfa/tree/86dab4803276eda74a3359e10cf5e93d9eef6301/GFA%20-%20MES%20Utilities/Content
