# GVK_Derelicts Project Tracker & TODOs

Centralized task tracker for **GVK_Derelicts** on the **GV: Deserts of Kharak (GVK)** server.

---

## 🛠️ Workflow & Usage
* **Manual Tasks**: Add high-level plans, features, or balance tasks to the sections below.
* **Inline Code TODOs**: Leave `<!-- TODO: ... -->` in `.sbc` files or `// TODO: ...` in `.cs` files.
* **Auto-Sync Script**: Run the following command from PowerShell to refresh the auto-harvested section below:
  ```powershell
  pwsh -File .\tools\Get-Todos.ps1 -UpdateFile
  ```

---

## 🔴 P0: Urgent / Game-Breaking
- [ ] **Cross-Grid Trigger Bypass**: Upstream button panel trigger bypass (`TriggerSystem.ProcessButtonTriggers` executing across different grids) — pending PR submitted to MES.
- [ ] **Dynamic Weapon Randomization**: Upstream MES weapon randomization issue (fix in progress, pending testing before submitting PR; temp workaround: weapon randomization disabled).
- [ ] **ChangeBlocksShareModeAll MES Bug**: Submit an MES PR fixing the indexing bug in `ActionSystem.cs` (`ChangeBlocksShareModeAll` loop uses `grid.AllTerminalBlocks[i]` instead of `[j]`). The tag was removed from `GVK-Universal-Action-PublicSpawnPoint`, so the KOTHOutpost spawn point is not public right now. Restore the tag once the fix ships.
- [ ] **Rescue Mission Despawn** ([#469](https://github.com/GV-Server-Mods/GVK-Settings/issues/469)): Fix mission cruiser despawning after server restarts during active rescue missions.
- [ ] **Escort Behavior Lock** ([#449](https://github.com/GV-Server-Mods/GVK-Settings/issues/449)): Fix NPC escorts retreating prematurely due to getting stuck between behavior state transitions.

---

## 🟡 P1: Active Encounters & Features (Season 11)
### Faction Encounters & KOTH
- [ ] **Alliance Preset Bases** ([#494](https://github.com/GV-Server-Mods/GVK-Settings/issues/494)): Complete preset location deployment system (`GVK-Alliance-PresetBases-*`) and collapse per-faction definitions via `IdsReplacer`.
- [ ] **Alliance Base Proximity Check** ([#479](https://github.com/GV-Server-Mods/GVK-Settings/issues/479)): Add trigger to check for duplicate base signals within 15 km; despawn and re-roll to prevent clutter.
- [ ] **Flying KOTH** ([#494](https://github.com/GV-Server-Mods/GVK-Settings/issues/494)): Create flying KOTH encounter profile and behaviors.
- [ ] **KOTH Megastructures** ([#494](https://github.com/GV-Server-Mods/GVK-Settings/issues/494)): Move KOTH capture blocks onto a separate subgrid to allow megastructures to conceal properly.
- [ ] **KOTH Slot Randomization** ([#494](https://github.com/GV-Server-Mods/GVK-Settings/issues/494)): Randomize KOTH encounter selection for each active spawn slot.
- [ ] **Ammo Factory Encounter** ([#494](https://github.com/GV-Server-Mods/GVK-Settings/issues/494)): Add automated ammo factory encounter.
- [ ] **Re-enable Planetary Encounters** ([#478](https://github.com/GV-Server-Mods/GVK-Settings/issues/478)): Restore random encounters by adjusting small planetary installation probability multipliers (to ~12.5) and uncommenting spawn conditions.

### Escorts & Formations
- [ ] **Escort System Verification** ([#484](https://github.com/GV-Server-Mods/GVK-Settings/issues/484)): Diagnose why Baserunners fail to escort cruisers; verify escort autopilot assignment.
- [ ] **On-Demand Escort Spawns** ([#480](https://github.com/GV-Server-Mods/GVK-Settings/issues/480)): Convert escorts from ambient idle spawns to interactive on-demand spawns (via button or contract block).
- [ ] **Formation Flying** ([#481](https://github.com/GV-Server-Mods/GVK-Settings/issues/481)): Implement RivalAI escort formation behaviors for fighters, sandskimmers, and LAVs.
- [ ] **Convoy System Integration**: Integrate `GVK-ConvoySystem-TriggerGroup` into additional behavior profiles beyond `HoverPatrolHorsefly`.

### Core Behaviors & Triggers
- [ ] **Alliance Research Lab**: Add countdown timers to behavior so players do not assume it is frozen.
- [ ] **Drone Trigger Defaults**:
  - [ ] Switch to message banks for Gaalsien chats to eliminate redundant triggers.
  - [ ] Use `IdsReplacer` for flexible spawn configurations via `CustomText`.
  - [ ] Abstract non-drone specific triggers into universal profiles.

---

## 🟢 P2: Balance & Economy
- [x] **Econ 2 Mission Items** ([#490](https://github.com/GV-Server-Mods/GVK-Settings/issues/490)): Hook `[LootProfiles:GVK-Universal-Loot-Mission]` into wreck manipulation profiles / spawn groups (`Kharak_Loot_Mission` items and loot profile already defined). — DONE: 5 GVK_Recovery_* Component items defined, wired into all 15 UseLootProfiles wreck blocks + Recovery manipulation, exclusive store orders (Rustys/Mastodon/Sevastapol/Skyport + SmuggledGoods at ScrapTownKoth), NLO Cargo Drop & Subawu Rover updated.
- [ ] **Station Services Terminal** ([#494](https://github.com/GV-Server-Mods/GVK-Settings/issues/494)): Enable the services terminal (`ServicesTerminal`) for specific features on NPC stations.
- [ ] **Alliance NPC Cooldown** ([#489](https://github.com/GV-Server-Mods/GVK-Settings/issues/489)): Implement cooldown mechanism for Alliance NPCs to prevent defense spawn spam in dense areas.
- [ ] **Alliance Supply System** ([#476](https://github.com/GV-Server-Mods/GVK-Settings/issues/476)): Implement supply grid delivery mechanic (transporting supply grids from depots to bases to build defense towers).
- [ ] **Dynamic KOTH POIs** ([#451](https://github.com/GV-Server-Mods/GVK-Settings/issues/451)): Add temporary KOTH POIs that generate resources for a short duration and then turn off.
- [ ] **Planetary Installations**: Audit and adjust beacon ranges on Small and Medium Vanilla prefab spawn groups.
- [ ] **Universal Defenses**:
  - [ ] Implement cooldown handshake between alliance drones and parent structures to prevent spawn spam.
  - [ ] Add Coalition wreck defense trigger sets.
- [ ] **Dialogue Variety**: Convert hardcoded chat triggers in `GVK-Universal-TriggerTags-DefeatedChat.sbc` to dialogue banks.

---

## 📋 Backlog & Tech Debt
- [ ] **Drone Tethering Investigation** ([#450](https://github.com/GV-Server-Mods/GVK-Settings/issues/450)): Investigate keeping drones near spawn areas without triggering `WaypointNear` engine crashes.
- [ ] **Infiltration Encounter** ([#420](https://github.com/GV-Server-Mods/GVK-Settings/issues/420)): Design multi-stage stealth/assault encounter with repairable Gaalsien vehicle.

---

## 🔍 Auto-Harvested Inline TODOs
<!-- AUTO-GENERATED-TODOS-START -->
### [Content/Data/Encounters/Alliance/GVK-Alliance-ResearchLab-Behavior.sbc](file:///C:/Users/blayl/source/repos/MDK2 Mods/GVK_Derelicts/Content/Data/Encounters/Alliance/GVK-Alliance-ResearchLab-Behavior.sbc)
- [ ] 📝 **TODO** (Line 5): Add countdowns timers so players don't think it is broken

### [Content/Data/Encounters/Alliance/GVK-Alliance-TriggerTags-Reputation.sbc](file:///C:/Users/blayl/source/repos/MDK2 Mods/GVK_Derelicts/Content/Data/Encounters/Alliance/GVK-Alliance-TriggerTags-Reputation.sbc)
- [ ] 📝 **TODO** (Line 12): If IdsReplacer gets added to EnableTriggerTags, then remove extra triggers for enabling respective faction's trigger.

### [Content/Data/Encounters/Alliance/GVK-Alliance-Universal-Behaviors.sbc](file:///C:/Users/blayl/source/repos/MDK2 Mods/GVK_Derelicts/Content/Data/Encounters/Alliance/GVK-Alliance-Universal-Behaviors.sbc)
- [ ] 📝 **TODO** (Line 7): Switch to message banks

### [Content/Data/Encounters/Alliance/PresetBases/GVK-Alliance-PresetBases-Placeholder-Behavior.sbc](file:///C:/Users/blayl/source/repos/MDK2 Mods/GVK_Derelicts/Content/Data/Encounters/Alliance/PresetBases/GVK-Alliance-PresetBases-Placeholder-Behavior.sbc)
- [ ] 📝 **TODO** (Line 209): Tokenise spawner/spawngroup/faction via IdsReplacer to collapse the per-faction definitions.
- [ ] 📝 **TODO** (Line 278): Optional deployment announcement with current alliance stats (needs new logic - deferred).
- [ ] 📝 **TODO** (Line 279): Upstream MES fix needed - a button panel on another grid can trigger this behavior (TriggerSystem.ProcessButtonTriggers bypasses its same-grid filter for grids outside the logical group). 

### [Content/Data/Encounters/Convoy/Contracts/GVK-EscortMissions-Missions.sbc](file:///C:/Users/blayl/source/repos/MDK2 Mods/GVK_Derelicts/Content/Data/Encounters/Convoy/Contracts/GVK-EscortMissions-Missions.sbc)
- [ ] 📝 **TODO** (Line 6): #480).
- [ ] 📝 **TODO** (Line 11): Add Route A option for single and double escort missions

### [Content/Data/Encounters/Convoy/Contracts/GVK-EscortMissions-Signals.sbc](file:///C:/Users/blayl/source/repos/MDK2 Mods/GVK_Derelicts/Content/Data/Encounters/Convoy/Contracts/GVK-EscortMissions-Signals.sbc)
- [ ] 📝 **TODO** (Line 14): consolidate conditions and actions that are spread across here and EventTemplates files

### [Content/Data/Encounters/Convoy/GaalsienSmallConvoy/GVK-ConvoySystem-TriggerGroup.sbc](file:///C:/Users/blayl/source/repos/MDK2 Mods/GVK_Derelicts/Content/Data/Encounters/Convoy/GaalsienSmallConvoy/GVK-ConvoySystem-TriggerGroup.sbc)
- [ ] 📝 **TODO** (Line 31): (No description provided)

### [Content/Data/Encounters/Drone/Drone-All-TriggerGroup-DroneDefaults.sbc](file:///C:/Users/blayl/source/repos/MDK2 Mods/GVK_Derelicts/Content/Data/Encounters/Drone/Drone-All-TriggerGroup-DroneDefaults.sbc)
- [ ] 📝 **TODO** (Line 19): Switch to message banks so separate triggers are not needed for GAALSIEN chats
- [ ] 📝 **TODO** (Line 19): use IdsReplacer to incorporate flexible spawn options using CustomText from behavior Inits
- [ ] 📝 **TODO** (Line 19): Make the non-drone specific stuff universal

### [Content/Data/Encounters/GVK-Universal-Behavior.sbc](file:///C:/Users/blayl/source/repos/MDK2 Mods/GVK_Derelicts/Content/Data/Encounters/GVK-Universal-Behavior.sbc)
- [ ] 📝 **TODO** (Line 749): Restore the ShareMode-All action tags for PublicSpawnPoint once the MES fix PR lands (ActionSystem.cs reads AllTerminalBlocks[i] instead of [j]; never matches the block and can throw IndexOutOfRange).

### [Content/Data/Encounters/GVK-Universal-TriggerGroup-Defenses.sbc](file:///C:/Users/blayl/source/repos/MDK2 Mods/GVK_Derelicts/Content/Data/Encounters/GVK-Universal-TriggerGroup-Defenses.sbc)
- [ ] 📝 **TODO** (Line 26): Have alliance structure-spawned drones send a command to the structure to reset the cooldown of the Trigger	so that it doesn't reset the counter while drones are still active that could cause too many drones.
- [ ] 📝 **TODO** (Line 26): If the reverse of CommandFromParent is implimented, have wreck use this condition to check if it recevieved a command from its child spawn before refunding a spawn.
- [ ] 📝 **TODO** (Line 26): Add COALITION wreck defenses here.

### [Content/Data/Encounters/GVK-Universal-TriggerTags-DefeatedChat.sbc](file:///C:/Users/blayl/source/repos/MDK2 Mods/GVK_Derelicts/Content/Data/Encounters/GVK-Universal-TriggerTags-DefeatedChat.sbc)
- [ ] 📝 **TODO** (Line 19): Switch to dialogue banks for more variety
- [ ] 📝 **TODO** (Line 20): Probably no need for {EncounterType} since it all uses 1 chat except for ship and structure

### [Content/Data/Encounters/PlanetaryCargoShip/Air Escorts/GVK-PlanetaryCargoShip-Air-Behavior-CoalitionEscortE.sbc](file:///C:/Users/blayl/source/repos/MDK2 Mods/GVK_Derelicts/Content/Data/Encounters/PlanetaryCargoShip/Air Escorts/GVK-PlanetaryCargoShip-Air-Behavior-CoalitionEscortE.sbc)
- [ ] 📝 **TODO** (Line 6): This use of sandbox counter may no longer be needed since Tinsoldier fixed behavior counters not saving

### [Content/Data/Encounters/PlanetaryCargoShip/Land Escorts/GVK-PlanetaryCargoShip-Land-Behavior-CoalitionTraderA.sbc](file:///C:/Users/blayl/source/repos/MDK2 Mods/GVK_Derelicts/Content/Data/Encounters/PlanetaryCargoShip/Land Escorts/GVK-PlanetaryCargoShip-Land-Behavior-CoalitionTraderA.sbc)
- [ ] 📝 **TODO** (Line 6): Clean up redundancy and cross-utilization between RouteA and RouteB Traders and Escort missions using better methods

### [Docs/EscortContractMissions-Design.md](file:///C:/Users/blayl/source/repos/MDK2 Mods/GVK_Derelicts/Docs/EscortContractMissions-Design.md)
- [ ] 📝 **TODO** (Line 6): #480 (On-Demand Escort Spawns) — https://github.com/GV-Server-Mods/GVK-Settings/issues/480

<!-- AUTO-GENERATED-TODOS-END -->

---

## ✅ Completed
- [x] Clamped Alliance zone size counters (0 to 1200) and configured direction announcements (`GVK-Alliance-Events-ZoneSize.sbc`).
- [x] **Zone Condition Consolidation** ([#411](https://github.com/GV-Server-Mods/GVK-Settings/issues/411)): Shared zone names across subtypes and collapsed redundant MES zone condition profiles (`GVK-Universal-ZoneCondition.sbc`).
- [x] **Multi-Tier Index Verification**: Replaced index-dependent boolean matrices with stateless integer marker ladder logic (`GVK-Alliance-Events-ZoneSize.sbc`).
- [x] **SBC Validation & Reference Audit**: Audited repository with `audit_sbc.ps1`, `audit_mes_tags.ps1`, and `audit_mes_references.ps1`; resolved duplicate triggers, missing master gates, and missing spawners.
- [x] **Coalition Wreck Defeated Architecture**: Migrated `GVK-PlanetaryInstallation-Medium-Behavior-COALITIONWreck` to `GVK-Universal-TriggerGroup-DefeatedAndAttacked` using `GVK-Universal-TriggerTags-Compromised` manual trigger to cleanly cancel mission triggers on loss.
- [x] **Vanilla Installation Beacon Ranges**: Standardized vanilla installation prefabs to Kharak canonical beacon ranges (Small 5km, Medium 30km; adjusted `NWS Twinsail Merchant` to 5km and `NWM Bulk Freighter` to 30km).
