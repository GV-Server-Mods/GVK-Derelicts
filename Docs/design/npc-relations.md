---
title: How NPC relations are read
notes: [47]
covers:
  - Content/Data/Encounters/GVK-Universal-Target.sbc
checked-against: MES 103f8d0
---

# How NPC relations are read

## Note 47

NPC relations come from two places (checked against MES `103f8d0` and the game build of 2026-10-23). The world-build commands are in the se-dev-kharak skill.
- **MES:** an NPC rates another NPC's grid from the target owner's own reputation with its faction, not from the faction-to-faction relation. With no stored value that is the faction's `StartingReputation`, or -1000 (Enemy) if it has none, and vanilla damage reputation lowers it for every attacker of a non-static faction. COALITION's `StartingReputation` is 500, and MES only counts above 500 as Friends, so every other NPC is Neutral to COALITION. GAALSIEN, DERELICT, SOBAN and KHAANEPH rate every other NPC Enemy, and their target profiles skip the factions they leave alone by tag.
- **Turrets:** vanilla and WeaponCore use the faction-to-faction relation between two NPC factions, and a pair with none set counts as Enemies. Against a player they use the player's own relation with the NPC faction.
- **Targeting:** COALITION Units pick GAALSIEN by faction name (`GVK-Universal-Target-EnemyGAALSIENBeacon`, `-StrikeFighterBeacon`). Forced targets (the attacker, a turret's target, a squadmate's target) go through the override profile instead. COALITION behaviors that fight GAALSIEN set `[OverrideTargetData:GVK-Universal-Target-Override-COALITION]`, which also accepts GAALSIEN by name; every other behavior that can force a target sets `GVK-Universal-Target-Override`, which skips KOTH.
- **KOTH:** Neutral to every NPC faction and to players (static, `StartingReputation` 0), so its weapons with WeaponCore's Neutrals setting on fire on any grid that breaks the KOTH rules, NPC or player. In return no NPC fires on KOTH: MES target profiles skip it by tag, the override profiles above keep a grid it shot from firing back, and every non-KOTH prefab has Neutrals off.
- **Neutrals setting:** only matters for Neutral pairs (KOTH, and DERELICT with COALITION/SOBAN/KHAANEPH). It's off in every prefab except the `NKO [KOTH]` ones, so NPCs ignore Neutrals. Turning it on in an NPC prefab would make that grid fire on KOTH structures.
