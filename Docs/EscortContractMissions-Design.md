# Escort Contract Missions: Remaining Work

Player-accepted escort missions for Coalition convoy Routes A, B and E, built entirely in SBC
with MES Missions (no C#). Issue: [#480](https://github.com/GV-Server-Mods/GVK-Settings/issues/480).

Files: `Content/Data/Encounters/Convoy/Contracts/` (Board, Missions, EventTemplates, Signals),
plus the convoy behaviors under `Encounters/PlanetaryCargoShip/`. The board is published by
`GVK-EscortContracts-Trigger-RefreshBoard` on `GVK-Static-TradeStation-Behavior`, onto the
"NPC Contracts" block of `NTS [COAL] Base`.

## Still to build
- [ ] **Route A single vs. double escort**: offer both the single and the double-escort
      variant of Route A as separate missions (`GVK-EscortMissions-Missions.sbc`).
- [ ] **Consolidate Signals and EventTemplates**: the per-route conditions and actions are split
      between `GVK-EscortMissions-Signals.sbc` and `GVK-EscortMissions-EventTemplates.sbc`;
      merge them into one place per route.
- [ ] **Decide: one escort at a time?** Routes A, B and E can currently run at the same time.
      If only one should run, add a shared `[PersistantEventConditionIds:]` gate to the missions.
- [ ] **Decide: must the escort cruisers survive?** Success currently requires only the
      transport to arrive; Route A's two escort cruisers can be lost without failing the contract.
- [ ] **KHAANEPH / SOBAN routes (future)**: add missions, template groups and a contract block
      on their bases; reputation reward/penalty fields become relevant for those factions.
- [ ] **Optional: success-gated loot**: payout is still the shared MES route-complete loot spawn.
      Tying loot to contract success would need a small script (`IMyInventory.AddItems` on success).

## Still to confirm in game
- [ ] Mid-escort server restart: the contract and convoy both survive and can still be completed.
- [ ] Transport destroyed or despawned: the contract fails (watchdog included), and no loss
      signal fires after a successful delivery.
- [ ] With no active contract, the board re-offers completed routes within 10 minutes.

## Known MES limitations
- `MinContracts` / `MaxContracts` on `[MES Contract Block]` are parsed but ignored by MES.
- `[EventConditionIds:]` on `[MES Mission]` is ignored (see TODO.md, Upstream MES Bugs); use
  `[PersistantEventConditionIds:]` for mission gates.
