# MES upstream drafts

Fork: `%AppData%\SpaceEngineers\Mods\Modular-Encounters-Systems` (origin = GV-Server-Mods, upstream = MeridiusIX). Branches are based on upstream/master `537c875`, compile-checked, not yet tested in-game or pushed.

Permalink base: `https://github.com/MeridiusIX/Modular-Encounters-Systems/blob/537c875f574f5fb305451a62ab20044323ce4296/Data/Scripts/ModularEncountersSystems/`

---

## PR 1: `fix/sharemode-all-index`

**Title:** Fix ChangeBlocksShareModeAll using wrong loop index

The inner block loop in ActionSystem.cs reads `grid.AllTerminalBlocks[i]` (the LinkedGrids index) instead of `[j]`. The named blocks never get changed, and it can throw IndexOutOfRange when a grid has fewer terminal blocks than the grid index.

---

## PR 2: `fix/known-player-locations`

**Title:** Fix Known Player Location bugs

- `ZoneManager.Setup` removes saved zones with no ProfileSubtypeId. KPLs never have one, so every KPL is deleted on world load.
- `CleanExpiredLocations` checks `MinutesToExpiration` without checking `UseZoneTimer`. A KPL with no timer (-1) keeps the default 60 and expires after an hour.
- `TimerChecks` removes expired zones without logging anything.
- `MergeExistingKnownPlayerLocation` normalizes the vector between the two centers, so a KPL created at the same position as an existing one gets NaN coords and radius.
- `MergeVariablesFromOldLocation` adds the new zone's values instead of the old zone's, so merged KPLs lose their bools/counters.
- `ZoneCustomBoolChangeUseKPL` / `ZoneCustomCounterChangeUseKPL` are inverted (true changes named zones, false changes KPLs). `ChangeKPLBools` / `ChangeKPLCounters` also skip the KPLs that contain the grid instead of the ones that don't.

Note: with the UseKPL fix, bool/counter changes without `UseKPL:true` now go to named zones.

---

## PR 3: `fix/tag-parsing`

**Title:** Fix tags that are never parsed

- `TagCheckEnumCheck` (GridDestructible, SubGridsDestructible, GridEditable, SubGridsEditable, IsStatic) is case-sensitive and silently keeps Ignore on a bad value, so `true`/`false` do nothing. It now accepts true/false, ignores case, and logs bad values.
- `EscortUsesRelativeDampening`, `EscortSpeedMatchMinDistance` and `EscortSpeedMatchMaxDistance` are used in Escort.cs but had no parser. Added them, plus wiki entries.
- Spawner `StartsReady` is on the wiki but had no parser.
- Mission.cs builds the event conditions from `PlayerConditionIds` instead of `EventConditionIds`.

---

## Issue 1: KPL resize

**Title:** No way to resize a Known Player Location

`ZoneRadiusChangeType` (and the event `ZoneRadiusChangeTypes`) go through `ZoneManager.ChangeZoneRadius`, which only changes persistent zones matched by PublicName, so KPLs can't be resized.

`KnownPlayerLocationManager.ChangeZoneSizeAtLocation` looks like it was meant for this, but nothing calls it (MESApi only declares `_changeKnownPlayerLocationSize`). Its position check is also inverted (it resizes every zone that does *not* contain the position, not only KPLs), and it doesn't refresh the cached `Zone.Sphere`.

Could we get an action to grow/shrink the KPL at the grid's position? I can PR it.

---

## Issue 2: parent commands

**Title:** CommandCheckFromParent matches owner, not the parent grid

The spawner sets `ParentId = RemoteControl.OwnerId` (ActionSystem.cs:403) and `CommandCheckFromParent` compares that to the command's owner id (ConditionProfile.cs:1746). Any grid with the same owner counts as the parent. `SingleRecipient` commands go to the first listener that processes them (TriggerSystem.cs:763), not the parent.

With several same-faction structures in range, a spawned drone can't send a command to only the grid that spawned it.

Could the parent RC entity id be stored in NpcData, with a command option to send to the parent only? I can PR it.

---

## Issue 3: unused tags

**Title:** Tags that are parsed but never used

- Zone `PlayerPresenceResetsTimer` is parsed but never read. `TimerChecks` resets the timer of every timed zone with a player inside.
- Store `ItemsRequireInventory` is declared in StoreProfile.cs but never parsed or used.

Should these be implemented or removed?

---

## PR 4: `fix/weaponcore-range-desync`

**Title:** Fix WeaponCore range setting and shield damage detection

Fixes #332

**0m ranges (#332)**
`SetWeaponCoreRandomRanges` stored the first `GetMaxWeaponRange` result for each block type in `DefaultRangeWC` and reused it for every later block of that type. WC's `GetMaxWeaponRange` returns 0 until the weapon's platform is Ready, which often isn't the case right after a spawn. If the first read happened too early, 0 was cached, and every weapon of that type spawned after it was set to 0m until restart. That's why it looked random and why the same turret worked fine on other NPCs.

MES doesn't need the max range here. WC's `SetBlockTrackingRange` already clamps the value to the weapon's max (smaller of hardpoint MaxTargetDistance and active ammo MaxTrajectory). So it now passes 800 for the normal range and `float.MaxValue` for max range, and WC works out the real number. `DefaultRangeWC` is removed since nothing else used it.

**Each weapon set multiple times**
It looped over every grid in `LinkedGrids` and called `GetBlocksOfType` for each one, but `GetBlocksOfType` already returns blocks from the whole construct. A grid with 12 subgrids set every weapon 13 times (the repeated log lines in #332). Now it gets the blocks once.

**Subgrid vanilla turrets never changed**
`SetAutomatedWeaponRanges` loops `LinkedGrids` but uses `this.Turrets` inside the loop instead of `grid.Turrets`. Main grid turrets got set once per subgrid and turrets on rotors/pistons were never touched.

**Shield damage never detected**
`GridDamageWatcher.ShieldValidator` (and the copy in `WeaponRandomizedGrids`) loops with `i > _lastAttackers.Count`, so the loop body never runs. Player damage absorbed by a DefenseShields shield never switched the NPC to max range or set ReceivedPlayerDamage.

---

## Not ready

- **Grid targeting needs a player nearby**: not traced in source yet.
