# Retire "Drone" in favor of "Unit"

GVK called every AI-piloted NPC vehicle a "Drone": the `NDR` ("NPC DRone") prefab tag, the `Drone*` Encounter Types, and the `Drone/` folders. We now call them **Units**, after the RTS term from Deserts of Kharak. The old name clashed with the MES Drone Encounter spawner, which GVK doesn't use. It also hid the cross-faction class ladder that Units now follow: Scout, Fighter, Gunship, Baserunner, Salvager, Corvette, Cruiser and Airship. The glossary switched first. The prefab tag followed as `NUN` ("NPC UNit"); the `Drone*` Encounter Types, `Drone-*` profile ids and `Drone/` folders followed in GV-Server-Mods/GVK-Settings#662 (phase 2), while the world was not live, because renaming spawn groups touches saved state.

## Considered Options

- **Keep "Drone"**: it was already player-visible, but it would keep the MES collision.
- **Raider**: rejected. GAALSIEN are already the "desert raiders", and COALITION or SOBAN Units aren't raiders.
- **Vehicle**: rejected as too generic.
- **Craft, Mobile, Combatant**: "Craft" leans toward aircraft and is already a display name. "Mobile" reads as an adjective. "Combatant" doesn't fit Salvagers.