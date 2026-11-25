---
title: Prefab suspensions and tracks
covers:
  - tools/Update-PrefabTracks.py
checked: 2026-11-25
---

# Prefab suspensions and tracks

Built 2026-11-25 with Rubber Track everywhere and checked in game the same day on the store cruisers, Light Hauler, the NPC cruisers, Carrier, Scraptown and the NWM wreck (owner: "every one of them looks good"). The COALITION and SOBAN NPC tracks moved to Kharak Double Tread the same day, not tested in game yet.

NPC grids and store grids use only suspension and wheel blocks players can build (owner, 2026-11-25: "This job should be identical across all prefabs"). Tracks on COALITION and SOBAN NPCs are Kharak Double Tread (owner, 2026-11-25: "Make all of the COAL and SOBA NPCs use the Kharak Double tread"); every other track, store grids included, is Rubber Track. A store grid's projector copy gets the same blocks, so a bought grid welds what the player could have built.

## The swap

`python tools/Update-PrefabTracks.py` rewrites every prefab and store prefab, projector copies included. Run it after exporting a prefab with suspensions or tracks; `tools/Test-Docs.ps1` flags one that needs it. `--check` lists what it would change.

| Hidden GVK_Suspension block (hidden 2026-11-22) | Becomes |
| --- | --- |
| Lifted Short Track Suspension, any size and hand | GVK's Lifted Short Suspension, same size and hand |
| Short Track Suspension, any size and hand | Keen's Short Suspension, same size and hand |
| Real Track Wheel, any size | Keen's tire of that size; the mirrored tire on a mirrored suspension, as Keen pairs them |
| Track Wheel 1x1, Short Track Wheel 1x1 (1x2x1) | Keen's Wheel 1x1 in the block's hull-side cell, same facing |
| Track Wheel 3x3 | Left as it is (only Scraptown has one, as decoration in no track) |

- Each pair has the same block size, mount and physics (GVK_Suspension's `track-wheel-swap.md`, Part C). Under a Kharak or Rubber track the tires show the GVK track wheel, so a bought grid looks the same as before.
- A saved track (Tank Tracks mod storage on the suspension that leads it) lists each roller by its block's `Min` cell. Where a Track Wheel 1x1 shrank to a Wheel 1x1, the tool moves that roller to the new cell; a roller with no block in its cell makes Tank Tracks drop the track.
- Every track gets its prefab's tread: `KharakDoubleTread_Large` on `Prefabs/` files tagged `[COAL]` or `[SOBA]`, `GVK_RubberTrack_Large` on the rest (`design_for` in the tool). The tool stops if a roller has no style for that tread in GVK_Suspension's `TankTracks.ini`: a roller with no style for the track's design also makes Tank Tracks drop the whole track.

## Wheel 1x1 rollers

Under a GVK track, Keen's Wheel 1x1 shows the Track Wheel 1x1 block (owner, 2026-11-25: "lets look at swapping them all to the vanilla 1x1 wheels, then building the tank tracks dynamic model swap for when it is added to tracks"). GVK_Suspension's `track-wheel-swap.md` ("Wheel 1x1 rollers") has how.

- The look is the Track Wheel 1x1 moved 1.25 m out, so it shows right only on a Wheel 1x1 in the cell next to the hull, top facing out (the way the suspensions face). The tool turns every Wheel 1x1 roller to face out and lists any that is not next to the hull.
- Keen's Wheel 1x1 is in the G menu (the static wheel group), so a player can rebuild one.

## In-game test

Restart the game fully first (the new models load once), then load GV Kharak S11 NPC Dev.
1. Spawn `NUN [COAL] Battlecruiser`, `NST [SOBA] Carrier` and a Light Hauler from the store. Pass: every track is there, Kharak Double Tread on the NPCs and Rubber Track on the Light Hauler; the tires show track wheels (double wheels under Double Tread); the end rollers show the Track Wheel 1x1 (double) on the track line.
2. Buy the store Battlecruiser and weld its projector copy. Pass: the projection welds, and its tracks appear as each one finishes.
3. Grind one end roller off a track and weld it back. Pass: the tire shows while the track is gone, the Track Wheel look comes back with the track.
