# GVK_Derelicts - MES & SBC Modding Guidelines

This document serves as the project-specific rules, quirks reference, and engineering guide for AI agents and developers working on **GVK_Derelicts**.

---

## 1. Modular Encounters Systems (MES) Source of Truth

- **WebWiki Is Outdated**: Online wikis and guides lack the newest features, contain human errors, or describe obsolete workarounds.
- **Physical Codebase Reference**: Always verify tag names, casing, and logic against the local MES source code:
  `C:\Users\blayl\AppData\Roaming\SpaceEngineers\Mods\Modular-Encounters-Systems\Data\Scripts\ModularEncountersSystems`
- **Key Inspection Targets**:
  - `Events\Action\EventActionProfile.cs` & `EventActionReference.cs` (MES Event Action tags)
  - `Events\Action\EventActionExecution.cs` (How event actions execute)
  - `Events\Condition\EventConditions.cs` (MES Event Condition tags and checks)
  - `Events\Event.cs` & `EventManager.cs` (Cooldowns, lifecycles, and triggers)
  - `Helpers\TagParse.cs` (Enum and list parsing logic)
  - `Spawning\SpawnRequest.cs` & `BehaviorSpawnHelper.cs` (Encounter spawning pipeline)

---

## 2. MES Event System vs. RivalAI Grid Trigger System

MES Events run globally via `EventManager` (server-authoritative, no physical grid needed). RivalAI Triggers run on individual in-world grids via Remote Control blocks. **They use different tag names for sub-profiles.**

| Feature | RivalAI Action Tag | MES Event Action Tag | Notes |
| :--- | :--- | :--- | :--- |
| **Encounter Spawner** | `[Spawner:ProfileId]` | `[SpawnData:ProfileId]` | Using `[Spawner:]` in an Event Action causes silent failure (`Spawner.Count == 0`). |
| **Chat Message** | `[Chat:ProfileId]` | `[ChatData:ProfileId]` | Using `[Chat:]` in an Event Action will fail to attach the chat profile. |
| **Counter Changes** | `[IncreaseSandboxCounters:Name]` | `[ChangeCounters:true]` + `[IncreaseCounters:Name]` | MES Event Actions **require** `[ChangeCounters:true]` gating. |
| **Zone Resizing** | `[ChangeZoneByName:true]` | `[ChangeZoneByName:true]` | Uses `[ZoneNames:]`, `[ZoneRadiusChangeTypes:]`, and `[ZoneRadiusChangeAmounts:]`. |

---

## 3. SBC XML Deserialization Quirks

### Strict Single `<SubtypeId>` per `<Id>` Block
Keen's XML deserializer strictly accepts **only one** `<SubtypeId>` per `<Id>` block:
```xml
<!-- INVALID: Second SubtypeId is discarded by deserializer; action fails to load -->
<EntityComponent xsi:type="MyObjectBuilder_InventoryComponentDefinition">
  <Id>
    <TypeId>Inventory</TypeId>
    <SubtypeId>Trigger-OutsideZone</SubtypeId>
    <SubtypeId>Action-OutsideZone</SubtypeId>
  </Id>
  ...
</EntityComponent>
```
```xml
<!-- VALID: Separate definitions with individual Id blocks -->
<EntityComponent xsi:type="MyObjectBuilder_InventoryComponentDefinition">
  <Id>
    <TypeId>Inventory</TypeId>
    <SubtypeId>Trigger-OutsideZone</SubtypeId>
  </Id>
  ...
</EntityComponent>
<EntityComponent xsi:type="MyObjectBuilder_InventoryComponentDefinition">
  <Id>
    <TypeId>Inventory</TypeId>
    <SubtypeId>Action-OutsideZone</SubtypeId>
  </Id>
  ...
</EntityComponent>
```
- **Symptom**: `MES / Error: Could Not Load Action Profile From Trigger: : [SubtypeId]`.
- **Rule**: Every distinct component, action, trigger, or condition must have its own dedicated definition block.

---

## 4. The MES & RivalAI Boolean Master-Gate Architecture

In both MES Event Actions/Conditions and RivalAI Actions/Conditions, sub-configuration tags (lists of variables, targets, coordinates, amounts) **do nothing on their own**. Almost every feature is guarded by a boolean master-switch tag that defaults to `false`.

> [!CAUTION]
> **The Golden Rule**: Specifying child parameters (e.g. `[SetCounters:...]`, `[TrueBooleans:...]`, `[SpawnCoords:...]`) without their parent boolean tag (e.g. `[ChangeCounters:true]`, `[CheckTrueBooleans:true]`, `[SpawnEncounter:true]`) causes **silent execution failure**. MES logs zero errors, but the entire block is skipped.

