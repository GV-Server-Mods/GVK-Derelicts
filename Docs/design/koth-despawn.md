---
title: KOTH 5 km despawn
notes: [42]
covers:
  - Content/Data/Encounters/GVK-Universal-TriggerGroup-DespawnInKOTH.sbc
---

# KOTH 5 km despawn

## Note 42

KOTH 5 km zones: MES can't keep spawns out of a zone, only require one (se-dev-mes `events_and_zones.md` §4 rule 8), so a spawn requested from outside can land inside a KOTH Site.
- **The fix:** `GVK-Universal-TriggerGroup-DespawnInKOTH` despawns anything that lands in a `KOTH Site 0N 5000` zone, as `DespawnInZ0` does for Zone 0.
- **Who carries it:** all installation, alliance and COALITION/SOBAN/KHAANEPH Unit behaviors. GAALSIEN Units don't, because the whitelisted ones are the KOTH garrison.
- **Effect:** such a despawn isn't a loss. It sets `GVK_DespawnedByRule`, so there is no "lost" chat and no alliance points change; the Defense refund still runs. Zone 0 and the 30-minute outside-faction-zone despawn work the same way, and the latter posts "A {Faction} {EncounterDisplayName} was abandoned." instead.
