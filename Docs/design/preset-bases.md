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
| Claim Base Site | Friendly (reputation 500+) with the alliance, standing in its Territory | Spawns the Base; the Base adds 50 Influence once | No Base at the site, no kill lock |
| Deploy Defense Turret | Friendly with the Base's alliance | The Base spawns one Turret 300-500 m out | One per 20 min, 4 standing |
| Restore Base | Friendly with the Base's alliance | Repairs damaged blocks on the Base and its subgrids, switches its shield block on | One per 2 h |

No contract shows while a player hostile to that alliance (reputation 0 or below) is within 5 km.

### How it is built
- **Files:** the missions and board profiles are in `GVK-Alliance-PresetBases-Contracts.sbc`, the Base Site in `GVK-Alliance-PresetBases-Site-Behavior.sbc`, and the Base and Turret side in `GVK-Alliance-PresetBases-BaseSite.sbc`. [tools/New-BaseSiteBoard.py](../../tools/New-BaseSiteBoard.py) generates all three, so edit the script and re-run it rather than hand-editing the 20 board rules.
- **One mission set serves all 22 sites.** The mission's event action broadcasts the command from `{ContractBlockLocation}` with a 150 m radius, and `{BoardCode}` (a mission `ReplaceKeys` value) names the contract. `[TryContractSuccess:true]` ends the contract and removes its event instance.
- **The Base Site keeps its own state** in local booleans and a counter. These are which alliance's Base stands there, a 2 h kill lock, a 120 s claim-pending window, the Turret and Restore cooldowns, the standing Turret count, and a hostile-near flag per alliance. Each change fires the board's refresh tag. Exactly one of 20 refresh rules matches each state and re-applies its board profile with `ClearContractContentsFirst`. A Session trigger and a 10-minute timer also refresh the board.
- **Cooldowns are Timer triggers restarted** with `ResetCooldownTimeOfTriggers` by the action that starts them. Each one clears its flag when it fires.
- **The Base reports to its Base Site** by radius (1100 m; sites are 7.9 km apart at minimum). It sends `BaseUp` on spawn and every 5 minutes, `BaseKilled` from the defeat chain and `BaseGone` from `DespawnMES`. A Base Site that hears nothing for 15 minutes clears its Base flag but keeps the Turret count and cooldowns, so a concealed Base does not reset them.
- **Defense Turrets report to their parent Base** (`MatchReceiverParent`), which relays to the Base Site. Lone Encounter Turrets share the Turret behavior but have no parent Base, so their reports reach no one. The Base despawns its Turrets (`MatchReceiverChild`) when it is killed or despawned. They despawn as a rule despawn, so they cost no Influence.
- **Placement:** each spawn group puts the grid at its site's GPS point raised 7.5 m along Up, because the Base Site's floor is 3 blocks below the grid origin. The 22 Up vectors meet at the planet center, so Up points away from the ground.
- **One live Base per site** is still enforced by the spawn conditions' RC code gate: `[RemoteControlCode:GVK-Alliance-Base]` with `[RemoteControlCodeMinDistance:1100]`. The gate must stay above `2 x` the spawner `MaxDistance` (500), or a redeploy can land outside it.

### Influence
- **Claim:** +50 to the Base's alliance once, guarded by a local boolean, because Session triggers fire on every load.
- **Kill:** the existing rule (-50 to the owner, +50 to the rival) applies when an enemy or neutral player damaged the Base. Any other kill now costs the owner 50 too, which closes the claim-and-kill farm.
- **Despawns:** the abandon rule (`GVK-Alliance-TriggerGroup-InsideOutsideZone`) and other rule despawns cost nothing and start no lock.

### Limits to test in game
- The 7.5 m raise is an estimate from the block layout: check that the floor sits on the ground at a site or two.
- A defeated Base wreck may keep its RC code and block a re-claim at its site until the wreck is cleaned up.
- A Turret that fails to find a spawn position still uses the 20-minute cooldown.
- Restore brings back a sieged shield only with GVK_SiegeableSafeZones_NPC 33d7711 or later. That build restores a sieged NPC shield when an NPC switches its block back on; older builds switch it off again.
