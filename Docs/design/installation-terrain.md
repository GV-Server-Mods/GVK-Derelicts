---
title: Installation terrain rule
notes: [48]
covers:
  - Content/Data/Encounters/PlanetaryInstallation/GVK-PlanetaryInstallation-All-SpawnCondition.sbc
  - Content/Data/Encounters/Alliance/GVK-Alliance-All-SpawnCondition.sbc
checked-against: MES 103f8d0
---

# Installation terrain rule

## Note 48

Planetary installations never spawn on Rock (GVK-Settings#726; checked against MES `103f8d0`). Every `[PlanetaryInstallation:true]` conditions profile, Units included, has `[InstallationTerrainValidation:true]` and `[DisallowedTerrainTypes:Rock]`.
- **What it checks:** MES reads the terrain type at each candidate spawn spot and skips spots that match. On GVK_Pertam_Planet, Rock is DesertRocks, Stone and Stone_03_Roads, so this keeps installations off roads, cliffs and rocky ground.
- **Limits:** only the centre point is checked, so a large prefab can still overhang a road edge. Rocky regions may get fewer installations, since MES keeps searching further out.
- **Don't add `[UseTerrainTypeValidation:true]`:** it uses the same Allowed/Disallowed lists but checks the most common terrain around the player, so a player standing on rock would block the spawn.
