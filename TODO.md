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
- [x] **Cross-Grid Trigger Bypass**: Upstream button panel trigger bypass (`TriggerSystem.ProcessButtonTriggers` executing across different grids) — merged upstream as MES #360. Remove the inline TODO in `GVK-Alliance-PresetBases-Placeholder-Behavior.sbc` once the server runs a MES build that includes it.
- [x] **ChangeBlocksShareModeAll MES Bug**: indexing bug in `ActionSystem.cs` (`grid.AllTerminalBlocks[i]` instead of `[j]`) — merged upstream as MES #369 (issue #370), listed in the MES 2.74.04 patch notes. The share-mode tags are restored on `GVK-Universal-Action-PublicSpawnPoint`; the KOTHOutpost spawn point becomes public once the server runs MES 2.74.04 or later.
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
- [ ] **Re-enable Weapon Randomization**: set MES `RandomizedWeaponsUseFullRange` to `true` (`Config-Grids.xml` or `/MES.Settings.Grids.RandomizedWeaponsUseFullRange.true`). Randomized NPCs then skip MES's 800m cap and spawn at WeaponCore's full range, which avoids the 0m range bug without waiting for the MES fix. Only affects new spawns, and applies to every randomized NPC server-wide. Then restore the commented-out `[ManipulationProfiles:GVK-Universal-Manipulation-*Turrets]` lines in the spawn groups. Don't use `[SetWeaponsToMaxRange:]` / `[SetWeaponsToMinRange:]` actions until the MES fix ships (they still hit the bug).
- [ ] **StrikeFighter → FighterPlane**: Consider moving the StrikeFighter drones (`GVK-Drone-All-TriggerGroup-PatrolStrike` switches them to the `Strike` subclass) to MES's newer `FighterPlane` behavior subclass (`Behavior/FighterPlane.cs`, MES `6d6d412`). It reads the same autopilot `AttackRun*` tags, so `GVK-Drone-All-Autopilot-StrikeFighter-Strike` carries over.
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

## 🐞 Upstream MES Bugs (report / PR to MES)
Verified against MES source at commit `537c875` (2026-09-24) unless marked *observed*. File paths are under `Data/Scripts/ModularEncountersSystems/`; line numbers are at that commit. Grouped into the reports to file. Upstream items already tracked elsewhere: Cross-Grid Trigger Bypass and ChangeBlocksShareModeAll (both in P0).
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
- [ ] **Store `[ItemsRequireInventory:]` does nothing**: declared at `Spawning/Profiles/StoreProfile.cs:29`, never parsed or read. GVK impact: set on 12 store profiles.

### Report C: Missions
- [ ] **`[EventConditionIds:]` is ignored** — fixed in MES PR #372 (open, tested in-game): parsed in `Mission/MissionProfile.cs:110`, but `Mission/Mission.cs:311` loops over `Profile.PlayerConditionIds` a second time instead of `Profile.EventConditionIds` when building the mission's event conditions. GVK impact: none today; avoid the tag until fixed (use `[PersistantEventConditionIds:]`).

