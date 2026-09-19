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

### A. Strict Single `<SubtypeId>` per `<Id>` Block (Child Tag Style)
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

### B. Strict Single `<Id>` per `<Prefab>` / Definition Block (Attribute Tag Style)
In prefab and block definitions using self-closing attribute tags (`<Id Type="..." Subtype="..." />`), having multiple `<Id>` elements inside a `<Prefab>` causes Keen to only read the first one and discard subsequent ones:
```xml
<!-- INVALID: Deserializer reads the first Id, registering the prefab as Nav Tower instead of Base Site Tower -->
<Prefab xsi:type="MyObjectBuilder_PrefabDefinition">
  <Id Type="MyObjectBuilder_PrefabDefinition" Subtype="NST GAALSIEN Nav Tower" />
  <Id Type="MyObjectBuilder_PrefabDefinition" Subtype="NST Base Site Tower" />
  <CubeGrids>...</CubeGrids>
</Prefab>
```
- **Symptom**: `Spawn group initialization: Could not get prefab [SubtypeId]`.
- **Rule**: When cloning prefabs, always replace the existing `<Id>` tag cleanly. Never leave duplicate `<Id>` elements.

### C. Ban XML Comments Inside `<Description>` Tags
Keen deserializes `<Description>` via `ReadElementString()`, which strictly expects plain text:
```xml
<!-- CRITICAL FAILURE: Throws System.Xml.XmlException: Unexpected node type Comment -->
<Description>
  [RivalAI Behavior]
  <!-- Zone Presence Tracking -->
  [Triggers:MyTrigger]
</Description>
```
```xml
<!-- VALID: Use RivalAI comment tag syntax instead -->
<Description>
  [RivalAI Behavior]
  [//Zone Presence Tracking]
  [Triggers:MyTrigger]
</Description>
```
- **Symptom**: `System.Xml.XmlException: Unexpected node type Comment. ReadElementString method can only be called on elements with simple or empty content. Failed to deserialize file... MOD_CRITICAL_ERROR / MOD SKIPPED`.
- **Rule**: Never use `<!-- ... -->` inside `<Description>` or any text element deserialized by `ReadElementString()`. Use `[//Comment]` syntax.

### D. Mandatory Pre-Build Automated XML Audit
Before running `dotnet build` or shipping SBC changes, execute this dual-check script in PowerShell:
```powershell
Get-ChildItem -Path Content\Data -Filter *.sbc -Recurse | ForEach-Object {
    [xml]$doc = Get-Content -LiteralPath $_.FullName -Raw
    $badChildIds = $doc.SelectNodes("//Id[count(SubtypeId) > 1]")
    if ($badChildIds.Count -gt 0) { Write-Host "DUPLICATE SubtypeId IN: $($_.FullName)" }
    $badAttrIds = $doc.SelectNodes("//*[count(Id) > 1]")
    if ($badAttrIds.Count -gt 0) { Write-Host "DUPLICATE Id TAG IN: $($_.FullName)" }
}
```

---

## 4. The MES & RivalAI Boolean Master-Gate Architecture

In **MES Event** Actions/Conditions, sub-configuration tags (lists of variables, targets, coordinates, amounts) **do nothing on their own**. Almost every feature is guarded by a boolean master-switch tag that defaults to `false`.

