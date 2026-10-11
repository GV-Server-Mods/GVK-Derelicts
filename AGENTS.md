# GVK_Derelicts Workspace Guidelines

Specific rules, architecture, and conventions for the **GVK_Derelicts** encounter mod on the **GV: Deserts of Kharak (GVK)** server.

---

## 1. Modular Encounters Systems (MES) Framework Reference

All general Modular Encounters Systems (MES) and RivalAI modding rules, tag dictionaries, engine bug workarounds, XML deserializer safeguards, and token matrices are managed by the **`se-dev-mes`** skill.

- Consult the **`se-dev-mes`** skill for tag syntax, master-gate verification, and engine constraints.
- Run the diagnostic scripts in `se-dev-mes/scripts/` before committing changes:
  - `audit_sbc.ps1` (XML deserializer checks)
  - `audit_mes_tags.ps1` (MES semantic linter)
  - `audit_mes_references.ps1` (Cross-file profile reference validator)
  - `New-MesProfile.ps1` (Encounter scaffolding generator)

---

## 2. GVK Factions & Zone Architecture

### Faction Tags
- `COALITION`: Starter Hub, civilian trade, non-hostile Kiith.
- `GAALSIEN`: Hostile NPC desert raiders, aggressive military encounters.
- `DERELICT`: Hostile automated wreckage & defense relics.
- `SOBAN`: Neutral mining Kiith (Alliance system).
- `KHAANEPH`: Nomad scavengers (Alliance system).
- `KOTH`: King of the Hill objective faction.

### Zone Hierarchy (Crossroads Tower Center: 62495, 28019, 37195)
- **Zone 0 (0 – 20 km)**: Safe Starter Hub. Strictly no PvP.
- **Zone 1 (20 – 35 km)**: Small derelicts and basic salvage.
- **Zone 2 (35 – 50 km)**: Medium defended wrecks, cargo convoys.
- **Zone 3 (> 50 km)**: Deep desert, heavy military convoys, Gaalsien cruisers.

---

## 3. GVK Naming & Directory Conventions

### Profile SubtypeId Naming
- Format: `GVK-<SpawnType>-<SubType>-<ProfileType>-<UniqueTag>` (`<SubType>` and `<UniqueTag>` are optional).
- Examples:
  - `GVK-Drone-Encounter-Behavior-Salvager-COALITION`
  - `GVK-PlanetaryInstallation-Small-Behavior`
  - `GVK-Universal-Trigger-DespawnInZ0`
- Prefab names: three-letter tag + 4-letter faction tag, e.g. `NWS [COAL] Combat Baserunner`. The tag list is generated in `README.md`.

### NPC Chatter (Dialogue Banks)
Every behavior that uses `GVK-Universal-TriggerGroup-DefeatedAndAttacked` also needs a `[DialogueBanks:GVK-<Category>-<FACTION>.xml]` line, where Category is `Units`, `Travellers`, `Structures` or `Installations` and FACTION is the faction its spawn groups spawn it as. MES fixes the bank per behavior, so if two factions' spawn groups share a behavior, give each faction its own copy with its own bank and a `[//CopyOf:<original>]` line, and keep the copies identical otherwise. Details: README note 37.

### Directory Layout
- `Content/Data/Encounters/`: Spawn groups, behaviors, and trigger groups.
- `Content/Data/Prefabs/`: Grid blueprint files (do not edit manually unless modifying block definitions).
- `Content/Data/StorePrefabs/`: Economy store grids.

---

## 4. Pre-Commit Verification Checklist

Before testing in-game or committing any `.sbc` modifications in `GVK_Derelicts`:
1. **XML & Deserialization**: Run `audit_sbc.ps1` to ensure no duplicate `<SubtypeId>`, duplicate `<Id>`, or `<!-- -->` comments inside `<Description>`.
2. **Tag Validity**: Run `audit_mes_tags.ps1` to ensure no zero-stripping in `CustomCountersTargets`, no `WaypointNear` crashes, and all boolean master gates are present.
3. **Reference Integrity**: Run `audit_mes_references.ps1` to ensure every referenced trigger, action, condition, spawner, and spawn group exists.

---

## 5. Documentation Rules (keep docs from going stale)

Each kind of fact has exactly one home. Don't copy it anywhere else.

| Fact | Home |
| --- | --- |
| Work, ideas, bugs, and the status of upstream fixes ("PR open", "waiting on MES") | GitHub issues in GVK-Settings (`upstream` label for MES/WeaponCore). Never in Markdown, and never as `TODO` comments in SBC or C#. |
| MES tags and behavior | The MES source, through the `se-dev-mes` skill. Never vendor copies of the MES wiki. |
| Data that lives in SBC (sandbox variables, Encounter Types, defense limits, prefab tags) | The SBC files. `tools/Update-DocTables.ps1` regenerates the README tables between `GENERATED` markers. |
| Vocabulary | `GLOSSARY.md` |
| Hard-to-reverse decisions | `Docs/adr/` |
| Durable lessons and admin how-tos | `README.md` notes. Say which MES version a behavior note was checked against. |

- When a change alters something a doc describes, update the doc in the same commit.
- The local Stop hook runs `tools/Test-Docs.ps1`. It flags:
  - docs that reference profiles, prefabs or paths that no longer exist
  - docs that call an MES issue/PR open after it has merged or closed
  - any `TODO`/`FIXME` comment in the encounter SBC files or ModScripts
  - dialogue bank mistakes: a DefeatedAndAttacked behavior with no bank, a missing or misnamed bank file, a bank whose faction doesn't match the behavior's spawn groups, a `[//CopyOf:]` copy that drifted from its original, and a bank missing a cue its faction can hear

---

## Agent skills

### Issue tracker

GitHub Issues on GV-Server-Mods/GVK-Settings (Issues are disabled on GVK-Derelicts) via the `gh` CLI. See `Docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary (needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix). See `Docs/agents/triage-labels.md`.

### Domain docs

Single-context: root `GLOSSARY.md` + `Docs/adr/`. See `Docs/agents/domain.md`.
