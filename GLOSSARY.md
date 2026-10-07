# GVK Derelicts

The NPC encounter content (spawned grids, their factions and the world they spawn into) for the GV: Deserts of Kharak server. Modular Encounters Systems (MES) engine terms are not defined here. A GVK term reuses an MES name only where the GVK concept matches that MES mechanic's name and intent.

**Encounter**:
An NPC grid, or a group of NPC grids, that this mod spawns into the world. Wrecks, Units, Convoys, Statics, Trade Stations and Caches are all encounters.

## Factions

**COALITION**:
The civilian trade faction that runs the starter hub. It is not hostile.

**GAALSIEN**:
The hostile faction of desert raiders behind most military encounters.

**DERELICT**:
The hostile faction that owns automated wreckage and defense relics. The word names only this faction, never a kind of grid.
_Avoid_: derelict (as a general noun for a wreck or an NPC grid)

**KOTH**:
The faction that owns the KOTH Sites. A KOTH Camp is a COALITION grid.

**SOBAN**:
A neutral mining faction; one of the two Alliance factions.

**KHAANEPH**:
A nomad scavenger faction; one of the two Alliance factions.

## World

**Zone**:
One of four distance rings (Zone 0 to Zone 3) measured from Crossroads Tower. The ring sets how dangerous an encounter is and whether PvP is allowed.
_Avoid_: ring, band, area

**Route**:
A lettered path (A to E) between two fixed points that NPC grids travel.

## Alliance competition

**Alliance faction**:
SOBAN or KHAANEPH: a faction that holds a Territory, competes for Influence, and that players can side with through reputation.
_Avoid_: Kiith (lore flavor for player-facing text only)

**Territory**:
The area that an Alliance faction controls. Its radius grows and shrinks with that faction's Influence.
_Avoid_: alliance zone, faction zone

**Influence**:
An Alliance faction's standing, which sets the size of its Territory. It moves when that faction's encounters are Defeated or Lost and when a Research Lab is claimed.
_Avoid_: points, alliance points

**Base Site**:
One of the fixed locations where a player in good standing can deploy an alliance Base for the faction whose Territory covers it.

**Supply Depot**:
A neutral depot that belongs to whichever Alliance faction's Territory covers it, and that Freighters supply.

**Research Lab**:
A neutral Wreck that players claim for an Alliance faction by holding it through an upload, which grants that faction Influence.

## Encounter categories

Most categories carry a three-letter prefab tag that leads the grid's name, e.g. `NWS [COAL] Combat Baserunner`.

**Wreck**:
A salvageable NPC grid of any faction, sized Small (NWS), Medium (NWM) or Large (NWL).
_Avoid_: derelict

**Signal**:
How an unidentified Wreck appears to players before they reach it, e.g. "Small Signal" or "Distress Signal".

**Downed Salvager**:
A crashed Coalition Salvager that a Recovery Mission asks players to recover. It is a Wreck, not a Unit.
_Avoid_: Salvager (on its own)

**Unit**:
An AI-piloted NPC vehicle of any faction, on the ground or in the air.
_Avoid_: drone, bot, NPC ship

**Static**:
A permanent NPC grid at fixed coordinates, such as a signpost, tower, bridge or race course (NST).

**Trade Station**:
A stationary Coalition grid that runs stores (NTS).

**Mission Giver**:
A Coalition grid that offers players a task, such as a Comms Relay, Turret Post or Support Cruiser (NMI).
_Avoid_: mission grid

**Turret Post**:
A Coalition gun emplacement that is a Mission Giver.
_Avoid_: turret station

**Cache**:
A reward crate grid that spawns for players to loot, such as a Cargo Drop or Ammo Drop (NLO).
_Avoid_: loot grid, drop

**KOTH Site**:
A permanent King of the Hill objective at a fixed location (NKO).
_Avoid_: Massive, megastructure

**KOTH Camp**:
A temporary King of the Hill site that expires after a fixed lifetime (NKO).
_Avoid_: KOTH Outpost, Player KOTH

## Structures