### Report E: WeaponCore ranges (low priority for GVK)
- [ ] **WeaponCore 0m ranges and related bugs** (upstream #332): MES branch `fix/weaponcore-range-desync`, PR 4 in `Docs/MES-Upstream-Drafts.md`; old branch kept as `backup/weaponcore-range-desync`. GVK doesn't need it once `RandomizedWeaponsUseFullRange` is on (see P1). Before submitting, one quick test: a `[SetWeaponsToMaxRange:true]` action gives turrets their real max range (not 0m), and `[SetWeaponsToMinRange:true]` gives 800m.

### Report D: Commands can't address the parent grid (feature request)
- [ ] A spawner stores `ParentId = _behavior.RemoteControl.OwnerId` (`Behavior/Subsystems/Trigger/ActionSystem.cs:403`), an owner identity rather than a grid, and `[CommandCheckFromParent:]` compares the command's owner identity to it (`Behavior/Subsystems/Trigger/ConditionProfile.cs:1746`). So "from parent" means "from any grid with the same owner as the one that spawned me". A `[SingleRecipient:true]` command goes to the first listener that processes it (`Behavior/Subsystems/Trigger/TriggerSystem.cs:763`), not the nearest or the parent. Ask: store the parent Remote Control entity id in `NpcData`, add a "send to parent only" command option, and check the parent by entity id. GVK impact: a despawning defense drone's refund can go to the wrong structure (see "Defense refund targets the wrong structure" below).

### Report F: Spawner cooldown timing
- [ ] **A spawner's first cooldown counts from world load, not from when its grid spawned** (noted, not fixed, in MES issue #371): `SpawnProfile` sets `LastSpawnTime` in its constructor (`Behavior/Subsystems/Trigger/SpawnProfile.cs:140`), which runs once when `ProfileManager` builds the template at world load. `LastSpawnTime` is a serialized `[ProtoMember(10)]`, so every grid that later loads the spawner gets the world-load time, and `IsReadyToSpawn` (`:242-244`) measures `[SpawnMinCooldown:]`/`[SpawnMaxCooldown:]` (in seconds) from it. With `[StartsReady:false]`, a spawner on a grid that spawns later than the cooldown after world load can spawn right away; one on a grid that spawns earlier waits out the rest of it. Later cooldowns work: `Spawning/BehaviorSpawnHelper.cs:180-182` / `:203-205` set `LastSpawnTime` and `SpawnCount` after each successful spawn. `SpawnProfile.ProcessSuccessfulSpawn` (`:266`) is never called, and `TriggerProfile.ResetTime` (`Behavior/Subsystems/Trigger/TriggerProfile.cs:509`) only resets the legacy `SpawnerDefunct`. Ask: set `LastSpawnTime` when the spawner is attached to a behavior (for example in `TriggerProfile.InitRandomTimes`, `:532`). GVK impact: `GVK-Drone-All-Spawner-SpawnInterceptorSingle-GAALSIEN` has `[SpawnMinCooldown:180000]` (50 hours; probably meant as ms) behind a `[MaxActions:1]` trigger, so before `[StartsReady:]` was parsed it only spawned if the world had been loaded for 50 hours. With the `fix/tag-parsing` build, Honorguard and HoverCruiserHorsefly Gaalsien drones will spawn their interceptor once when a player comes within 1.5 km.

### Not yet traced in source
- [ ] **Grid targeting needs a player to wake it** (*observed*): `GVK-Universal-Target-EnemyPlayerAndGrid2km` only detects enemy grids while a player is also around to wake the targeting, so a player sitting in a cockpit is effectively untargetable as a grid. Trace in `Behavior/Subsystems/AutoPilot/TargetingSystem.cs` before reporting; keep the profile for when it is fixed.

---

## 🧩 Unfinished Mechanics (from the 2026-09-24 unused-profile review)
Profiles that exist but are not wired into anything yet.
- [ ] **KHAANEPH Production Cruiser**: `GVK-Drone-All-Behavior-ProductionCruiser-KHAANEPH` and `GVK-Drone-Elite-Behavior-ProductionCruiser-KHAANEPH` exist, but there is no `NDR [KHAA] Production Cruiser` prefab. Build the prefab, then add it to `GVK-Drone-Defense-SpawnGroup-KHAANEPH-LargeHover` and `GVK-Boss-SpawnGroup-KHAANEPH-LargeCruiserSingle`.
- [ ] **KHAANEPH Large Hover variety**: `GVK-Drone-Defense-SpawnGroup-KHAANEPH-LargeHover` now has the Siege and Honorguard cruisers. The Assault, Hurricane and Railgun cruiser prefabs also exist; consider adding them to match the GAALSIEN Large Hover group.
- [ ] **Move drones to the KPL trigger groups**: goal is for drones to use the KPL (Known Player Location) versions of the Patrol groups wherever possible. Keep the non-KPL groups (`PatrolFighter`, `PatrolHorsefly`, `PatrolHorseFighter`, used by SOBAN/KHAANEPH today) until the KPL retest below passes. `GVK-Drone-All-TriggerGroup-PatrolFighter` is the non-KPL twin of `PatrolFighterKPL` (fixed guns on targets in range, back to patrol when not engaging).
- [ ] **Invulnerable Until Player Near (on hold)**: the trigger group now works (it was sending `true`/`false` to `[GridDestructible:]`, which only accepts `Yes`/`No`, so it never did anything; it also now starts invulnerable). Deliberately not attached to anything. Edge cases to solve before using it: a drone is also invulnerable to unattended player turrets when no player is within 4 km (offline or AFK bases can't kill raiders, but still take damage); only grids carrying it are protected, so a one-sided fight still destroys the other NPC (convoys, Alliance structures would need it too); a player sniping from beyond 4 km can't hurt it.
- [ ] **Defense refund targets the wrong structure**: the exploit (trigger defenses, leave so they despawn, come back to an undefended target) is handled by the despawn refund: a defense drone that *despawns* (not destroyed) sends `DefensesRefundCounter` (`GVK-Universal-TriggerTags-RefundDefensesCommand`, single recipient, same owner, 6 km) and the structure's `GVK-Universal-Trigger-DefensesRefundCounter` decreases `DefenseSpawn_Counter`. What's left: MES delivers a single-recipient command to the first same-owner listener in range, not the drone's own parent, so with two defended structures within 6 km the wrong one can get the refund. `GVK-Universal-Condition-ReceiveCommandFromParent` can't fix it (see Upstream MES Bugs, Report D). Needs the MES PR, or a workaround such as per-structure command codes.
- [ ] **Retire the Defense Heartbeat**: `GVK-Universal-TriggerGroup-Send/ReceiveDefenseHeartbeat` (structure pings its defenses every 30 s within 4 km; drones retreat after 30 min with no target or 6 h total) solved the same exploit but keeps drones loaded, since they must be exempt from concealment. Superseded by the refund above; delete once the refund is reliable.
- [ ] **Reputation on Player Damage**: `GVK-Universal-Condition-DamagedByEnemyPlayer` / `-DamagedByNeutralPlayer` check the `DamagedByEnemyPlayer` / `DamagedByNeutralPlayer` booleans set by the AttackerIsEnemy/NeutralPlayer triggers in `GVK-Universal-TriggerGroup-DefeatedAndAttacked`. Finish the relation/reputation mechanic that consumes them.
- [ ] **Beacon Disabled Condition**: `GVK-Universal-Condition-BeaconDisabled-WIP` uses `[RequiredNoneFunctionalBlockNames:]`. Retest on current MES with `/MES.BehaviorDebug.Condition.true`. Known limits in `ConditionProfile.cs`: the watched-block list is built once at behavior start by exact CustomName, so beacons renamed afterwards (for example by spawn-group BeaconText) or replaced are never watched.
- [ ] **KPL Targeting Rebuild**: `GVK-Universal-Target-EnemyGridsinKPL` was meant to keep drones on enemies near their spawn area and break off the chase once players leave, but KPLs kept removing themselves.
  - Observed: KPLs sometimes vanished within seconds of creation while a player was standing inside.
  - MES history: `KnownPlayerLocationManager.cs` has had no functional change in the past month (only the `Factions` → `AllowedFactions` rename in `e2d53a7`, 2026-09-07). `d2a18a2` (2025-08-03) fixed two bugs that match "gone within seconds": a KPL without MaxSpawns was removed by the next spawn request after creation (`MaxSpawnedEncounters` defaulted to 0 and `0 >= 0` passed), and `RemoveLocation` removed KPLs of every faction *except* the caller's. GVK's KPL notes date from Jan 2025, before that fix.
  - Every path in current MES that can remove a KPL (traced 2026-09-24): spawn-count cap (`CleanExpiredLocations`, on every spawn request); timer expiry (`TimerChecks` every 10 s and `CleanExpiredLocations`, both reset while a player is inside a timed KPL); radius ≤ 0; merge with a newer overlapping KPL (replaced, not lost); `RemoveLocation` (the `RemoveKnownPlayerArea` action or the API; GVK no longer uses it); world load (all KPLs, see Upstream MES Bugs). With a player inside, only the spawn cap and `RemoveLocation` can remove a GVK KPL today. The Patrol*KPL groups set `[KnownPlayerAreaMaxSpawns:5]`, and a wreck's defense wave plus escorts can spawn 5 GAALSIEN groups inside the 3 km sphere within seconds.
  - Also note: a KPL owned by a faction acts as an allowed-faction zone, so while a player stands in a GAALSIEN KPL only GAALSIEN spawn groups can spawn there.
  - Retest with `/MES.SpawnDebug.Zone.true` (plus `.GameLog.true`): every removal path except timer expiry writes its reason ("Exceeded Spawn Count", "Timer Expired", "Radius is 0 or Less", "Has Been Removed"). Then drop the spawn cap, use a longer timer (not `-1`, which hits the 60-min bug), move drones to the KPL groups, and have target-relay grids (`GVK-Universal-TriggerGroup-SendTargets`) add KPLs to extend the engagement area for nearby drones. Expect KPLs to reset on every restart until the world-load bug is fixed.

## 🧹 Unused Profile Cleanup (decide keep / delete)
- [ ] **Old explosion triggers**: the six `GVK-Universal-Trigger-{Small,Medium,Large}{,Blue}ExplosionEffects` (Compromised-type) are superseded by the tag system in `GVK-Universal-TriggerTags-Explosions.sbc` (blue for GAALSIEN/KHAANEPH, regular for everyone else). Delete the six triggers; keep the six explosion actions.
- [ ] **Targets**: `GVK-Universal-Target-EnemyAllianceGrids` (SOBAN/KHAANEPH prioritizing each other; didn't help), `GVK-Universal-Target-EnemyGrids4km`.
- [ ] **Conditions**: `GVK-Universal-Condition-ReceiveCommandFromParent` (keep until the parent-command PR decides the defense refund). `GVK-Universal-Condition-GridSizeSmall` was removed on 2026-09-24 (superseded by the aircraft check in `GVK-Universal-TriggerTags-AttemptSmallDespawn`).
- [ ] **Tags MES ignores**: `[ItemsRequireInventory:]` in 12 store profiles (no parser), `[SubGridsEditable:]` in 2 `[MES Manipulation]` profiles in `GVK-PlanetaryInstallation-All-Manipulation.sbc` (Action-only tag; `[GridsAreEditable:]` is the manipulation one), `[InitializeStoreBlocks:]` in the 2 `GVK-Static-Generic-SpawnCondition-*` profiles (SpawnGroup-only tag).
- [ ] **Behaviors**: `GVK-PlanetaryInstallation-PlayerKOTH-Behavior`, `GVK-Static-KOTHTown-Behavior`.
- [ ] **Chat / command / weapons**: `GVK-Alliance-EncounterType-Chat-Defenses-Faction`, `GVK-Universal-Chat-SPRTBattleChatter`, `GVK-Other-Recovery-Command-Repaired`, `GVK-Universal-Weapons-GAALSIEN-Carrier`.
- [ ] **Trigger**: `GVK-Drone-All-Trigger-FireRockets/FireFlares/FireRailgunsTimers`.
- [ ] **Waypoints**: `GVK-CargoShip-StaticRandom-AngelsLanding/Rustys/Sevastapol`, `GVK-Static-TradeStation-Waypoint-RelativeRandom`, `GVK-Convoy-WaypointStatic-LandRouteA01/A02/A06a`, the empty `GVK-Convoy-WaypointStatic-` stub (no coordinates), `GVK-Convoy-Waypoint-LandRouteD00 Start`.
- [ ] **Spawn conditions**: `GVK-Boss-SpawnCondition-GAALSIEN-LargeHoverSingle_Old`, `GVK-Drone-Defense-SpawnCondition-COALITION-MediumFlyerSingle`, `GVK-Drone-Encounter-SpawnCondition-KHAANEPH`, `GVK-PlanetaryInstallation-Large-SpawnCondition-PlayerKOTH`, `-Large-SpawnCondition-Wreck-GAALSIEN`, `-Medium-SpawnCondition-Building-RANDOM`, `-Small-SpawnCondition-Building-RANDOM`, `GVK-Static-Generic-SpawnCondition-COALITIONStation/GAALSIENStation`.
- [ ] **Zone conditions**: `GVK-Universal-ZoneConditions-COALITIONArea`, `-WreckZone12`.
- [ ] **Manipulation**: `GVK-Alliance-Base-Manipulation`, `GVK-Alliance-ToKHAANEPHColor-Manipulation`, `GVK-Alliance-ToSOBANColor-Manipulation`, `GVK-PlanetaryInstallation-Large-Manipulation-PlayerKOTH`, `-Small-Manipulation-GAALSIENStructures`, `-Small-Manipulation-OilRigs`.
- [ ] **Other**: `GVK-Replacer-NPCWeapons`, `GVK-Replacer-ProgrammableBlocks` (may be used from MES world config), `GVK-Universal-Dereliction-DerelictTurrets-Functional`, `GVK-Universal-Replenishment`, `GVK-Store-StoreProfile-COALITIONTrader`.
- [ ] **Keep**: `GVK-Convoy-EventCondition-CoalitionA/B/E` belong to the disabled ambient convoy events.
- [ ] **Commented-out duplicate**: an old commented-out `GVK-ScrapRace-SpawnGroup-Set09` block (around line 935 of `GVK-Static-Generic-SpawnGroup.sbc`) now shares its name with the active one.

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
- [ ] 📝 **TODO** (Line 34): .md, Upstream MES Bugs); use

<!-- AUTO-GENERATED-TODOS-END -->

---

## ✅ Completed
- [x] Clamped Alliance zone size counters (0 to 1200) and configured direction announcements (`GVK-Alliance-Events-ZoneSize.sbc`).
- [x] **Zone Condition Consolidation** ([#411](https://github.com/GV-Server-Mods/GVK-Settings/issues/411)): Shared zone names across subtypes and collapsed redundant MES zone condition profiles (`GVK-Universal-ZoneCondition.sbc`).
- [x] **Multi-Tier Index Verification**: Replaced index-dependent boolean matrices with stateless integer marker ladder logic (`GVK-Alliance-Events-ZoneSize.sbc`).
- [x] **SBC Validation & Reference Audit**: Audited repository with `audit_sbc.ps1`, `audit_mes_tags.ps1`, and `audit_mes_references.ps1`; resolved duplicate triggers, missing master gates, and missing spawners.
- [x] **Coalition Wreck Defeated Architecture**: Migrated `GVK-PlanetaryInstallation-Medium-Behavior-COALITIONWreck` to `GVK-Universal-TriggerGroup-DefeatedAndAttacked` using `GVK-Universal-TriggerTags-Compromised` manual trigger to cleanly cancel mission triggers on loss.
- [x] **Vanilla Installation Beacon Ranges**: Standardized vanilla installation prefabs to Kharak canonical beacon ranges (Small 5km, Medium 30km; adjusted `NWS Twinsail Merchant` to 5km and `NWM Bulk Freighter` to 30km).
