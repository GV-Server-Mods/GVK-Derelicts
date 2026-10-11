# NPC Dialogue Research

Reference material and tools for writing NPC chatter in the dialogue banks (`Content/Data/DialogueBanks/`). The bank wiring is in README note 37.

## Layout

| Folder | What | In git |
|---|---|---|
| `scripts/` | Python tools: fetch lore, clean transcripts, fix mishearings, extract phrases | yes |
| `lore/` | Plain text of the Homeworld Wiki faction pages, and `lexicon.txt` of their linked names | yes |
| `analysis/` | Recurring phrases per transcript, with counts, and the mishearing table | yes |
| `reference/` | Raw and cleaned game transcripts, wiki JSON, cutscene excerpts | **no** (local only) |

`reference/` is git-ignored because the transcripts are full transcriptions of the game's copyrighted dialogue. Keep it backed up locally. Everything else can be rebuilt from it with the scripts.

## Sources

**Transcripts** (YouTube auto-captions, saved by the server owner as `reference/raw/<name>.txt`):

| File | Content |
|---|---|
| `cutscenes` | Campaign cutscenes only (Coalition view: Rachel S'jet, the Kapisi; some Gaalsien transmissions) |
| `playthrough` | Full campaign playthrough: cutscenes plus Coalition unit chatter and alerts |
| `coalition-skirmish` | Coalition skirmish unit chatter |
| `gaalsien-units` | Gaalsien unit chatter (two videos, several unit types) |
| `soban-carrier` | Soban fleet operations and carrier alerts |
| `soban-aircraft` | Soban aircraft chatter |
| `khaaneph-baserunner` | Khaaneph Baserunner and support chatter |

**Lore:** [Homeworld Wiki](https://homeworld.fandom.com) pages [Coalition of the Northern Kiithid](https://homeworld.fandom.com/wiki/Coalition_of_the_Northern_Kiithid), [Kiith S'jet](https://homeworld.fandom.com/wiki/Kiith_S%27jet), [Kiith Gaalsien](https://homeworld.fandom.com/wiki/Kiith_Gaalsien), [Kiith Soban](https://homeworld.fandom.com/wiki/Kiith_Soban) and [Khaaneph](https://homeworld.fandom.com/wiki/Khaaneph). Wiki text is CC BY-SA 3.0. The files in `lore/` are copies of it, so they keep that licence and this attribution.

## Pipeline

Run from this folder (`Docs/dialogue`):

```
python scripts/fetch_lore.py              # wiki pages -> reference/lore-json/
python scripts/clean_lore.py              # -> lore/*.txt, lore/lexicon.txt
python scripts/clean_transcripts.py       # reference/raw/*.txt -> reference/clean/*.tsv (timestamps, [Music] removed)
python scripts/normalize_split.py         # fixes mishearings; splits the playthrough into cutscenes vs gameplay chatter
python scripts/extract_phrases.py         # analysis/coalition_barks.txt, reference/gaalsien_voice.txt
python scripts/extract_phrases.py reference/clean/<name>.tsv   # analysis/<name>_barks.txt
python scripts/find_variants.py [reference/clean/<name>.tsv ...]  # candidate mishearings of lore names
```

**Adding a transcript:** save it as `reference/raw/<faction>-<topic>.txt`, run `clean_transcripts.py`, then `find_variants.py` on the new `.tsv`, add any new mishearings to `scripts/fixes.py`, and run `extract_phrases.py` on it.

The auto-captions mishear lore names. `scripts/fixes.py` is the shared correction list, for example gaussian→Gaalsien, capisi→Kapisi, kartoba→Khar-Toba, kagon→Khagaan, "god set"→"guard set", "face runner"→Baserunner.

## Faction voice guides

### COALITION (Coalition of the Northern Kiithid)
- **Who:** a confederacy of kiithid under the Daiamid, capital Tiir. Kiith S'jet (science, yellow colours) led the Khar-Toba expedition on the carrier Kapisi, and Kiith Manaan are nomad merchants and explorers. In GVK they run the starter hub and scrap refiners, and they are the players' natural allies.
- **Register:** calm, procedural radio. Short clauses with call-and-response.
- **Chatter vocabulary** (use as style, never as whole lines): go ahead, make ready, copy, order confirmed, guard position, vector dialed, taking effective fire, green line confirmed, eyes out, five by five, hostile armor, light attack vehicle, strike craft, engage on site, standing by, reading you, moving out; friendly taking hostile fire, provide fire support, visually authenticated, authentication pending, heat levels spiking, reroute power.
- **References:** the Daiamid, Tiir, the Frontier Wall, the Kapisi, the S'jet expedition, Khar-Toba and the primary anomaly, Gaalsien raiders, the Boneyard.
- **By bank:** Units are military crews. Travellers are Manaan traders and transport crews, civilian and worried. Installations are science and salvage outposts and Mission Givers, procedural.

### GAALSIEN (Kiith Gaalsien)
- **Who:** exiled zealots of the Great Banded Desert, cast out after burying Saju-ka. They follow the Decree of Kah'a. Kharak is Sajuuk's punishment for the sin of hubris, and seeking the stars is blasphemy. They treat crashed starships (the Kalash) as sacred, so damaging or salvaging them is profanation. Leaders: Khagaan (carrier Ashoka) and K'had Sajuuk (flagship Hand of Sajuuk).
- **Register:** two layers.
  - **Crews (Units):** cold, ritual-like procedure, more clinical than the Coalition. Verify, authenticate, cycle and directive words, with faith showing only in the nouns. Chatter vocabulary: relay verified, cycle commencing, telemetry received, diagnostic cycle, cruiser verifies, command authority, protocols in effect, returns are negative, guard directive, barrage authorized, maintain separation. Enemies are **heretics** and **northerners**.
  - **Leaders, structures and last words:** formal, prophetic, second-person judgement. They never panic, and they welcome death as penance.
- **Their own words:** the Coalition are **Faagani**, "the Bound and the Blind", followers of a false god but redeemable. **Khaaneph** means godless, the thing even the Gaalsien fear. Sajuuk is "the Great Maker, Whose Hand Shapes What Is". Also: the exile, penance, hubris, the stars forbidden, the desert as Sajuuk's will.
- **GVK fit:** players strip wrecks for scrap, which is profanation in Gaalsien eyes. Use that for Installations GAALSIEN.

### SOBAN (Kiith Soban, the Grey Brotherhood)
- **Who:** a landless mercenary kiith founded by Soban the Red, who tore off his old kiith colours. They fight without regard to risk or cost, and leave the minute a contract ends. Renewal only goes through their Kiith-Sa, never on the field. Sobani red, Somtaaw steel, Sobani academies; two legions won the Night of Fiery Daggers against the Gaalsien. In GVK they are a player alliance faction guarding Soban Territory.
- **Register:** clipped, professional and dryly confident. Contract and honour language, no bravado. Pilots are a little looser and cockier than the Coalition's.
- **Chatter vocabulary:** be advised, fleet group assigned, taking hostile fire, alert all stations, we require additional, positive lock, keep steady on target, take it out, light it up, push it up, bullseye, payload empty, returning to carrier, I'm all out. Damage reports are blunt.
- **References:** the contract and its terms, colours (wearing red, tearing colours), the Kiith-Sa, the Brotherhood, Soban the Red, the Night of Fiery Daggers, cost and price.

### KHAANEPH ("the Godless")
- **Who:** descendants of the Gritiidim, cast-out families who lost faith in everything. No god, no law, no kiith, only survival. They prey on caravans and settlements and take everything: every scrap, every machine, even corpses. They ride with the storms and are the monsters even the Gaalsien fear. They attack in waves with salvaged Gaalsien hovercraft, heavy armour, missiles, explosive drones and siege weapons. In GVK they are a player alliance faction.
- **Register:** **cold and machine-flat, not feral.** In-game they sound like an obedient war machine: comply, battle advance commanded, nullify their push, prosecute designated hostiles, uphold battle formation, institute guard protocol, escort directive, diagnostic cycle commencing. Damage reports are eerily detached. Enemies are **northerners**. The menace comes from the lore (prey, stripping, the godless) delivered in that flat procedural voice. Their loyalty lasts only as long as you are useful or stronger.
- **References:** prey, the hunt, scrap and salvage, the storm, the deep south, cutting the rope (the Faagan metaphor turned around), bones, the pack, picking clean.
- **Never:** prayer, honour or law, except to mock them.

### DERELICT (automated relics)
- **Who:** unmanned ancient defence systems in GVK wrecks. They echo the orbital weapon's recognition code and ID transponder from the campaign.
- **Register:** ALL CAPS system messages, impersonal, with protocol and error terms.
- **References:** recognition codes, transponder, authorisation, protocol numbers, power rerouting, core integrity, shutdown.

## Cues

| Bank | Cues |
|---|---|
| Units COALITION / SOBAN / KHAANEPH | TargetAcquired, TargetStructure, TargetAircraft, TargetInfantry, TargetFastMover, TargetLongRange, NoTargets, NeutralAttacked, EnemyAttacked, FriendlyFire, Defeated |
| Units GAALSIEN | as above, without FriendlyFire (NeutralAttacked kept but rarely heard) |
| Travellers ×3, Structures ×2, Installations COALITION | NeutralAttacked, EnemyAttacked, FriendlyFire, Defeated |
| Installations GAALSIEN, DERELICT | EnemyAttacked, Defeated |

`Target*` cues are target-type callouts. One plays per target lock, from the first check that passes: Structure (static grid) > Aircraft (grid 40 m+ above terrain) > Infantry (player on foot) > FastMover (60 m/s+) > LongRange (2500 m+) > TargetAcquired (anything else). The chain is in `GVK-Universal-Behavior.sbc`.

## Line rules

- One sentence or two short ones, up to 90 characters. It's a chat line.
- `{Faction}` and `{GridName}` tokens work, but use them sparingly.
- No real-world slang or idioms that break the setting. Spellings: Kiith, Kharak, S'jet, Gaalsien, Sajuuk, Khar-Toba.
- Original writing only: no line may share 5 or more consecutive words with any transcript.
- No duplicates within a bank. Vary the openings.
