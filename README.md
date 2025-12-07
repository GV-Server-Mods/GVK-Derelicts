# GVK-Derelicts
Global Bools
- `LargeWrecksEnabled`
- `SpawnStaticTown`
- `MassiveSignalEligible`
- `LargeWreckActive`
- `ConvoyInactive`

Run command: `/MES.Debug.ChangeBool.Value1.true/false` to change bools. LargeWrecksEnabled should be turned on about 1 to 2 weeks in.
SpawnStaticTown needs to be false when clearing all static grids so they don't spawn too many at once. Then set to true after the trade stations spawn in.

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
```NCS	[NPC CargoShip]		"NCS [COALITION] Trader"
NCO	[NPC Convoy]		"NCO [COALITION] Cargo Cruiser"
NDR	[NPC Drone]		"NDR [GAALSIEN] Salvager"
NKO	[NPC KOTH]		"NKO [KOTH] Khar Toba"
NMI	[NPC Mission]		"NMI [COALITION] Support Cruiser"
NST	[NPC Static]		"NST [COALITION] South Signpost"
NWL	[NPC Large Wreck]	"NWL [DERELICT] Mammoth"
NWM	[NPC Med Wreck]		"NWM [GAALSIEN] Outpost"  
NWS	[NPC Small Wreck]	"NWS [COALITION] Turtle"
NTS	[NPC Trade Station]	"NTS [COALITION] Rusty's"
NLO	[NPC Loot]		"NLO [COALITION] Cargo Drop"

NOU	[NPC Outpost]		Out of date
NSN	[NPC Station]		Out of date
```

## Thanks Yous:
Nekron910 https://steamcommunity.com/sharedfiles/filedetails/?id=2650194963&tscn=1643638039

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
