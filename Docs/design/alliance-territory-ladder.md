---
title: Alliance territory ladder and influence
notes: [28, 35, 36]
covers:
  - Content/Data/Encounters/Alliance/GVK-Alliance-Events-ZoneSize.sbc
  - Content/Data/Encounters/Alliance/GVK-Alliance-TriggerTags-Influence.sbc
---

# Alliance territory ladder and influence

## Note 28

Territory tier ladder (`GVK-Alliance-Events-ZoneSize.sbc`): one event per faction runs the whole ladder with `[ActionExecution:Condition]` (se-dev-mes `profiles_and_tags.md` §2.G).
- **State:** one `<FACTION>_Tier` sandbox counter holding the currently announced radius, not a boolean matrix. Bare shared names (`Tier10..Tier55`) once made the SOBAN and KHAANEPH ladders overwrite each other.
- **Conditions:** points in band AND `Tier != band` AND direction (`Tier < band` going up, `Tier > band` going down). So every transition announces exactly once, in the right direction, and the same tier never re-fires.
- **Clamps:** they never write the Tier marker; the transition action is its only writer. A clamp that resets points gets its zone and chat on the next cycle. Clamp conditions are listed last, so a clamp wins a tie against a tier change.
- **Top band:** open-ended (`>= 1000`). The ceiling clamp parks points at exactly the max, so a bounded top band would leave that value matching no band.
- **Bootstrap:** a one-shot `UniqueEvent:true` event creates the Tier counters first, because a counter that was never written fails every condition.

## Note 35

The zone ladder's Tier marker tracks the last *announced* radius, not the live zone. Resetting or deactivating a zone by hand desyncs the two. The ladder then never re-asserts (every band condition requires `Tier != band`), so the zone stays shrunk until points cross a boundary.
- **Recovery:** drop the marker below the current band (`/MES.Debug.ChangeCounter.SOBAN_Tier.-45`), and the ladder sets the radius again within one 5 s cycle.

## Note 36

Influence changes use `{Faction}`. `GVK-Alliance-TriggerTags-Influence.sbc` has one Despawned/Awarded trigger pair per Encounter Type, using `[DecreaseSandboxCounters:{Faction}_Influence]` / `[IncreaseSandboxCounters:{Faction}_Influence]`; their trigger tags reference `...-{EncounterType}` only. `[CustomStrings:DecreaseFactionName,{Faction}]` feeds the shared chat profiles. The Compromised transfer (own faction down, rival up) still needs one pair per faction, because MES has no rival-faction token.
