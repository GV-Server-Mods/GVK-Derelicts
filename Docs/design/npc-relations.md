---
title: How NPC relations are read
notes: [47]
covers:
  - Content/Data/Encounters/GVK-Universal-Target.sbc
checked-against: MES 67320b7
---

# How NPC relations are read

## Note 47

NPC relations come from two places (checked against MES `67320b7` and the game build of 2026-10-23). The world-build commands are in the se-dev-kharak skill.
- **MES:** two NPC grids in different factions are rated from the faction-to-faction relation, the same table the turrets use (MES `67320b7`, PR #461). A pair with no value set, or a grid with no faction, counts as Enemy. An NPC rating a player uses the player's own reputation with the NPC's faction, and vanilla damage reputation lowers that for every attacker of a non-static faction. 500 and up counts as Friends and -501 and below as Enemy, as in the game (PR #460), so a player at COALITION's static 500 is Friends to MES. Target profiles still pick or skip factions by tag; they have not been retested against the table since the fix.
- **Turrets:** vanilla and WeaponCore use the faction-to-faction relation between two NPC factions, and a pair with none set counts as Enemies. Against a player they use the player's own relation with the NPC faction.
- **Targeting:** COALITION Units pick GAALSIEN by faction name (`GVK-Universal-Target-EnemyGAALSIENBeacon`, `-StrikeFighterBeacon`). Forced targets (the attacker, a turret's target, a squadmate's target) go through the override profile instead. COALITION behaviors that fight GAALSIEN set `[OverrideTargetData:GVK-Universal-Target-Override-COALITION]`, which also accepts GAALSIEN by name; every other behavior that can force a target sets `GVK-Universal-Target-Override`, which skips KOTH.
- **KOTH:** Neutral to every NPC faction and to players (static, `StartingReputation` 0), so its weapons with WeaponCore's Neutrals setting on fire on any grid that breaks the KOTH rules, NPC or player. In return no NPC fires on KOTH: MES target profiles skip it by tag, the override profiles above keep a grid it shot from firing back, and every non-KOTH prefab has Neutrals off.
- **Neutrals setting:** only matters for Neutral pairs (KOTH, and DERELICT with COALITION/SOBAN/KHAANEPH). It's off in every prefab except the `NKO [KOTH]` ones, so NPCs ignore Neutrals. Turning it on in an NPC prefab would make that grid fire on KOTH structures.
- **Attacker checks (temporary workaround, hub #739):** `IsAttackerHostile`, `IsAttackerNeutral` and `IsAttackerFriendly` still rate an NPC attacker from its own reputation, not the faction table (MeridiusIX/Modular-Encounters-Systems#462). Every NPC reads 500 to COALITION, which MES now counts as Friendly, so the shared `GVK-Universal-Condition-SendHighPriorityTarget` never passes for a GAALSIEN hit. The five COALITION behaviors that send targets (Depot, Relay, Turret Post, Recovery Mission, Salvager) use `GVK-Universal-TriggerGroup-SendTargets-COALITION`, whose condition only checks that the damager is an NPC; the receivers still accept only GAALSIEN or Enemy targets. Remove the three `-COALITION` profiles when the MES fix is on master. Not tested in game yet.