> [!CAUTION]
> **The Golden Rule (MES Events only)**: Specifying child parameters (e.g. `[SetCounters:...]`, `[TrueBooleans:...]`, `[SpawnCoords:...]`) without their parent boolean tag (e.g. `[ChangeCounters:true]`, `[CheckTrueBooleans:true]`, `[SpawnEncounter:true]`) causes **silent execution failure**. MES logs zero errors, but the entire block is skipped.
>
> **RivalAI has NO master gates.** There is no `ChangeBooleans`/`ChangeCounters` field anywhere in `Behavior\Subsystems\Trigger\` - RivalAI action tags are self-gating (an empty list is a no-op), so `[SetBooleansTrue:X]` alone is valid. Do not add MES-style gates to `[MES AI Action]` profiles.

> [!CAUTION]
> **Grid vs Sandbox variables are different namespaces.** RivalAI `[SetBooleansTrue/False]`, `[SetCounters]`, `[IncreaseCounters]`, `[DecreaseCounters]`, `[ResetCounters]` write to the **grid-scoped** behavior settings (`StoredSettings.StoredCustomBooleans`/`StoredCustomCounters`) and are read back only by grid conditions. Sandbox (session-wide) storage uses the separate `[SetSandboxBooleansTrue/False]`, `[IncreaseSandboxCounters]`, `[DecreaseSandboxCounters]`, `[ResetSandboxCounters]`, `[SetSandboxCounters(+Values)]` tags, which is the same storage MES Event actions/conditions use. Mixing them up produces conditions that never become true.

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

**No master gates** - the tag itself is the switch.

| Tag | Reads / writes | Purpose / Effect |
| :--- | :--- | :--- |
| `[SetBooleansTrue:]`, `[SetBooleansFalse:]` | Grid settings (`_settings.SetCustomBool`) | Grid-scoped flags, readable only by grid conditions (`[CheckTrueBooleans]/[CheckFalseBooleans]`). |
| `[SetCounters:]` + `[SetCountersValues:]`, `[IncreaseCounters:]` + `[IncreaseCountersAmount:]`, `[DecreaseCounters:]` + `[DecreaseCountersAmount:]`, `[ResetCounters:]` | Grid settings | Grid-scoped counters. |
| `[SetSandboxBooleansTrue:]`, `[SetSandboxBooleansFalse:]`, `[IncreaseSandboxCounters:]` + `[IncreaseSandboxCountersAmount:]`, `[DecreaseSandboxCounters:]` + `[DecreaseSandboxCountersAmount:]`, `[ResetSandboxCounters:]`, `[SetSandboxCounters:]` + `[SetSandboxCountersValues:]` | Session storage | Sandbox variants - the same namespace MES Events read. |
| `[SpawnEncounter:true]` | `[Spawner:ProfileId]` | Spawning reinforcements or escorts. |
| `[ChangeZoneByName:true]` | `[ZoneNames:]`, `[ZoneRadiusChangeTypes:]`, `[ZoneRadiusChangeAmounts:]` | Modifying dynamic zones from grid triggers. |
| `[ToggleEvents:true]` | `[ToggleEventIds:]`, `[ToggleEventIdModes:]` | Activating/deactivating MES Events from grid. |
| `[CreateSafeZone:true]` | `[SafeZonePositionGridCenter:true]`, `[SafeZoneRadius:]` | Deploying safezones around NPC grid. |
| `[AddGPSToPlayers:true]` | `[GPSNames:]`, `[GPSDescriptions:]`, `[GPSCoords:]` | Pushing GPS coordinates to players. |
| `[BroadcastCommandProfiles:true]`| `[CommandProfileIds:]` | Transmitting antenna command codes to nearby NPCs. |

### D. RivalAI Conditions (`ConditionReferenceProfile.cs`)

| Master Gating Tag (Required) | Dependent Child Tags Evaluated | Purpose / Effect |
| :--- | :--- | :--- |
| `[CheckCustomCounters:true]` | `[CustomCounters:]`, `[CustomCountersTargets:]`, `[CounterCompareTypes:]` | Evaluating **grid-scoped** counters. |
| `[CheckCustomSandboxCounters:true]` | `[CustomSandboxCounters:]`, `[CustomSandboxCountersTargets:]`, `[SandboxCounterCompareTypes:]` | Evaluating **sandbox** counters. |
| `[CheckTrueBooleans:true]` | `[TrueBooleans:]`, `[AllowAnyTrueBoolean:true/false]` | Evaluating grid-scoped true booleans (`AllowAnyTrueBoolean` = OR over the list). |
| `[CheckFalseBooleans:true]` | `[FalseBooleans:]`, `[AllowAnyFalseBoolean:true/false]` | Evaluating grid-scoped false booleans (list = AND). |
| `[CheckThreatScore:true]` | `[ThreatScoreAmount:]`, `[ThreatScoreDistance:]` | Evaluating threat of nearby player grids. |
| `[CheckPlayerNear:true]` | `[PlayerNearDistance:]` | Checking player distance from remote control. |
| `[CheckPlayerReputation:true]` | `[CheckReputationwithFaction:]`, `[MinPlayerReputation:]`, `[MaxPlayerReputation:]` | Checking player faction reputation (equal list counts required). |
| `[CheckHealthPercentage:true]` | `[HealthPercentageTrigger:]`, `[HealthPercentageCompareType:]` | Triggering on grid damage / block loss. |
| `[CheckWeaponsPercentage:true]`| `[WeaponsPercentageTrigger:]`, `[WeaponsPercentageCompareType:]` | Triggering on loss of defensive armament. |

### E. Trigger Gotchas (`TriggerProfile.cs`, `TriggerSystem.cs`)
- `[MaxActions:N]` is **one-way**: once `TriggerCount >= N` the trigger is force-disabled on every evaluation and there is **no reset tag** in RivalAI. Any re-enableable trigger (3h cooldowns, repeatable terminals) must use `[MaxActions:-1]` and disable itself from its own action.
- `[UseTrigger:false]` skips the trigger entirely, including `[Type:Timer]`. Re-enabling via `[EnableTriggers:true]` + `[ResetCooldownTimeOfTriggers:true]` restarts the full cooldown from that moment.
- `[Type:ButtonPress]` is event-driven (fires only on a real press, no polling); `[ButtonPanelIndex:-1]` = any button on the named panel. A 1s `[MinCooldownMs:1000]`/`[MaxCooldownMs:1001]` absorbs double-press/duplicate events.
- Grid filters are loose: `ProcessButtonTriggers` skips panels on *other* grids only when they are in the same logical group, so a player-built panel with a matching name can fire another grid's triggers (known MES issue).

### F. MES Event Execution Model
- `[UseAnyPassingCondition:true]` + `[ActionExecution:Condition]` runs **only** `Actions[RequiredConditionIndex]`, where the index is the *last* satisfied condition. `ConditionIds` and `ActionIds` must therefore be index-aligned and equal in length, and order-sensitive rules (e.g. clamps that must win against a tier change) rely on list position.
- `[UniqueEvent:false]` is required for any event that must fire more than once (default is `true`).
- Event chat profiles support only the `{PlayerName}` token in this path; `IdsReplacer` tokens (`{Faction}`, `{EncounterDisplayName}`, etc.) are **not** applied to MES Event chat messages.
- SpawnCondition `[UseRemoteControlCodeRestrictions:true]` + `[RemoteControlCode:]` + `[RemoteControlCodeMinDistance:]` blocks spawning within that distance of any grid registered with the code (`CoreBehavior` registers the RC when the NPC behavior starts; destroyed grids stop blocking). Set the min distance **greater than 2x the spawner's MaxDistance**, otherwise a redeploy can land outside the gate.


### G. List Count Alignment Rules
All paired lists in Event Actions must have strictly equal element counts:
- `SetCounters` count must equal `SetCountersAmount` count.
- `IncreaseCounters` count must equal `IncreaseCountersAmount` count.
- `DecreaseCounters` count must equal `DecreaseCountersAmount` count.
- For `[SpawnEncounter:true]`: `SpawnData` count must equal `SpawnCoords` count and `SpawnFactionTags` count.
- For `[ActionExecution:Condition]`: `ConditionIds` count must equal `ActionIds` count, index for index (see F).
- In `[CheckCustomCounters:true]`: `CustomCounters` count must equal `CustomCountersTargets` count. `CounterCompareTypes` is optional per entry but silently defaults to `GreaterOrEqual`, so state it explicitly for every entry.

### H. Profile Header Tags
Profile type is detected from a header line inside `<Description>`; `ProfileManager` accepts both the legacy `[RivalAI ...]` and the current `[MES AI ...]` aliases. New files use `[MES AI Behavior|Trigger|Action|Condition|TriggerGroup|Chat|Spawn]` plus the MES-side headers `[MES Event]`, `[MES Event Condition]`, `[MES Event Action]`, `[MES Player Condition]`, `[MES Zone]`, `[MES Zone Conditions]`, `[MES Spawn Conditions]`, `[MES Manipulation]`. RivalAI and MES were separate mods before they merged, so the legacy names carry no extra meaning - they are compatibility aliases only.

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

### A. One Namespace, Single Writer

- All sandbox counters/booleans (MES Events, RivalAI grid actions, plugins, HUD) share ONE session-global namespace. Two events writing the same bare name fight over the same storage and can loop announcements forever - this happened live when the zone-size ladder used bare `Tier10..Tier55` booleans in both faction events (each faction's transitions cleared the other's flags, producing an endless "decreased to 10km" / "increased to 55km" ping-pong).
- Rule 1 - Prefix every shared-state variable with its owner: `KHAANEPH_Tier`, `SOBAN_Points`, never bare `Tier`.
- Rule 2 - Single writer: exactly one event/action owns each variable's writes. In a tier ladder, clamps must not write the tier marker - the transition action owns it (so a clamp that resets points gets its zone + chat on the next cycle).
- Rule 3 - Prefer stateless integer tier markers over boolean matrices: conditions test `points in band AND Tier != band AND (Tier < band = up-entry | Tier > band = down-entry)`. Same-tier repeats are structurally impossible, and the top band must be open-ended (the ceiling clamp parks points at exactly the max - a bounded top band leaves that value dead). See `GVK-Alliance-Events-ZoneSize.sbc` for the reference implementation.
- Rule 4 - A condition that references a counter never written to sandbox storage ALWAYS fails: `EventConditions.cs` keeps the `GetVariable` success flag in the verdict, so the 0 default does not help. Bootstrap any state a condition reads via a one-shot event (`UniqueEvent:true` - `RunCount` is `[ProtoMember]`-serialized, so it fires exactly once per world) whose conditions only reference counters that already exist, and whose action `SetCounters` the new ones. Without this the ladder deadlocks: nothing writes the marker, so every condition reading it fails forever.

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

