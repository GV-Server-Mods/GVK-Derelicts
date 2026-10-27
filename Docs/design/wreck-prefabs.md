---
title: Wreck prefabs and vanilla encounters
notes: [38, 39]
covers:
  - Content/Data/Encounters/GVK-Universal-Loot.sbc
  - Content/Data/Encounters/GVK-Universal-SpawnGroup-VanillaPlanetaryDisabled.sbc
  - Content/Data/Prefabs/NW*.sbc
checked-against: MES 13bcb1d
---

# Wreck prefabs and vanilla encounters

## Note 38

Base-game `P*` planetary encounters (`P1_SupplyPost` to `P30_AbandonedFarmstead`) are disabled in `GVK-Universal-SpawnGroup-VanillaPlanetaryDisabled.sbc`, so they stay out of the wreck pools (se-dev-mes `spawning_and_conditions.md` explains why MES loads them). Their prefabs stay loaded and can still be used in GVK spawn groups. When a game update adds new `P*` groups, copy them into that file.

## Note 39

Wreck prefab checklist (Small `NWS` / Medium `NWM`; checked against MES `13bcb1d`):
- **Loot:** the main loot profile fills small/large cargo containers (`GVK-Universal-Loot.sbc`): Small wrecks need 4-6, Medium 8-12. Conveyor junctions, straight conveyor tubes and AI combat/mission blocks count, because `GVK-Replacer-ConveyorToCargo` turns them into containers at spawn.
- **Adding containers:** swap a 1x1x1 block for a small cargo container in place (same size only, never remove blocks). Order: remaining conveyor shapes and AI blocks, then timers, event controllers, turret controllers, gyros (keep 1) and reactors (keep 1), batteries last (keep 2). Never swap `MA_Buster_Conveyor`; it holds turrets.
- **RivalAI block:** needs a Remote Control, a `LargeBlockCockpitSeat`/`LargeBlockCockpitIndustrial`, or a flight AI block (the last two are swapped in by `GVK-Replacer-LargeCockpitToRivalAI`). Without one the wreck behavior is never applied.
- **Beacon:** required for a planetary installation; range 5 km Small, 30 km Medium, no HUD text. Antennas off, welders and projectors off, projector blueprints removed.
- **Placement:** vehicles use the `Wreck` spawn conditions (random rotation), buildings the `Building` ones (none).
- **Names:** the file name, prefab `Subtype`, main grid `DisplayName` and the spawn group's `<Prefab SubtypeId>` all match.
