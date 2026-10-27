# GVK_Derelicts

Every NPC on the **GV: Deserts of Kharak (GVK)** server: wrecks, Units, convoys, alliance bases, freighters, KOTH sites and what they say. It is MES (Modular Encounters Systems) and RivalAI data, plus two small scripts. Workshop item: GVK11 MES NPC Addon (2653133286).

## How it is built
- **NPC behavior is data.** Spawn groups, conditions, behaviors, triggers, autopilots and chatter are SBC and XML files that MES reads. The only C# is in `ModScripts/`: a weekly scheduler that fires events through the MES API, and the refuelling tether for the Coalition Route E aerial escort.
- **Repeated structures are generated.** The leash, patrol switch and peer-escort trigger groups come from the `tools/New-*.ps1` generators, so ten behaviors cannot disagree about one rule.
- **One vocabulary.** Terms (Unit, Wreck, Convoy Contract, Territory and so on) are defined once in [GLOSSARY.md](GLOSSARY.md).
- **The docs check themselves.** Reference tables are rebuilt from the SBC files, and `tools/Test-Docs.ps1` fails on the mistakes MES never reports.
- **Debug by looking first.** MES logs are slow to read, so check visually (see below) and only then turn logging on.

## Requirements
- A build of MES made **after master `a1895d9` (2026-10-24)**. Workshop 2.75.01 is not enough: older builds ignore or misread tags this repo uses. The list is in [Docs/design/server-build-requirements.md](Docs/design/server-build-requirements.md).
- WeaponCore, and the GVK weapons pack loaded after it, for the NPC weapons.
- The rest of the server mod list: [Steam collection](https://steamcommunity.com/sharedfiles/filedetails/?id=2650582206).

## Operator cheat sheet
Sandbox variables, with what reads and writes each one, are generated in [Docs/reference.md](Docs/reference.md). When to switch each during a season: the se-dev-kharak skill, `server-context.md` §11. Set a boolean with `/MES.Debug.ChangeBool.<Name>.<true|false>`.

| Command | What it does |
| --- | --- |
| `/MES.Debug.DrawPaths` | Draws every NPC's waypoint lines: the way to check autopilot behavior |
| `/MES.Debug.ShowAllZones` | Draws zones and Known Player Areas |
| `/MES.IGGB` (looking at a grid) | Shows that grid's mode, subclass and autopilot state |
| `/MES.Debug.ChangeCounter.<Name>.<n>` | Adds `n` to a sandbox counter, for example `SOBAN_Tier.-45` or `<FACTION>_DepotDemand.1` |
| `/MES.Debug.ResetZones` | Needed after editing a zone profile, or the change does nothing |
| `/MES.Debug.ClearUniqueEncounters`, `/MES.Debug.ClearStaticEncounters` | World build: reset unique and static spawns |
| `/MES.Spawn.StaticEncounter` | Spawns a static encounter by name (MES wiki, chat commands) |
| `/MES.BehaviorDebug.Trigger.true`, `/MES.BehaviorDebug.Condition.true` | Logs which triggers and conditions fire |
| `!faction rep change <TagA> <TagB> <amount>` | CrunchUtils: sets a faction-to-faction relation (1500 friendly, 0 neutral, -1500 hostile) |
| `!faction rep <TagA> <TagB>` | Shows that relation, to check a build |
| `!eco give <player/faction> <name/tag> <amount>` | CrunchUtils: gives money (the Coalition trader's balance, for example) |
| `!voxels reset all true` | World build: resets voxels |

The `/MES` commands are checked against the MES source; the `!` commands were last checked against the hub world-build list on 2026-10-26. The full world-build and season checklist is in the hub, issue #494, not here.

If something looks wrong, in this order: `DrawPaths`, `ShowAllZones`, `IGGB`; then the MES logging notes in the se-dev-mes skill (`diagnostics_and_troubleshooting.md` §2.D and §3).

## Naming
Prefab names start with a three-letter tag, then the four-letter faction tag, for example `NWS [COAL] Combat Baserunner`. Profile SubtypeIds start with `GVK-` and the system name. The tag list and the Encounter Types are generated in [Docs/reference.md](Docs/reference.md); the rest of the conventions are in [AGENTS.md](AGENTS.md).

## If you are building your own NPCs with this as a reference
Worth copying:
- **Encounter types set at init.** Every behavior's init action sets its Encounter Type and display name, which chat, despawn and refund rules key on ([reference](Docs/reference.md)).
- **Generated trigger groups.** [tools/New-LeashGroup.ps1](tools/New-LeashGroup.ps1), [New-PatrolSwitchGroup.ps1](tools/New-PatrolSwitchGroup.ps1) and [New-PeerEscortPool.ps1](tools/New-PeerEscortPool.ps1).
- **Dialogue banks.** Lines written as drafts and built into banks by [Docs/dialogue/scripts/build_banks.py](Docs/dialogue/scripts/build_banks.py); how they are wired: [Docs/design/dialogue-banks.md](Docs/design/dialogue-banks.md).
- **Zone-gated spawns.** The zones are in `Content/Data/Encounters/GVK-Universal-Zone.sbc`.
- **One live base per site.** [Docs/design/preset-bases.md](Docs/design/preset-bases.md).
- **A checklist for wreck prefabs.** [Docs/design/wreck-prefabs.md](Docs/design/wreck-prefabs.md).

Traps this repo hit and documented: escorts falling into MES's one-way retreat ([escorts and peer wings](Docs/design/escorts-and-peer-wings.md)), Known Player Areas locking an area to one faction ([parent leash](Docs/design/parent-leash.md)), MES unable to keep spawns out of a zone ([KOTH despawn](Docs/design/koth-despawn.md)), terrain checks that read the wrong area ([installation terrain](Docs/design/installation-terrain.md)). General MES lessons are in the se-dev-mes skill, not here.

## Folder map
| Path | What is in it |
| --- | --- |
| `Content/Data/Encounters/` | Spawn groups, conditions, behaviors, triggers, autopilots, zones, per faction and system |
| `Content/Data/Prefabs/` | The NPC grids |
| `ModScripts/` | The weekly event scheduler (`WeeklyScheduler_*.cs`) and the aerial escort refuel session |
| `Content/Data/StorePrefabs/`, `StoreItems/` | Grids and items the stores sell |
| `Content/Data/DialogueBanks/` | NPC chat, built from `Docs/dialogue/` |
| `Docs/design/` | How each system is built ([index](Docs/design/README.md)) |
| `Docs/dialogue/` | Dialogue drafts, lore and build scripts |
| `Docs/adr/` | Hard-to-reverse decisions |
| `Docs/reference.md` | Generated tables |
| `tools/` | Generators and checks (below) |

## Tools
Run from the repo root.

| Script | What it does |
| --- | --- |
| `tools/Update-DocTables.ps1` | Rebuilds [Docs/reference.md](Docs/reference.md) and the design doc index from the SBC files and the design docs. `-Check` only reports |
| `tools/Test-Docs.ps1` | Fails on dialogue, leash, terrain and other rules MES never reports |
| `tools/Test-MesFreshness.ps1` | Checks the MES version the content was written against |
| `tools/New-LeashGroup.ps1`, `New-PatrolSwitchGroup.ps1`, `New-PeerEscortPool.ps1` | Generate the repeated trigger groups |

The `se-dev-mes` skill's audit scripts (`audit_sbc.ps1`, `audit_mes_tags.ps1`, `audit_mes_references.ps1`) should pass with 0 errors before a commit.

## Design docs
[Docs/design/README.md](Docs/design/README.md) lists them with the files each one covers. Notes keep their old numbers because hub issues cite them.

## Quick links
- Hub board and issues: [GV-Server-Mods/GVK-Settings](https://github.com/GV-Server-Mods/GVK-Settings) ([open `area:npc`](https://github.com/GV-Server-Mods/GVK-Settings/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Anpc), [open `upstream`](https://github.com/GV-Server-Mods/GVK-Settings/issues?q=is%3Aissue+is%3Aopen+label%3Aupstream))
- Skills: [se-dev-mes](https://github.com/GV-Server-Mods/se-dev-mes), [se-dev-kharak](https://github.com/GV-Server-Mods/se-dev-kharak)
- MES: [MeridiusIX/Modular-Encounters-Systems](https://github.com/MeridiusIX/Modular-Encounters-Systems)
- WeaponCore: [Ash-LikeSnow/WeaponCore](https://github.com/Ash-LikeSnow/WeaponCore)
- Steam guide: [players' rules and gameplay](https://steamcommunity.com/sharedfiles/filedetails/?id=2781522559); mod collection: [2650582206](https://steamcommunity.com/sharedfiles/filedetails/?id=2650582206)
- Examples from other MES authors: Enenra's [MSB](https://github.com/enenra/mes-shared-behaviors) and [GFA](https://github.com/enenra/gfa/tree/86dab4803276eda74a3359e10cf5e93d9eef6301/GFA%20-%20MES%20Utilities/Content)

## Thank yous
- Nekron910: https://steamcommunity.com/sharedfiles/filedetails/?id=2650194963&tscn=1643638039
- Engineered Coffee: https://steamcommunity.com/id/EngineeredCoffee/myworkshopfiles/
- Rayman11NL: https://steamcommunity.com/profiles/76561198210730607/myworkshopfiles/
- Enenra and the MES authors, for the examples above and for reviewing upstream fixes.