**Base**:
A large, stationary, defended NPC grid that anchors a faction's presence, such as an alliance Base or a GAALSIEN Base.

**Carrier**:
A mothership-class grid design. Each Alliance faction's Carrier is its central hub; GAALSIEN's Carrier leads a Convoy.

**Outpost**:
A smaller alliance structure that spawns on its own inside its faction's Territory.
_Avoid_: outpost (for KOTH sites, stores or wreck names)

**Turret**:
A stationary alliance gun emplacement. It spawns either as a Base's Defense or on its own inside a Territory.
_Avoid_: turret station

## Unit classes

A class is a battlefield role shared across factions; each faction fields its own designs for it. A Unit's threat size comes from its Encounter Type, not its class.

**Scout**:
A small, fast ground raider, e.g. the LAV or the Sandskimmer.
_Avoid_: LAV, Sandskimmer (as class names)

**Fighter**:
The smallest attack aircraft, e.g. the Strike Fighter or the Interceptor.
_Avoid_: Strike Fighter, Interceptor (as class names)

**Gunship**:
A small-grid attack aircraft that is larger than a Fighter and ranks as a Medium threat.

**Baserunner**:
A medium ground combat vehicle, built in Light and Heavy variants.

**Salvager**:
A Unit that roams the desert stripping wreckage. It can spawn on its own or from a Wreck.

**Corvette**:
A large-grid, medium-sized combat aircraft, between a Gunship and an Airship, e.g. the GAALSIEN Bomber, the Chad Shuttle or the Denizen.
_Avoid_: Bomber (as a class name)

**Cruiser**:
A large ground or hover combat Unit. Honorguard and Production Cruiser are Cruiser designs.

**Airship**:
A large flying combat Unit, the air counterpart of a Cruiser.

## Protective duties

**Defense**:
A Unit or Turret that a parent grid spawns to protect itself when players come near or attack it.
_Avoid_: reinforcement

**Escort**:
A Unit whose only job is to travel with a Convoy's lead grid and guard it.

## Route travel

**Convoy**:
A lead grid and the grids travelling with it along a Route, of any faction.

**Transport**:
A Coalition grid in a Convoy that a Convoy Contract protects. A Convoy can carry more than one.
_Avoid_: escort, cargo ship

**Trader**:
A lone Coalition grid that travels a Route and stops at stations to trade. It is not a Convoy.

**Freighter**:
An alliance supply ship that carries shipments from its faction's Carrier to a Supply Depot.
_Avoid_: cargo ship

## Missions

**Convoy Contract**:
A contract that a player accepts from the Coalition contract board to protect a Transport until it arrives.
_Avoid_: escort mission, escort contract

**Recovery Mission**:
A timed Coalition mission in which players recover Downed Salvagers.

## Economy

**Salvage Goods**:
Rare trade items found in Wreck loot and sold only at certain stores.
_Avoid_: Recovery items, mission items

## Encounter tiers

**Encounter Type**:
The threat tier of an encounter (e.g. Wreck Small, Unit Large, Alliance Base). It sets how much Influence, how large an explosion and how far a chat announcement the encounter's defeat is worth. It is separate from the encounter category and does not have to match it.

**Small / Medium / Large**:
The three threat sizes that Wrecks and Units share. They are threat sizes, not the Space Engineers small- or large-grid size.

**Elite**:
The top tier for Units, above Large: a Cruiser or Airship of any design, strengthened to boss level, that spawns on its own. It is not a dedicated design and not an MES Boss encounter.

**Structure tier**:
The tier of each alliance structure (Base, Outpost, Turret), scaled to how important the structure is. A Base is worth the most.

**Traveller tier**:
The single tier that Convoy lead grids, Traders and Freighters share.

## Encounter lifecycle

**Defeated**:
The state of an encounter that players have beaten. Defeat can shift Influence, sets off the encounter's explosion and announces it in chat.
_Avoid_: compromised, destroyed

**Lost**:
The state of an encounter that left the world without being Defeated.
_Avoid_: despawned
