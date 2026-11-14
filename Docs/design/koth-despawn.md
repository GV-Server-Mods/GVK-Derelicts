---
title: KOTH 5 km despawn
notes: [42]
covers:
  - Content/Data/Encounters/GVK-Universal-TriggerGroup-DespawnInKOTH.sbc
  - Content/Data/Encounters/GVK-Universal-TriggerGroup-DespawnInZ0.sbc
checked-against: MES d500922
checked: 2026-11-14
---

# KOTH 5 km despawn

## Note 42

KOTH 5 km zones: MES can't keep spawns out of a zone, only require one (se-dev-mes `events_and_zones.md` §4 rule 8), so a spawn requested from outside can land inside a KOTH Site.
- **The fix:** `GVK-Universal-TriggerGroup-DespawnInKOTH` despawns anything that lands in a `KOTH Site 0N 5000` zone, as `DespawnInZ0` does for Zone 0.
- **Who carries it:** all installation, alliance and COALITION/SOBAN/KHAANEPH Unit behaviors. GAALSIEN Units don't, because the whitelisted ones are the KOTH garrison.
- **Effect:** such a despawn isn't a loss. It sets `GVK_DespawnedByRule`, so there is no "lost" chat and no alliance points change; the Defense refund still runs. Zone 0 and the 30-minute outside-faction-zone despawn work the same way, and the latter posts "A {Faction} {EncounterDisplayName} was abandoned." instead.
- **Spawn chat waits for the check:** MES runs every trigger that is ready in one pass before any of their actions, so an init (`[Type:Session]`) and the zone check fire together and a chat in the init goes out before the despawn. Elites, installations and alliance structures therefore send their spawn chat from a separate trigger that starts `[UseTrigger:false]`. The init turns it on (`[EnableTriggers:true]`), so it is first checked on the next pass, and `GVK-Universal-Condition-NotDespawnedByRule` drops it if a zone check fired. It has `[MaxActions:1]`, which MES stores, so it doesn't repeat after a restart. New behaviors that announce their spawn and carry a zone despawn need the same pattern (example: `GVK-Unit-Elite-Trigger-SpawnedChat`).
