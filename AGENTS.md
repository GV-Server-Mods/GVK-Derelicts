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
- Format: `GVK-<Type>-<Faction/Category>-<DescriptiveName>`
- Examples:
  - `GVK-Trigger-Damage-GaalsienScout`
  - `GVK-Action-DeployDefense-Carrier`
  - `GVK-SpawnGroup-ScrapRace-Set10`

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
