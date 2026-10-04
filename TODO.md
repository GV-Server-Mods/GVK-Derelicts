# GVK_Derelicts Project Tracker & TODOs

Work for **GVK_Derelicts** is tracked as GitHub issues in **GV-Server-Mods/GVK-Settings** (Issues are disabled on this repo):
[open `area:npc` issues](https://github.com/GV-Server-Mods/GVK-Settings/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Anpc).
This file keeps only what does not belong there: upstream MES bug reports, on-hold ideas, and the auto-harvested inline TODOs.

---

## 🛠️ Workflow & Usage
* **New work**: open an issue in GVK-Settings (`area:npc`, or `area:economy` for stores, contracts and loot). See `Docs/agents/issue-tracker.md`.
* **Inline Code TODOs**: Leave `<!-- TODO: ... -->` in `.sbc` files or `// TODO: ...` in `.cs` files.
* **Auto-Sync Script**: Run the following command from PowerShell to refresh the auto-harvested section below:
  ```powershell
  pwsh -File .\tools\Get-Todos.ps1 -UpdateFile
  ```

---

## 🐞 Upstream MES Bugs (report / PR to MES)
Verified against MES source at commit `537c875` (2026-09-24) unless marked *observed*. File paths are under `Data/Scripts/ModularEncountersSystems/`; line numbers are at that commit. Grouped into the reports to file. Already merged upstream, waiting on the server MES build: Cross-Grid Trigger Bypass (MES #360; then remove the inline TODO in `GVK-Alliance-PresetBases-Placeholder-Behavior.sbc`) and ChangeBlocksShareModeAll (MES #369, MES 2.74.04; the KOTHOutpost spawn point becomes public once the server runs it).
PR branches and issue drafts (2026-09-25): see `Docs/MES-Upstream-Drafts.md`. `fix/sharemode-all-index` merged as MES #369; `fix/tag-parsing` (Report B + C) open as MES PR #372 / issue #371; `fix/known-player-locations` (Report A bugs) not yet submitted; issues drafted for KPL resize, Report D and unused tags.

### Report A: Known Player Locations (KPLs)
Context: `d2a18a2` (2025-08-03) already fixed a KPL without MaxSpawns being deleted by the next spawn request (default `MaxSpawnedEncounters` 0 passed `0 >= 0`) and `RemoveLocation` removing other factions' KPLs instead of the caller's. Those matched GVK's "KPL vanished within seconds while I stood in it" reports from Jan 2025.
- [ ] **KPLs are deleted on every world load**: `Zones/ZoneManager.cs:65-75` (`Setup`) removes every saved zone whose `ProfileSubtypeId` is empty ("Removing Zone With No ProfileSubtypeId"). KPLs are created by `Zone.InitAsKnownPlayerLocation`, which never sets one, so every KPL is wiped on each server restart. Present since 2021. Fix: skip the profile checks for `PlayerKnownLocation` zones.
- [ ] **Timer expiry removes zones silently**: `Zones/ZoneManager.cs:648` (`TimerChecks`) removes an expired timed zone or KPL with no log line and no player notification, unlike every other removal path (which log under `SpawnDebug.Zone` and call `AlertPlayersOfRemovedKPL`). Fix: log the removal and notify.
- [ ] **A KPL with no timer still expires after ~60 min**: with `[KnownPlayerAreaTimer:-1]`, `InitAsKnownPlayerLocation` leaves `MinutesToExpiration` at the Zone default of 60 (`Zones/Zone.cs:119`), and `Zones/KnownPlayerLocationManager.cs:149` (`CleanExpiredLocations`, run on every spawn request) checks it without checking `UseZoneTimer`. Nothing refreshes `TimeCreated` for an untimed KPL, so it is deleted ~60 min after creation (or after its last spawn). Fix: gate that check on `UseZoneTimer`.
- [ ] **KPLs can't be resized (bug + feature request)**: the zone radius actions (`[ZoneRadiusChangeType:]`, MES Event `[ZoneRadiusChangeTypes:]`) call `ZoneManager.ChangeZoneRadius`, which only touches zones that are `Persistent` with a matching `PublicName` (`Zones/ZoneManager.cs:523`); KPLs are neither, so an NPC can never grow its KPL and can only create another, which merges. Before `c153124` (2026-09-08) that function's position check was inverted and it compared the wrong name field. The KPL-specific `KnownPlayerLocationManager.ChangeZoneSizeAtLocation` (`:107`) is broken and unreachable: its check at `:111` is inverted (it resizes every zone that does *not* contain the position, persistent ones included), it never refreshes the cached `Zone.Sphere` (`Zones/Zone.cs:80`), and nothing calls it (`API/MESApi.cs:22` only declares a private `_changeKnownPlayerLocationSize` field; no public method, no `LocalAPI` registration). Ask: a RivalAI action to grow/shrink the KPL at the grid's position, with the check fixed and `Sphere`/`RadiusSquared` refreshed.
- [ ] **KPL merge bugs**: `Zones/Zone.cs:185` normalizes the vector between the two centers, so a new KPL created at exactly the position of an existing one (a stationary grid) produces NaN coordinates and radius; a NaN KPL counts as containing every position for KPL triggers and targeting (`Distance > NaN` is false) and is never refreshed by player presence. `MergeVariablesFromOldLocation` (`Zones/Zone.cs:224-255`) copies the new zone's own values instead of the old zone's (`:239` adds `boolresult` instead of the old bool, `:255` adds the zone's own counter to itself), and the merged KPL restarts `SpawnedEncounters` and `TimeCreated`.
- [ ] **`UseKPL` switches are inverted**: `Behavior/Subsystems/Trigger/ActionSystem.cs:1932` and `:1940` call the named-zone function when `[ZoneCustomBoolChangeUseKPL:true]` / `[ZoneCustomCounterChangeUseKPL:true]` and the KPL function when false.

### Report B: Tag values and tags that silently do nothing
- [ ] **Yes/No tags fail silently on a bad value** — fixed in MES PR #372 (open, tested in-game): `Helpers/TagParse.cs:343-350` (`TagCheckEnumCheck`) uses a case-sensitive `Enum.TryParse` and returns without a log on failure, so `true`, `false` or `yes` leave the field at `Ignore` and the action does nothing. Used by `[GridDestructible:]`, `[SubGridsDestructible:]`, `[GridEditable:]`, `[SubGridsEditable:]` (RivalAI Action) and `[IsStatic:]` (RivalAI Target). enenra declined accepting `true`/`false`; the PR logs bad values to the game log with the profile SubtypeId (`<Profile>: Could not parse tag '[GridEditable:true]' (expected Yes, No or Ignore)`) and lists `Ignore` on the wiki. Only `Yes`, `No` and `Ignore` (exact case) work. Every other `TagParse` value parser is still silent on failure.
- [ ] **Escort autopilot tags are never parsed** — fixed in MES PR #372 (open, tested in-game). Even once parsed, `EscortSpeedMatchMinDistance` has no effect (`Behavior/Escort.cs:110-112` discards the lerped speed; noted in issue #371): `Behavior/Subsystems/AutoPilot/AutoPilotProfile.cs:174-176` declares `EscortUsesRelativeDampening`, `EscortSpeedMatchMinDistance`, `EscortSpeedMatchMaxDistance` (defaults false / 25 / 150 at `:327-329`) and `Behavior/Escort.cs:90`, `:104`, `:110` read them, but `InitTags` has no parser, so the tags are ignored. GVK impact: `GVK-Convoy-Escort-PrimaryAutopilot`, both `Drone-All-Autopilot-Baserunner` profiles and both `Drone-All-Autopilot-MediumHoverPatrolHorsefly` profiles run on the defaults instead of 0–25 m speed matching with relative dampening; possibly related to [#484](https://github.com/GV-Server-Mods/GVK-Settings/issues/484) / [#449](https://github.com/GV-Server-Mods/GVK-Settings/issues/449).
- [ ] **Spawner `[StartsReady:]` is never parsed** — fixed in MES PR #372 (open, tested in-game): `Behavior/Subsystems/Trigger/SpawnProfile.cs:18` declares it and `:246` reads it, but there is no tag parser, so it is always false. GVK impact: set on 73 `[RivalAI Spawn]` profiles with no effect (low impact: a spawner's first cooldown starts at 0).
- [ ] **Store `[ItemsRequireInventory:]` does nothing**: declared at `Spawning/Profiles/StoreProfile.cs:29`, never parsed or read. GVK impact: none; the 12 `[ItemsRequireInventory:false]` tags were removed on 2026-10-04, since `false` is also the field default.

### Report C: Missions
- [ ] **`[EventConditionIds:]` is ignored** — fixed in MES PR #372 (open, tested in-game): parsed in `Mission/MissionProfile.cs:110`, but `Mission/Mission.cs:311` loops over `Profile.PlayerConditionIds` a second time instead of `Profile.EventConditionIds` when building the mission's event conditions. GVK impact: none today; avoid the tag until fixed (use `[PersistantEventConditionIds:]`).

### Report G: Contract blocks (sent to enenra on Discord, 2026-10-04)
- [ ] **`MinContracts` / `MaxContracts` do nothing**: `Spawning/Profiles/ContractBlockProfile.cs:24-25` declares them (default 10/10) and `:47-48` parses them, but nothing reads them. `ApplyProfileToBlock` (`:110`) loops over every `MissionIds` entry and posts each mission whose `Init` succeeds, so the contract count is just "every eligible mission". Confirmed on upstream `2361acf` (2026-10-04). GVK impact: none today (Convoy Contracts, [#675](https://github.com/GV-Server-Mods/GVK-Settings/issues/675), list 3 missions). Also reported: `Behavior/Subsystems/Trigger/ActionSystem.cs:2572` logs "Couldn't find Mission Profile" for a missing contract block profile.
  - Status: waiting on enenra. Check for the fix after `git fetch upstream` in the MES clone: `git grep -n "MinContracts\|MaxContracts" upstream/master` shows more than the declaration/parse lines once something reads them. When it lands, tick this off and note the MES commit.

### Report H: Terrain (asked enenra on Discord, 2026-10-04)
- [ ] **`[MatchTerrainType:]` doesn't check the grid's terrain**: `Behavior/Subsystems/Trigger/ConditionProfile.cs:1174-1180` compares `NpcData.TerrainTypeName`, which `Spawning/PrefabSpawner.cs:202` sets once from `EnvironmentEvaluation.CommonTerrainAtPosition`. That is the most common material within ~165 m of the spawn request position (the player, for random installations), not where the grid landed. The live lookup at the Remote Control position is commented out at `ConditionProfile.cs:1168-1170`. GVK impact: `GVK-Universal-TriggerGroup-TerrainSkin` ([#676](https://github.com/GV-Server-Mods/GVK-Settings/issues/676)) can pick the wrong skin near a biome edge. Becomes exact with no GVK change once fixed.
- [ ] **`[MatchTerrainType:]` always passes** (found in testing 2026-10-04: a wreck on grass got Frozen). Two bugs in the same block (`ConditionProfile.cs:1160-1190`):
  - It never does `usedConditions++`. With the default `[MatchAnyCondition:false]`, a condition profile that only uses MatchTerrainType compares `satisfied >= 0`, which is always true.
  - With `[MatchAnyCondition:true]` (as MSB uses it), `if (_behavior.AutoPilot.CurrentPlanet == null) satisfiedConditions++;` passes it anyway. `CurrentPlanet` is only set in `AutoPilotSystem.CalculateCurrentWaypoint` (`:934`), which a Passive behavior never reaches: `ThreadedAutoPilotCalculations` returns early when `CurrentAutoPilot == None` on first run (`:536-540`). So on wrecks, CurrentPlanet stays null.
  - GVK impact: every terrain trigger in the group fires, and the first one (Frozen) wins.
- [ ] *Not yet reported:* `Behavior/Subsystems/GridSystem.cs` `RecolorBlocks` loops over `AllBlocks` but removes an invalid block with `AllTerminalBlocks.RemoveAt(j)` (same `[i]`/`[j]` list mix-up class as MES #369). Only hits when the grid has a destroyed block, so it doesn't affect the spawn-time skin swap.

### Report E: WeaponCore ranges (low priority for GVK)
- [ ] **WeaponCore 0m ranges and related bugs** (upstream #332): MES branch `fix/weaponcore-range-desync`, PR 4 in `Docs/MES-Upstream-Drafts.md`; old branch kept as `backup/weaponcore-range-desync`. GVK doesn't need it once `RandomizedWeaponsUseFullRange` is on ([#666](https://github.com/GV-Server-Mods/GVK-Settings/issues/666)). Before submitting, one quick test: a `[SetWeaponsToMaxRange:true]` action gives turrets their real max range (not 0m), and `[SetWeaponsToMinRange:true]` gives 800m.

### Report D: Commands can't address the parent grid (feature request)
- [ ] A spawner stores `ParentId = _behavior.RemoteControl.OwnerId` (`Behavior/Subsystems/Trigger/ActionSystem.cs:403`), an owner identity rather than a grid, and `[CommandCheckFromParent:]` compares the command's owner identity to it (`Behavior/Subsystems/Trigger/ConditionProfile.cs:1746`). So "from parent" means "from any grid with the same owner as the one that spawned me". A `[SingleRecipient:true]` command goes to the first listener that processes it (`Behavior/Subsystems/Trigger/TriggerSystem.cs:763`), not the nearest or the parent. Ask: store the parent Remote Control entity id in `NpcData`, add a "send to parent only" command option, and check the parent by entity id. GVK impact: a despawning defense drone's refund can go to the wrong structure ([#663](https://github.com/GV-Server-Mods/GVK-Settings/issues/663)).

### Report F: Spawner cooldown timing
- [ ] **A spawner's first cooldown counts from world load, not from when its grid spawned** (noted, not fixed, in MES issue #371): `SpawnProfile` sets `LastSpawnTime` in its constructor (`Behavior/Subsystems/Trigger/SpawnProfile.cs:140`), which runs once when `ProfileManager` builds the template at world load. `LastSpawnTime` is a serialized `[ProtoMember(10)]`, so every grid that later loads the spawner gets the world-load time, and `IsReadyToSpawn` (`:242-244`) measures `[SpawnMinCooldown:]`/`[SpawnMaxCooldown:]` (in seconds) from it. With `[StartsReady:false]`, a spawner on a grid that spawns later than the cooldown after world load can spawn right away; one on a grid that spawns earlier waits out the rest of it. Later cooldowns work: `Spawning/BehaviorSpawnHelper.cs:180-182` / `:203-205` set `LastSpawnTime` and `SpawnCount` after each successful spawn. `SpawnProfile.ProcessSuccessfulSpawn` (`:266`) is never called, and `TriggerProfile.ResetTime` (`Behavior/Subsystems/Trigger/TriggerProfile.cs:509`) only resets the legacy `SpawnerDefunct`. Ask: set `LastSpawnTime` when the spawner is attached to a behavior (for example in `TriggerProfile.InitRandomTimes`, `:532`). GVK impact: `GVK-Drone-All-Spawner-SpawnInterceptorSingle-GAALSIEN` has `[SpawnMinCooldown:180000]` (50 hours; probably meant as ms) behind a `[MaxActions:1]` trigger, so before `[StartsReady:]` was parsed it only spawned if the world had been loaded for 50 hours. With the `fix/tag-parsing` build, Honorguard and HoverCruiserHorsefly Gaalsien drones will spawn their interceptor once when a player comes within 1.5 km.

### Not yet traced in source
- [ ] **Grid targeting needs a player to wake it** (*observed*): `GVK-Universal-Target-EnemyPlayerAndGrid2km` only detects enemy grids while a player is also around to wake the targeting, so a player sitting in a cockpit is effectively untargetable as a grid. Trace in `Behavior/Subsystems/AutoPilot/TargetingSystem.cs` before reporting; keep the profile for when it is fixed.

---

## ⏸️ On Hold
- [ ] **Invulnerable Until Player Near (on hold)**: the trigger group now works (it was sending `true`/`false` to `[GridDestructible:]`, which only accepts `Yes`/`No`, so it never did anything; it also now starts invulnerable). Deliberately not attached to anything. Edge cases to solve before using it: a drone is also invulnerable to unattended player turrets when no player is within 4 km (offline or AFK bases can't kill raiders, but still take damage); only grids carrying it are protected, so a one-sided fight still destroys the other NPC (convoys, Alliance structures would need it too); a player sniping from beyond 4 km can't hurt it.

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
- [ ] 📝 **TODO** (Line 15): Add Route A option for single and double escort missions

### [Content/Data/Encounters/Convoy/Contracts/GVK-EscortMissions-Signals.sbc](file:///C:/Users/blayl/source/repos/MDK2 Mods/GVK_Derelicts/Content/Data/Encounters/Convoy/Contracts/GVK-EscortMissions-Signals.sbc)
- [ ] 📝 **TODO** (Line 14): consolidate conditions and actions that are spread across here and EventTemplates files

### [Content/Data/Encounters/Convoy/GaalsienSmallConvoy/GVK-ConvoySystem-TriggerGroup.sbc](file:///C:/Users/blayl/source/repos/MDK2 Mods/GVK_Derelicts/Content/Data/Encounters/Convoy/GaalsienSmallConvoy/GVK-ConvoySystem-TriggerGroup.sbc)
- [ ] 📝 **TODO** (Line 31): (No description provided)

### [Content/Data/Encounters/Drone/Drone-All-TriggerGroup-DroneDefaults.sbc](file:///C:/Users/blayl/source/repos/MDK2 Mods/GVK_Derelicts/Content/Data/Encounters/Drone/Drone-All-TriggerGroup-DroneDefaults.sbc)
- [ ] 📝 **TODO** (Line 19): Switch to message banks so separate triggers are not needed for GAALSIEN chats
- [ ] 📝 **TODO** (Line 19): use IdsReplacer to incorporate flexible spawn options using CustomText from behavior Inits
- [ ] 📝 **TODO** (Line 19): Make the non-drone specific stuff universal

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

<!-- AUTO-GENERATED-TODOS-END -->