> [!IMPORTANT]
> **Non-Exhaustive Reference**: The tables below document the primary actions and conditions used across this mod, but this is a **non-exhaustive list**. Virtually every subsystem in MES Event Actions/Conditions and RivalAI Actions/Conditions implements this exact same master-gate scheme. When writing or debugging any tag group, assume a parent boolean gate is required and verify it against the local MES source code.

### A. MES Event Actions (`EventActionExecution.cs`)
| Master Gating Tag (Required) | Dependent Child Tags Enabled | Purpose / Effect |
| :--- | :--- | :--- |
| `[ChangeCounters:true]` | `[SetCounters:]`, `[SetCountersAmount:]`, `[IncreaseCounters:]`, `[IncreaseCountersAmount:]`, `[DecreaseCounters:]`, `[DecreaseCountersAmount:]` | Mutating Sandbox integer counters. |
| `[ChangeBooleans:true]` | `[SetBooleansTrue:]`, `[SetBooleansFalse:]` | Setting Sandbox boolean variables. |
| `[SpawnEncounter:true]` | `[SpawnCoords:]`, `[SpawnFactionTags:]`, `[SpawnData:]`, `[SpawnReplaceKeys:]`, `[SpawnReplaceValues:]` | Spawning encounters via event actions. |
| `[ChangeZoneByName:true]` | `[ZoneNames:]`, `[ZoneRadiusChangeTypes:]`, `[ZoneRadiusChangeAmounts:]` | Dynamically modifying spherical zones by name. |
| `[ChangeZoneAtPosition:true]` | `[ZoneCoords:]`, `[ZoneToggleActiveModes:]` | Activating/deactivating zones at coordinates. |
| `[ToggleEvents:true]` | `[ToggleEventIds:]`, `[ToggleEventIdModes:]`, `[ToggleEventTags:]`, `[ToggleEventTagModes:]` | Enabling or disabling other MES Events. |
| `[ResetCooldownTimeOfEvents:true]` | `[ResetEventCooldownIds:]`, `[ResetEventCooldownTags:]` | Forcing events back to 0 or full cooldown. |
| `[IncreaseRunCountOfEvents:true]` | `[IncreaseRunCountEventIds:]`, `[IncreaseRunCountEventIdAmount:]`, `[IncreaseRunCountEventTags:]` | Manually incrementing event run counters. |
| `[UseChatBroadcast:true]` | `[ChatData:]`, `[UseChatOverrideAuthor:true]`, `[ChatOverrideAuthor:]`, `[UseChatOverrideMessage:true]` | Transmitting HUD / chat notifications. |
| `[ChangeReputationWithPlayers:true]` | `[ReputationPlayerConditionIds:]`, `[ReputationChangeFactions:]`, `[ReputationChangeAmount:]` | Modifying player faction reputation. |
| `[ChangePlayerCredits:true]` | `[PlayerCreditsPlayerConditionIds:]`, `[PlayerCreditsAmount:]` | Adding or deducting player space credits. |
| `[AddGPSToPlayers:true]` | `[GPSNames:]`, `[GPSDescriptions:]`, `[GPSCoords:]`, `[UseGPSObjective:true]` | Creating HUD GPS waypoints for players. |
| `[RemoveGPSFromPlayers:true]` | `[RemoveGPSNames:]` | Deleting HUD GPS waypoints from players. |
| `[TeleportPlayers:true]` | `[TeleportPlayerConditionIds:]`, `[TeleportPlayerCoords:]` | Teleporting players to coordinates. |
| `[AddItemToPlayersInventory:true]` | `[AddItemPlayerConditionIds:]`, `[ItemIds:]` | Adding items directly to player inventories. |
| `[AddTagsToPlayers:true]` | `[AddTags:]`, `[AddTagsPlayerConditionIds:]` | Attaching persistent tracking tags to players. |
| `[RemoveTagsFromPlayers:true]` | `[RemoveTags:]`, `[RemoveTagsPlayerConditionIds:]` | Removing tracking tags from players. |

### B. MES Event Conditions (`EventConditions.cs`)
| Master Gating Tag (Required) | Dependent Child Tags Evaluated | Purpose / Effect |
| :--- | :--- | :--- |
| `[CheckCustomCounters:true]` | `[CustomCounters:]`, `[CustomCountersTargets:]`, `[CounterCompareTypes:]` | Evaluating sandbox counter variables. |
| `[CheckTrueBooleans:true]` | `[TrueBooleans:]`, `[AllowAnyTrueBoolean:true/false]` | Requiring sandbox booleans to be true. |
| `[CheckFalseBooleans:true]` | `[FalseBooleans:]`, `[AllowAnyFalseBoolean:true/false]` | Requiring sandbox booleans to be false. |
| `[CheckPlayerNear:true]` | `[PlayerNearCoords:]`, `[PlayerNearDistanceFromCoords:]`, `[PlayerNearMinDistanceFromCoords:]` | Distance checks from specified coords. |
| `[CheckPlayerCondition:true]` | `[PlayerConditionIds:]` | Player-specific state & inventory checks. |
| `[CheckThreatScore:true]` | `[ThreatScoreAmount:]`, `[ThreatScoreDistance:]`, `[ThreatScoreCoords:]`, `[ThreatScoreType:]` | Player combat grid threat checks. |
| `[CheckMainEventDaysPassed:true]`| `[DaysPassed:]` | World age / session lifespan progression. |

