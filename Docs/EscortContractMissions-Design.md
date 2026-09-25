# Escort Contract Missions — Design Document

Feature: Replace ambient/proximity spawning of Route A–E escort cargo convoys
with player-initiated contract missions accepted at a Coalition Base contract block.

Parent TODO: #480 (On-Demand Escort Spawns) — https://github.com/GV-Server-Mods/GVK-Settings/issues/480
Related: #469 (mission cruiser despawn on restart), P0 cross-grid button bypass.

---

## 0. CURRENT ARCHITECTURE (2026-09-21 pivot — C# script retired)

The first implementation (the C# session component described in §4–§7 below) **failed in-game**
and has been deleted from the repo. Three root causes, each proven from MES/SE source + server log:

1. **MES API delegate timing.** `MesApi` was constructed lazily at contract-accept time. MES
   broadcasts its API delegate dictionary **exactly once** (`MES_SessionCore.BeforeStart()` →
   `LocalApi.SendApiToMods()` → `SendModMessage(1521905890, dict)`), so a handler registered
   afterwards never receives it: `_customSpawnRequest` stayed `null` → `?? false` → instant
   "convoy spawn FAILED" with *no* MES-side log line. MES's own wrapper states the contract:
   *"Create this object in your SessionComponent LoadData() Method"*.
2. **`[RemoteControlCode:X]` is not block data.** It is a behavior-SBC tag consumed into MES's
   in-memory `NpcManager.RemoteControlCodes` (`CoreBehavior.cs:559`, `SpawnConditions.cs:1614`);
   MES only writes RC `CustomData` on a behavior *switch* (`CoreBehavior.cs:500`). No prefab in
   this mod carries it in block CustomData, so the script's grid re-acquisition scan could never
   match — the convoy would have been declared lost ~60 s after any successful spawn.
3. **The chat lied.** The "convoy is rolling out — form up!" message was a script
   `ShowMessage` call emitted regardless of spawn success. The NPC-side chat chain that the
   ambient version used (`Chat-EscortOnSpawnA/B/E`, fired by each convoy's own OnSpawn trigger)
   is the correct mechanism and cannot fire without a grid.

MES's **Missions** subsystem is the right tool for this feature (discovered during the
post-mortem, verified in source). The whole feature is now SBC-only, **zero C#**:

| Profile | Marker | Role |
|---|---|---|
| `GVK-EscortMission-RouteA/B/E` | `[MES Mission]` | Title/description/reward/collateral/duration/reputation, `Exclusive:true`, `InstanceEventGroupId`, `OverrideFaction:COALITION` |
| `GVK-EscortContracts-Board` | `[MES Contract Block]` | `MissionIds` list published onto a contract block |
| `GVK-EscortContracts-BoardBehavior` (+ `Trigger`/`Condition`/`Action`) | `[RivalAI Behavior/Trigger/Condition/Action]` | Runs on the base grid; publishes the board and refreshes it every 10 min, gated on `[NoActiveContracts:true]` so it can never disturb an in-progress mission |
| `GVK-EscortMissions-Template-Spawn/Arrived/Lost-X` + `GVK-EscortMissions-Group-X` | `[MES Event Template]` / `[MES Event TemplateGroup]` | On accept MES instantiates these with the contract id as `InstanceId`: spawn (runs the existing `GVK-Convoy-EventAction-CoalitionX`), plus arrived-wait and lost-wait |
| `GVK-EscortMissions-EventCondition-Arrived/Lost-X`, `GVK-EscortMissions-EventAction-Arrived/Lost-X` | `[MES Event Condition]` / `[MES Event Action]` | `[TryContractSuccess:true]` / `[TryContractFail:true]` — MES passes the seeded contract id to `TryFinishCustomContract`/`TryFailCustomContract` |
| `GVK_EscortArrived_X`, `GVK_EscortLost_X` (sandbox booleans) | convoy behavior actions | Outcome signals: set by `Action-EscortSuccessX` / the convoy's BeaconDisabled, Compromised, Despawn and DespawnMES triggers; cleared by the board refresh action |

Flow: board refresh → MES adds the missions as real `MyContractCustom` contracts (type
`MESContract`, shipped by MES at `Data/Contract/ContractType.sbc`) → player accepts →
MES spawns the convoy via the mission's instance event group → transport arrives / is lost →
MES event finishes or fails the contract (escrow payout, reputation, `ActivateBooleanNameOnSucces`)
→ next board refresh re-offers the routes.

Consequences: no `MesApi` dependency, no grid scanning, no RC codes, no position polling, no
script-owned chat, and restart survival is automatic (Keen owns contract state, MES owns mission
state, sandbox booleans persist).

---

## 1. Goals

1. Escort missions start **only when a player actively requests them** (contract acceptance).
2. **Primary payout stays the loot spawns** (shared, as today) — the contract adds a small
   holder-only token credit bonus. Loot payout may later be script-injected on success
   (see §8) for success-gated / difficulty-scaled payouts.
3. Missions **survive server restarts/crashes** mid-escort without ending the player's mission.
4. Config-driven route table so KHAANEPH/SOBAN factions can be added later with **zero script changes**.
5. No reputation changes for COALITION (always friendly); rep fields reserved for future factions.

## 2. Non-Goals (Season 11)

- Gaalsien Convoy C/D (hostile carrier/small convoys) — remain ambient MES Events.
- Formation flying, refuel gameplay changes (tracked separately).

## 3. Foundation (verified)

| Dependency | Status |
|---|---|
| Custom Contracts API (`MyAPIGateway.ContractSystem`, `MyContractCustom`, lifecycle events) | ✅ Official server-side API |
| MES API `CustomSpawnRequest` wrapper | ✅ Already in repo (`WeeklyScheduler_MesApi.cs` pattern) |
| MES trigger counters stuck after save/reload | ✅ Fixed upstream: MES `7e6566e` (tinsoldier) |
| `SetSandboxCounters` wrong-array bug | ✅ Fixed upstream: MES `919f024` (Blaylock1988) |
| Contract block visible on **MES prefab-spawned** NPC base | ✅ **VERIFIED IN-GAME (spike, 2026-09-21)**: `SUCCESS: contract added` + test contract listed on the Base's "NPC Contracts" block. Decompiled source explains why: `MyContractBlock.GetAdministrableContracts()` lists ModAPI `AddContract` contracts whenever the grid is **NOT a registered economy faction station** (`GetAvailableContractsForBlock_OB`, indexed by `endBlockId`). Keen bug #26976 only affects Economy-system stations. |
| `AddContract` validation gates (decompiled `MySessionComponentContractSystem.cs`) | ✅ Mapped: (1) `StartBlockId` **must** be a real contract block entity id (passing 0 → instant `Success=false`); (2) funds check `GetBalance(startBlock.OwnerId) < MoneyReward` → `Fail_NotEnoughFunds`; (3) reward **escrowed from block owner at add time** (log: `Balance change ... to account owner 144115188075855919`), refunded on delete (our contracts are `IsPlayerMade`, so `DeleteCustomContract` works). COALITION owner balance ≈ 100B → funds gate is a non-issue for token rewards. |
| Contract block placed in `NTS [COAL] Base.sbc` | ✅ Added (`MyObjectBuilder_ContractBlock`, line ~38677) |
| MES despawn mid-contract while players away | ✅ **Verified via MES source** (`DespawnSystem.cs`): no sandbox-variable gate exists; solution is `[UsePlayerDistanceTimer:false]` on convoy behaviors + script-owned lifecycle (§7). |

**Deployment gate**: server MES build must include `7e6566e` and `919f024`.

## 4. Architecture

```
Content/Data/ContractTypes/GVK-ContractTypes.sbc     → ContractTypeDefinition(s)
Content/Data/Prefabs/NTS [COAL] Base.sbc             → ContractBlock (added)
ModScripts/EscortContractRouteTable.cs               → route config (data only)
ModScripts/EscortContractSession.cs                  → lifecycle session component
Content/Data/Encounters/PlanetaryCargoShip/...       → existing spawn groups reused as-is
```

### 4.1 Route Table (config-driven)

Each entry: one route. Adding KHAANEPH/SOBAN later = add entries + contract blocks on their bases.

```csharp
public class EscortRoute
{
    public string  RouteId;          // "A" | "B" | "E" | future "S1","K1"...
    public string  FactionTag;       // "COALITION"
    public string  SpawnGroup;       // existing GVK spawn group
    public Vector3D RouteStart;      // spawn origin (existing event coords)
    public Vector3D RouteEnd;        // destination station coords (fill from station/prefab)
    public double  CompleteRadius;   // e.g. 1500 m from RouteEnd
    public int     MoneyReward;      // token holder-only bonus (loot is the primary payout)
    public int     Collateral;       // 0 for now
    public int     DurationMinutes;  // generous: 360 (in-game time; paused while server offline)
    public int     CooldownMinutes;  // per-route re-arm after finish
    public string  RemoteControlCode;// convoy grid re-acquisition after reload
    public string  DisplayName;      // "Escort Convoy – Route A (Sevastapol)"
    public string  Description;      // flavor + instructions
    public bool    Enabled;
}
```

### 4.2 Initial COALITION routes (from `GVK-Convoy-Events.sbc` / waypoint files)

| Route | Type | Start (spawn origin) | Destination | Notes |
|---|---|---|---|---|
| A | Land | 60487.12, 32965.06, 44090.29 | Sevastapol | ~87 waypoints; end coords = final waypoint vicinity (~2832, 32610, 32318 → refine to station GPS) |
| B | Land | 61272.50, 23606.81, 32536.20 | Mastodon | |
| E | Air | 61208.22, 33998.99, 42038.30 | Skyport → Sevastapol | aerial, refuel system active (`AerialEscortRefuelSession`) |

Gaalsien C/D **excluded** (hostile ambient convoys, not player missions).

### 4.3 Contract offering

- Script maintains ≤1 active contract **per route** and a per-route cooldown.
- When a route is available, script `AddContract`s it to the contract block. When accepted
  (`CustomActivateContract`), the block is empty again for other routes.
- All routes share the contract type `GVK-EscortConvoy`; the route is identified by a
  machine-readable tag embedded in the contract name: `[GVK-Route:A]` (used for re-binding).

## 5. Lifecycle & State Machine

```
AVAILABLE ──accept──▶ SPAWNING_PENDING ──spawn ok──▶ ACTIVE ──end coords──▶ SUCCESS
    ▲                      │                            │  ──grid destroyed──▶ FAIL
    │                      └──spawn failed──▶ FAIL      └──duration expired──▶ FAIL (grace)
    └──── cooldown expires / re-arm ────┘
```

- `CustomActivateContract` → set sandbox flag `GVK_ConvoyActive_<route>=1`, call
  `MesApi.CustomSpawnRequest([spawnGroup], matrix at RouteStart, ...)`, persist state, chat
  confirmation + GPS marker ("Convoy dispatched from Crossroads, form up!").
- Monitor tick (10 s): convoy grid exists? distance(RouteEnd) < CompleteRadius → finish(success).
  Grid gone / null → fail. Duration enforced by contract itself.
- Success → token credit payout is vanilla (contract holder only). **Primary loot payout
  remains the existing MES route-complete loot spawns** (shared, as today).
  Cleanup: clear sandbox flag, re-arm cooldown, world-storage state update.

## 6. Reload / Crash Survival (the critical requirement)

**What persists natively:** contracts (vanilla saves them; numeric IDs regenerate on load),
the convoy grid (world save), sandbox variables (with 7e6566e + 919f024 in build).

**World-storage state file** (`escort_contracts.xml`, `ReadFileInWorldStorage` pattern):
per active route: `RouteId, ContractLongId, Phase (Pending/Active), SpawnedGridEntityId, FireTime`.

On session load (script `LoadData`/first tick):
1. Load state file.
2. For each active route: re-resolve contract by type + `[GVK-Route:<id>]` tag in the name
   (IDs regenerate on load); re-acquire convoy grid by `RemoteControlCode`.
3. Resolution matrix:

   | Contract | Convoy grid | Action |
   |---|---|---|
   | ✓ | ✓ | **Resume ACTIVE** (no player-visible disruption) |
   | ✓ | ✗ | FAIL contract + notification ("Convoy lost") |
   | ✗ | ✓ | Orphaned convoy → despawn via MES trigger; clear flag |
   | ✓(pending) | ✗ | Crash between accept & spawn → **re-run spawn** at RouteStart |
   | ✗ | ✗ | Clear flag, re-arm route |

4. Players mid-escort at reload see the contract still in their log and the convoy still driving
   — seamless. **The old "mission dies on restart" behavior is unacceptable by design.**

## 7. MES Despawn Gate

**Verified against MES source** (`Behavior/Subsystems/DespawnSystem.cs`, installed build):
despawn is driven by three behavior tags parsed from the RemoteControl's CustomData:
- `[UsePlayerDistanceTimer:bool]` — **default `true`**, timer 150 s at >25 km from any player → `DoDespawn` → grid (+ linked grids) removed.
- `[UseNoTargetTimer:bool]` — default `false`.
- `[UseRetreatTimer:bool]` — default `false`.

There is **no sandbox-variable despawn gate** in MES — the variable-gate idea from the
original design is not implementable as first sketched. Instead:

1. The contract-convoy behaviors set **`[UsePlayerDistanceTimer:false]`** (repo precedent:
   `GVK-Alliance-ResearchLab-Behavior.sbc` already does this) so MES never distance-despawns them.
2. The script **owns the full lifecycle**: spawn (MES `CustomSpawnRequest`), monitor, and cleanup.
   Orphaned convoys (contract gone) are removed by the script closing the grid directly
   (full ModAPI session component, same privilege as `AerialEscortRefuelSession`).
3. `_behavior.Trigger.ProcessDespawnTriggers()` still runs when a grid despawns/destroys —
   route-failure flags can be set from the convoy's existing `DefeatedAndAttacked`-style
   trigger chain if we want MES-side signaling.
4. Crash safety per §6 is unaffected: with distance-despawn disabled, the convoy cannot
   be silently removed while nobody is online, which was the main restart-time hazard.

No additional MES wiki tag verification is required for this mechanism.

## 8. Rewards

- **Primary payout: existing MES loot spawns** on route completion (unchanged, shared).
- `moneyReward` = small holder-only token bonus. Starting point: A 8k, B 6k, E 10k.
- `collateral = 0`, `reputationReward = 0`, `failReputationPrice = 0` (COALITION always friendly).
- **Optional enhancement (later):** script-injected loot on SUCCESS — inject item stacks into the
  convoy's remaining cargo containers (or spawn stacks at the convoy position) when the contract
  finishes successfully. Ties payout to mission completion rather than convoy destruction and can
  scale per route. ~20 lines per loot table using `IMyInventory.AddItems`.
- Future KHAANEPH/SOBAN: rep fields populated in route table only — no code changes.

## 9. Spike Test (pre-implementation)

Script: `ModScripts/EscortContractSpike.cs` + `Content/Data/ContractTypes/GVK-ContractTypes.sbc`.

1. ~~Add a contract block to Coalition Base prefab~~ ✅ Done (`NTS [COAL] Base.sbc`, "NPC Contracts").
2. Deploy mod, load world; spike auto-runs ~10 s after session start, server-side:
   - Logs **every contract block found** in the world (grid name, owning faction, entity id).
   - Adds a `GVK-EscortConvoy`-type test contract to the first block found on a COALITION grid.
   - Subscribes to `CustomActivateContract/FinishFor/FailFor/CleanUp` and logs all events.
3. Accept the contract at the base terminal → verify it activates and logs.
4. Restart server mid-contract → verify contract survives in log; spike logs re-resolution.
5. MES sanity: admin button panel trigger with `SetSandboxCounters`, restart, verify counter held
   and advanced (validates 7e6566e + 919f024 are in the deployed build).

**Pass criteria for spike:** step 2 finds the block and the contract appears on its board.
If it does NOT appear → fallback options: (a) admin-place + faction-transfer the block,
(b) investigation of block `Generation` settings on prefab-spawned grids, (c) custom
script-side offering UI.

**Spike results (2026-09-21):**
- ✅ **Q1 PASS**: contract added (`SUCCESS: contract added, id=1001215467579021369`) and
  **visible in the Base's "NPC Contracts" terminal**. Pass criteria met; no fallbacks needed.
- Root cause of the first failed attempt: `startBlockId: 0` (see §3 gates row). Fixed.
- Note: the spike adds a fresh test contract **on every world load** — expect duplicates
  during testing; harmless (0-reward, 240 min expiry).
- ✅ **Q2 PASS** (10:24): `EVENT CustomActivateContract: contract=1001215467579021369 player=...` +
  vanilla economy ledger logged the acceptance (`CONTRACT,ACCEPT,...,MyContractCustom,True,...`).
- ✅ **Q3 PASS** (10:25): accepted contract survived world reload; spike re-added a second test
  contract on load as expected (per-session behavior, not production).

**SPIKE COMPLETE — Option B fully validated. Proceeding to production implementation (§10).**

## 10. Implementation Status (MES-native, 2026-09-21)

**Shipped (SBC-only, no C#):**
- `Content/Data/Encounters/Convoy/Contracts/GVK-EscortMissions-Missions.sbc` — 3 × `[MES Mission]`
  (A: 8000 cr, B: 6000 cr, E: 10000 cr; all `Exclusive`, `OverrideFaction:COALITION`,
  `Duration:360`, per-route `InstanceEventGroupId`)
- `.../GVK-EscortMissions-Board.sbc` — `[MES Contract Block]` profile + board behavior,
  refresh trigger (10 min), `NoActiveContracts` condition, refresh action (clears outcome flags,
  `[ApplyContractProfiles:true]`, `[ClearContractContentsFirst:true]`, block names
  `Contracts` + `NPC Contracts`)
- `.../GVK-EscortMissions-Signals.sbc` — per-route loss actions, arrived/lost event conditions,
  and the `TryContractSuccess` / `TryContractFail` event actions
- `.../GVK-EscortMissions-EventTemplates.sbc` — 3 template groups × (spawn, arrived, lost)
- Convoy behaviors: `[SetSandboxBooleansTrue:GVK_EscortArrived_X]` added to `Action-EscortSuccessA/B/E`;
  `GVK-EscortMissions-Action-ConvoyLost-X` added to the existing BeaconDisabled, Compromised, Despawn
  and DespawnMES triggers
- Board hosting: board trigger added to `GVK-PlanetaryInstallation-Large-Behavior` (station bases,
  incl. existing worlds) and `GVK-EscortContracts-BoardBehavior` attached to the Z0 hub prefab slot
  (`NST Crossroads Tower V3` in `GVK-Static-Generic-SpawnGroup.sbc`)
- Ambient `GVK-Convoy-Event-CoalitionA/B/E` remain `[UseEvent:false]`; their condition/action/spawner
  profiles are reused by the mission spawn templates
- Deleted: `EscortContractSession.cs`, `EscortContractRouteTable.cs`, `EscortContractSpike.cs`,
  `Content/Data/ContractTypes/GVK-ContractTypes.sbc` (MES ships `MESContract`)
- `[UsePlayerDistanceTimer:false]` retained in all 6 Coalition convoy behaviors
- Regression fix in the same pass: `WeeklyScheduler_Session` now passes `forceSpawn: true` and logs
  rejected spawn requests (its scheduled raids were silently filtered to zero by MES conditions)

**Verification gates:**
- `audit_sbc.ps1` — PASS (no deserializer hazards)
- `audit_mes_tags.ps1` — 182 findings, identical to the pre-change baseline (no new findings);
  all remaining are the known cross-mod faction false positives (factions live in GVK_Settings)
- `audit_mes_references.ps1` — pre-existing orphans only
- `dotnet build -c Release` — 0 errors; `mdk pack` deployed to
  `%AppData%\SpaceEngineers\Mods\GVK_Derelicts` (verified: new SBCs present, stale script/contract
  files removed)
- **In-game: NOT YET VERIFIED** — see §11

## 11. In-Game Verification Plan

1. Reload the world; open the base's contract block ("Contracts"/"NPC Contracts").
   Expect three missions (A/B/E) offered by COALITION; each shows reward/duration from the profile.
   - If nothing appears: `/MES.BehaviorDebug.*.true` + `BehaviorLogger` for
     "Applying contract Profiles" / "Couldn't find Mission Profile"; check the base grid actually
     runs the board trigger (behavior re-attach on spawn).
2. Accept Route A → convoy spawns at the route start within a second or two (instance event →
   `GVK-Convoy-EventAction-CoalitionA`), and the *NPC* OnSpawn chat fires
   ("A transport is ready for escort from Crossroads to Sevastopol (Difficult).").
3. Escort the transport to Sevastopol → arrival action sets the flag → contract completes
   (payout + reputation). No script chat: the NPC chat is the voice.
4. Repeat but destroy the transport → per-route loss trigger → contract fails (owner refunded).
5. Restart mid-escort → contract survives; finish it to validate the whole chain across a reload.
6. Idle 10+ min with no active contract → board refreshes and re-offers completed routes.

### Known trade-offs / follow-ups
- **Completion = transport arrival only.** The two escort cruisers in Route A's lead group are not
  required to survive; add them if the mission should be harsher.
- **Loss detection** = beacon disabled, compromised, or despawned (RivalAI `Despawn` and MES cleanup),
  plus contract expiry as backstop. The arrived-flag guard in the fail condition prevents false
  positives from the post-delivery despawn.
- **Board refresh interval is 10 min**, so a completed route can take up to 10 minutes to re-appear.
- **Routes A and E can be run simultaneously** (separate missions; per-route flags keep them
  independent). If you want one escort at a time, add a shared `PersistantEventConditionIds` gate.
- **Station faction**: the board behavior attaches to whatever grid hosts a `Contracts`/
  `NPC Contracts` block, while the mission's faction is `COALITION` (mission `OverrideFaction`) —
  the block owner still escrows the reward. Designate a Coalition-owned hub prefab to make the
  fiction exact.
- `MinContracts`/`MaxContracts` exist in `[MES Contract Block]` but MES ignores them (see the
  upstream contribution doc, `Docs/MES-Contribution-MissionContracts.md`).


---
*Note: waypoint file audit found junk entries — `GVK-Convoy-WaypointStatic-` (empty SubtypeId +
empty Coordinates) at RouteA line ~975–985 and a stray `"` at line ~1009. Fix during
implementation; run `audit_sbc.ps1`.*
