---
title: Preset alliance bases
notes: [30]
covers:
  - Content/Data/Encounters/Alliance/PresetBases/*.sbc
  - Content/Data/Encounters/Alliance/GVK-Alliance-Base-Behavior-*.sbc
  - Content/Data/Encounters/Alliance/GVK-Alliance-Turret-Behavior-*.sbc
checked-against: MES d500922
---

# Preset alliance bases

## Note 30

Each Base Site (`NST [UNKN] Base Site`, a low static grid owned by UNKN) runs a contract board on its contract block `NPC Contracts` (GVK-Settings#653). The contracts are free, with no reward and no collateral. Accepting one sends a command to that Base Site, which does the work. The contract then succeeds at once.

| Contract | Who can accept | Effect | Limit |
| --- | --- | --- | --- |
| Claim Base Site | Friendly (reputation 500+) with the alliance | Spawns the Base; the Base adds 50 Influence once | No Base at the site, no kill lock; shown only while the site is inside that alliance's Territory |
| Deploy Defense Turret | Friendly with the Base's alliance | The Base spawns one Turret 300-500 m out | One per 20 min from when the last one was placed, 4 standing |
| Restore Base | Friendly with the Base's alliance | Repairs damaged blocks on the Base and its subgrids, switches its shield block on | One per 2 h |

While a player hostile to an alliance (reputation below 0) is within 5 km, that alliance's contracts can't be accepted. A contract blocked by the site's state shows as a stand-in that names the reason, such as `Deploy Defense Turret - KHAANEPH (cooling down)`.

### How it is built
- **Files:** the missions and board profiles are in `GVK-Alliance-PresetBases-Contracts.sbc`, the Base Site in `GVK-Alliance-PresetBases-Site-Behavior.sbc`, and the Base and Turret side in `GVK-Alliance-PresetBases-BaseSite.sbc`. [tools/New-BaseSiteBoard.py](../../tools/New-BaseSiteBoard.py) generates all three, so edit the script and re-run it rather than hand-editing the 29 board rules. For an in-game test, `--test-cooldown 10` in a throwaway worktree builds a copy with 10 s Turret and Restore cooldowns and marks its contracts as a test build.
- **One mission set serves all 22 sites.** The mission's event action broadcasts the command from `{ContractBlockLocation}` with a 150 m radius, and `{BoardCode}` (a mission `ReplaceKeys` value) names the contract. `[TryContractSuccess:true]` ends the contract and removes its event instance.
- **The Base Site keeps its own state** in local booleans and counters. These are which alliance's Base stands there, a 2 h kill lock, a 120 s claim-pending window, a 15 s Turret-placing window, the Turret and Restore cooldowns, the standing Turret count, a hostile-near flag per alliance, and an in-Territory flag per alliance. The in-Territory flags come from `InsideActiveZone` and `OutsideActiveZone` triggers on each alliance's zone, so a site that a Territory grows over or shrinks off updates its board within seconds. Each change fires the board's refresh tag. Exactly one of 25 refresh rules matches each state and re-applies its board profile with `ClearContractContentsFirst`. A Session trigger and a 10-minute timer also refresh the board.
- **Who can accept** is checked only by reputation. The Territory is checked on the site, not the player: the board shows Claim only while the site is inside it, and the player stands at the board. The Claim used to check the player's position as well. In testing on 2026-11-07 it refused a Friendly player at a site inside the KHAANEPH Territory but accepted SOBAN claims, and the code shows no difference between the two, so that check was removed.
- **Stand-ins.** A contract that the site's state blocks shows in its place as a stand-in: a hostile player near, a Turret being placed, 4 Turrets standing, or a cooldown. Its title names the reason, and its player condition needs a player tag nobody has, so it is always refused. MES refuses only after the game has accepted, and says so only in chat (GVK-Settings#762), so the title is what tells the player. Claim stays hidden outside the Territory, while a Base stands, during the kill lock and while a claim is pending.
- **Turret placement.** The order starts the 15 s placing window, and the cooldown starts only when the Turret reports in. MES runs behaviors every tick, so a placed Turret reports within seconds. If no Turret reports, the window ends with a chat line, and the contract opens again with no cooldown. The spawner tries one random spot 300-500 m from the Base, and MES checks the spawn conditions at that spot only. Defense Turrets keep 75 m from every grid with the RC code `GVK-Alliance-Encounter`, which includes the Base's other Turrets. In testing on 2026-11-08, most second to fourth Turrets failed to place at the old 600 m, and the fourth still failed often at 150 m.
- **Turret roll call.** Every minute the Base Site asks its Base to call its Turrets (`MatchReceiverChild`). Each Turret answers through the Base, and 5 s later the count is set to the number of answers. So a Turret that vanishes without a report, such as one an admin deletes, frees its slot within a minute (tested 2026-11-08: before the roll call, the slot never freed). The count is set only if the Base answered, because a Base that isn't loaded can't count its Turrets. Spawn and loss reports still change the count straight away.
- **The hostile band ends at -1, not 0.** MES drops `0` from integer lists, so a player condition with `[MaxPlayerReputation:0]` has uneven lists and never passes. Before this fix, the hostile-player rule never hid a board.
- **Cooldowns are Timer triggers restarted** with `ResetCooldownTimeOfTriggers` by the action that starts them. Each one clears its flag when it fires.
- **The Base reports to its Base Site** by radius (1100 m; sites are 7.9 km apart at minimum). It sends `BaseUp` on spawn and every 5 minutes, `BaseKilled` from the defeat chain and `BaseGone` from `DespawnMES`. A Base Site that hears nothing for 15 minutes clears its Base flag but keeps the Turret count and cooldowns, so a concealed Base does not reset them. Every command between a Base and its Base Site sets `[MatchSenderReceiverOwners:false]`. MES drops a grid's command when the receiver has a different owner (the default is `true`), and the Base Site is owned by UNKN while the Base belongs to its alliance. Commands sent by the board's contract event skip that check.
- **Defense Turrets report to their parent Base** (`MatchReceiverParent`), which relays to the Base Site. Lone Encounter Turrets share the Turret behavior but have no parent Base, so their reports reach no one. The Base despawns its Turrets (`MatchReceiverChild`) when it is killed or despawned. They despawn as a rule despawn, so they cost no Influence.
- **Placement:** `ForceExactPositionAndOrientation` puts the grid origin on `StaticEncounterCoords` and lines grid +Y up with `StaticEncounterUp`. The Base Site is built with its up along grid -Y, like the KOTH trade station it came from: its functional blocks face grid Down. So its `StaticEncounterUp` points at the planet center. Its foundation's base is 6.25 m below the origin, so each spawn group puts the origin 6.25 m below its site's GPS point and the base sits on the point. With the origin on the point, the grid stood about 6 m off the ground.
- **One live Base per site** is still enforced by the spawn conditions' RC code gate: `[RemoteControlCode:GVK-Alliance-Base]` with `[RemoteControlCodeMinDistance:1100]`. The gate must stay above `2 x` the spawner `MaxDistance` (500), or a redeploy can land outside it.

### Influence
- **Claim:** +50 to the Base's alliance once, guarded by a local boolean, because Session triggers fire on every load.
- **Kill:** the existing rule (-50 to the owner, +50 to the rival) applies when an enemy or neutral player damaged the Base. Any other kill now costs the owner 50 too, which closes the claim-and-kill farm.
- **Despawns:** the abandon rule (`GVK-Alliance-TriggerGroup-InsideOutsideZone`) and other rule despawns cost nothing and start no lock.

### Limits to test in game
- The Base Site's foundation is wider than the old tower's: check at a site or two that it sits on the ground, not buried or floating on a slope.
- A defeated Base wreck may keep its RC code and block a re-claim at its site until the wreck is cleaned up.
- The roll call counts only loaded Turrets. If the Base is loaded but some of its Turrets are concealed, the count drops until they load again.
- Restore brings back a sieged shield only with GVK_SiegeableSafeZones_NPC 33d7711 or later. That build restores a sieged NPC shield when an NPC switches its block back on; older builds switch it off again.