### C. RivalAI Actions (`ActionSystem.cs`)
| Master Gating Tag (Required) | Dependent Child Tags Enabled | Purpose / Effect |
| :--- | :--- | :--- |
| `[ChangeCounters:true]` | `[SetCounters:]`, `[IncreaseCounters:]`, `[DecreaseCounters:]`, `[ResetCounters:]` | Mutating sandbox counters from grid blocks. |
| `[ChangeBooleans:true]` | `[SetBooleansTrue:]`, `[SetBooleansFalse:]` | Mutating sandbox booleans from grid blocks. |
| `[SpawnEncounter:true]` | `[Spawner:ProfileId]` | Spawning reinforcements or escorts. |
| `[ChangeZoneByName:true]` | `[ZoneNames:]`, `[ZoneRadiusChangeTypes:]`, `[ZoneRadiusChangeAmounts:]` | Modifying dynamic zones from grid triggers. |
| `[ToggleEvents:true]` | `[ToggleEventIds:]`, `[ToggleEventIdModes:]` | Activating/deactivating MES Events from grid. |
| `[CreateSafeZone:true]` | `[SafeZonePositionGridCenter:true]`, `[SafeZoneRadius:]` | Deploying safezones around NPC grid. |
| `[AddGPSToPlayers:true]` | `[GPSNames:]`, `[GPSDescriptions:]`, `[GPSCoords:]` | Pushing GPS coordinates to players. |
| `[BroadcastCommandProfiles:true]`| `[CommandProfileIds:]` | Transmitting antenna command codes to nearby NPCs. |

### D. RivalAI Conditions (`ConditionReferenceProfile.cs`)
| Master Gating Tag (Required) | Dependent Child Tags Evaluated | Purpose / Effect |
| :--- | :--- | :--- |
| `[CheckCustomCounters:true]` | `[CustomCounters:]`, `[CustomCountersTargets:]`, `[CounterCompareTypes:]` | Evaluating sandbox counter variables. |
| `[CheckTrueBooleans:true]` | `[TrueBooleans:]`, `[AllowAnyTrueBoolean:true/false]` | Evaluating sandbox true booleans. |
| `[CheckFalseBooleans:true]` | `[FalseBooleans:]`, `[AllowAnyFalseBoolean:true/false]` | Evaluating sandbox false booleans. |
| `[CheckThreatScore:true]` | `[ThreatScoreAmount:]`, `[ThreatScoreDistance:]` | Evaluating threat of nearby player grids. |
| `[CheckPlayerNear:true]` | `[PlayerNearDistance:]` | Checking player distance from remote control. |
| `[CheckPlayerReputation:true]` | `[CheckReputationFaction:]`, `[CheckReputationMin:]`, `[CheckReputationMax:]` | Checking player faction reputation. |
| `[CheckHealthPercentage:true]` | `[HealthPercentageTrigger:]`, `[HealthPercentageCompareType:]` | Triggering on grid damage / block loss. |
| `[CheckWeaponsPercentage:true]`| `[WeaponsPercentageTrigger:]`, `[WeaponsPercentageCompareType:]` | Triggering on loss of defensive armament. |

### E. List Count Alignment Rules
All paired lists in Event Actions must have strictly equal element counts:
- `SetCounters` count must equal `SetCountersAmount` count.
- `IncreaseCounters` count must equal `IncreaseCountersAmount` count.
- `DecreaseCounters` count must equal `DecreaseCountersAmount` count.
- For `[SpawnEncounter:true]`: `SpawnData` count must equal `SpawnCoords` count and `SpawnFactionTags` count.

---

## 5. Event Spawner Configurations

