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
