---
title: Preset alliance bases
notes: [30]
covers:
  - Content/Data/Encounters/Alliance/PresetBases/*.sbc
checked-against: MES bc71965
---

# Preset alliance bases

## Note 30

Preset base deployment (`GVK-Alliance-PresetBases-*`) keeps one live base per site purely through the SpawnCondition RC code gate: `[RemoteControlCode:GVK-Alliance-Base]` with `[RemoteControlCodeMinDistance:1100]`.
- **The 1100 m gate** must stay above `2 x` the spawner `MaxDistance` (500), or a redeploy can land outside it. Tower sites are 7.9 km apart at minimum, so the gate never leaks across sites.
- **No per-site cooldown:** the site frees itself when the base grid is destroyed. Pressing the terminal while a base exists does nothing; the base's own "constructed" chat is the success feedback.