### Spawner Profile Tag Standards
When spawning via `[MES Event Action]`:
```xml
<EntityComponent xsi:type="MyObjectBuilder_InventoryComponentDefinition">
  <Id>
    <TypeId>Inventory</TypeId>
    <SubtypeId>GVK-EventAction-MyEncounter</SubtypeId>
  </Id>
  <Description>
  [MES Event Action]
  [SpawnEncounter:true]
  [SpawnCoords:{X:100 Y:200 Z:300}]
  [SpawnFactionTags:COALITION]
  [SpawnData:GVK-EventSpawner-MyEncounter]
  </Description>
</EntityComponent>

<EntityComponent xsi:type="MyObjectBuilder_InventoryComponentDefinition">
  <Id>
    <TypeId>Inventory</TypeId>
    <SubtypeId>GVK-EventSpawner-MyEncounter</SubtypeId>
  </Id>
  <Description>
  [RivalAI Spawn]
  [UseSpawn:true]
  [SpawningType:CustomSpawn]
  [StartsReady:true]
  [ProcessAsAdminSpawn:true]
  [SpawnGroups:MySpawnGroup]
  [MinDistance:200]
  [MaxDistance:500]
  [MinAltitude:40]
  [MaxAltitude:50]
  [InheritNpcAltitude:false]
  [IgnoreSafetyChecks:true]
  </Description>
</EntityComponent>
```
- **`[ProcessAsAdminSpawn:true]`**: Bypasses global max NPC caps, area NPC count limits, and area spawn timeouts in `SpawnRequest.cs`. Crucial for scripted convoy/cargo dispatches.
- **`[RivalAiAnySpawn:true]`**: Must be set on the target `[MES Spawn Conditions]` profile to permit programmatic spawning.

---

## 6. Event Timing & Cooldowns

- **Units**: All cooldown values (`MinCooldownMs`, `MaxCooldownMs`) are in **milliseconds** (`1000` = 1s, `60000` = 1m, `3600000` = 1h).
- **`[StartsReady:true]`**:
  - `StartsReady: false` forces the event to wait the full cooldown period after initialization before evaluating conditions.
  - `StartsReady: true` evaluates conditions immediately on tick 1. Use for reactive events and testing.
- **Proximity Gating**: Use `[CheckPlayerNear:true]` with `[PlayerNearCoords:{...}]` and `[PlayerNearDistanceFromCoords:10000]` to avoid running heavy spawn logic when players are outside activation distance.

---

## 7. Sandbox Variables & Cross-System Persistence

- `SetCounters` in MES Events and `IncreaseSandboxCounters` / `DecreaseSandboxCounters` in RivalAI grid actions write directly to the Space Engineers Sandbox session storage (`MyAPIGateway.Utilities.SetVariable<int>`).
- MES Event Conditions evaluate these variables via:
  ```xml
  [MES Event Condition]
  [CheckCustomCounters:true]
  [CustomCounters:KHAANEPH_Points]
  [CustomCountersTargets:200]
  [CounterCompareTypes:GreaterOrEqual]
  ```
- Valid `CounterCompareTypes`: `GreaterOrEqual`, `Greater`, `Equal`, `NotEqual`, `Less`, `LessOrEqual`.

---

## 8. MES Tag Parsing Quirks & The Zero-Stripping Bug

### Zero-Stripping in Integer Lists (`TagIntListCheck`)
In the MES source (`TagParse.cs`), the standard integer list parser strips all `0` values unless explicitly called with `preserveZero: true`:
```csharp
if (!preserveZero)
    result.RemoveAll(item => item == 0);
```

- **MES Event Conditions (`EventConditions.cs`)**:
  `CustomCountersTargets` calls `TagIntListCheck(s, ref CustomCountersTargets)` without preserving zeros.
  - **Symptom**: Using `[CustomCountersTargets:0]` strips the `0`, resulting in an empty targets list. Condition evaluation fails with `Counter Names and Targets List Counts Don't Match` and marks the condition unsatisfied.
  - **Workaround for Zero Comparison**:
    - To test `< 0` (e.g., floor clamping): Use `[CustomCountersTargets:-1]` with `[CounterCompareTypes:LessOrEqual]`.
    - To test `>= 0` (e.g., positive progress gates): Use `[CustomCountersTargets:-1]` with `[CounterCompareTypes:Greater]`.
- **Affected Tags across MES (Missing `preserveZero: true`)**:
  - `CustomCountersTargets` in `EventConditions.cs`
  - `CustomSandboxCountersTargets` in `ConditionReferenceProfile.cs`
  - `CustomSandboxCountersTargets` in `SpawnConditionsProfile.cs`
  - `CustomZoneCounterValue` in `ZoneConditionsProfile.cs`
  - `IncreaseCountersAmount` / `DecreaseCountersAmount` in `EventActionReference.cs`
- **Tags that Safely Preserve Zero**:
  - `SetCountersAmount` in `EventActionReference.cs` (`preserveZero: true`)
  - `CustomCountersTargets` in `ConditionReferenceProfile.cs` (RivalAI grid conditions pass `preserveZero: true`)

