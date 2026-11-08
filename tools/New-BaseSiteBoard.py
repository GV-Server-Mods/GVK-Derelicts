"""Generate the Base Site contract board (GVK-Settings#653): the Base Site behavior, the contracts, and the Base and
Defense Turret triggers. Edit this script and re-run it instead of editing the three generated files by hand.

Usage (from the repo root): python tools/New-BaseSiteBoard.py [--test-cooldown SECONDS]
Writes Content/Data/Encounters/Alliance/PresetBases/GVK-Alliance-PresetBases-{Site-Behavior,Contracts,BaseSite}.sbc
as UTF-8 (no BOM) with CRLF line endings. Design: Docs/design/preset-bases.md.
--test-cooldown sets the Turret and Restore cooldowns to SECONDS and marks the contracts as a test build. Run it only in
a throwaway worktree for an in-game test, never on the files you commit.
"""
import argparse
from pathlib import Path

ARGS = argparse.ArgumentParser()
ARGS.add_argument("--test-cooldown", type=int, metavar="SECONDS")
TEST_COOLDOWN = ARGS.parse_args().test_cooldown
TURRET_COOL_MS = TEST_COOLDOWN * 1000 if TEST_COOLDOWN else 1200000
RESTORE_COOL_MS = TEST_COOLDOWN * 1000 if TEST_COOLDOWN else 7200000

ROOT = Path(__file__).resolve().parents[1]
PB = ROOT / "Content/Data/Encounters/Alliance/PresetBases"
F = ["SOBAN", "KHAANEPH"]
P = "GVK-Alliance-PresetBases"

def comp(subtype, body, comment=None):
    out = []
    if comment:
        out.append(f"\t\t<!-- {comment} -->")
    out.append('\t\t<EntityComponent xsi:type="MyObjectBuilder_InventoryComponentDefinition">')
    out.append("\t\t\t<Id>")
    out.append("\t\t\t\t<TypeId>Inventory</TypeId>")
    out.append(f"\t\t\t\t<SubtypeId>{subtype}</SubtypeId>")
    out.append("\t\t\t</Id>")
    out.append("\t\t\t<Description>")
    for line in body:
        out.append("\t\t\t\t" + line)
    out.append("\t\t\t</Description>")
    out.append("\t\t</EntityComponent>")
    return "\n".join(out)

def section(title):
    bar = "=" * 51
    return f"\t\t<!-- {bar} -->\n\t\t<!-- {title.ljust(51)} -->\n\t\t<!-- {bar} -->"

def doc(header, parts):
    head = '<?xml version="1.0"?>\n<Definitions xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">\n\t<EntityComponents>\n'
    head += header + "\n"
    tail = "\n\t</EntityComponents>\n</Definitions>\n"
    return head + "\n\n".join(parts) + tail

def write(path, text):
    path.write_bytes(text.replace("\r\n", "\n").replace("\n", "\r\n").encode("utf-8"))

def trig(subtype, ttype, actions, conditions=None, extra=(), tags=(), starts_ready=True, cooldown=None):
    body = ["[RivalAI Trigger]", "[UseTrigger:true]", f"[Type:{ttype}]"]
    body += [f"[Tags:{t}]" for t in tags]
    body.append(f"[StartsReady:{'true' if starts_ready else 'false'}]")
    if cooldown is not None:
        body += [f"[MinCooldownMs:{cooldown}]", f"[MaxCooldownMs:{cooldown + 1}]"]
    body += list(extra)
    body.append("[MaxActions:-1]")
    if conditions:
        body.append(f"[Conditions:{conditions}]")
    body.append("[ActionExecution:All]")
    body += [f"[Actions:{a}]" for a in actions]
    return comp(subtype, body)

def cond(subtype, true=(), false=(), counters=(), any_true=False):
    body = ["[RivalAI Condition]", "[UseConditions:true]", "[MatchAnyCondition:false]"]
    if true:
        body.append("[CheckTrueBooleans:true]")
        body += [f"[TrueBooleans:{b}]" for b in true]
        if any_true:
            body.append("[AllowAnyTrueBoolean:true]")
    if false:
        body.append("[CheckFalseBooleans:true]")
        body += [f"[FalseBooleans:{b}]" for b in false]
    if counters:
        body.append("[CheckCustomCounters:true]")
        for name, target, cmp in counters:
            body += [f"[CustomCounters:{name}]", f"[CustomCountersTargets:{target}]", f"[CounterCompareTypes:{cmp}]"]
    return comp(subtype, body)

def action(subtype, lines, refresh=False):
    body = ["[RivalAI Action]"] + list(lines)
    if refresh:
        body += ["[ManuallyActivateTrigger:true]", f"[ManuallyActivatedTriggerTags:{P}-TriggerTags-RefreshBoard]"]
    return comp(subtype, body)

def command(subtype, code, radius, extra=(), cross_owner=False):
    # MES drops a grid's command when the receiver's owner differs (MatchSenderReceiverOwners defaults to true).
    # The Base Site is owned by UNKN and the Base by its alliance, so commands between them must turn it off.
    body = ["[RivalAI Command]", f"[CommandCode:{code}]"] + list(extra)
    if cross_owner:
        body.append("[MatchSenderReceiverOwners:false]")
    body += [
        "[IgnoreAntennaRequirement:true]", "[IgnoreReceiverAntennaRequirement:true]",
        f"[Radius:{radius}]", "[CommandDelayTicks:0]"]
    return comp(subtype, body)

# Local state on the Base Site (RivalAI booleans and counters, saved with the grid)
BASE = {f: f"GVK_Site_Base_{f}" for f in F}
HOST = {f: f"GVK_Site_HostileNear_{f}" for f in F}
TERR = {f: f"GVK_Site_InTerritory_{f}" for f in F}
LOCK, PEND = "GVK_Site_KillLock", "GVK_Site_ClaimPending"
TCOOL, RCOOL, TCOUNT = "GVK_Site_TurretCooling", "GVK_Site_RestoreCooling", "GVK_Site_Turrets"
TPEND = "GVK_Site_TurretPending"
ROLL, ROLLACK, TALLY = "GVK_Site_TurretRollCall", "GVK_Site_TurretRollCallAck", "GVK_Site_TurretTally"
TURRET_CAP = 4
RESET_STATE = [f"[SetBooleansFalse:{BASE['SOBAN']}]", f"[SetBooleansFalse:{BASE['KHAANEPH']}]",
               f"[SetBooleansFalse:{TCOOL}]", f"[SetBooleansFalse:{RCOOL}]", f"[SetBooleansFalse:{TPEND}]",
               f"[ResetCounters:{TCOUNT}]"]

# ---------------------------------------------------------------- contracts file
c = []
c.append(section("PLAYER CONDITIONS"))
for f in F:
    c.append(comp(f"{P}-PlayerCondition-Friendly{f}", [
        "[MES Player Condition]", "[CheckPlayerReputation:true]", f"[CheckReputationwithFaction:{f}]",
        "[MinPlayerReputation:500]", "[MaxPlayerReputation:1500]"],
        f"Friendly standing with {f}: the only players who can accept its contracts"))
    # MES drops 0 from integer lists, so a 0 maximum leaves the lists uneven and the condition never passes: -1 is the cap.
    c.append(comp(f"{P}-PlayerCondition-Hostile{f}", [
        "[MES Player Condition]", "[CheckPlayerReputation:true]", f"[CheckReputationwithFaction:{f}]",
        "[MinPlayerReputation:-1500]", "[MaxPlayerReputation:-1]"],
        f"Hostile to {f} (reputation below 0): blocks {f} contracts within 5 km"))
# No player carries this tag, so a stand-in contract is always refused. MES refuses after the game accepts and says so
# only in chat (GVK-Settings#762), so the stand-in's title carries the reason.
c.append(comp(f"{P}-PlayerCondition-Never", [
    "[MES Player Condition]", "[CheckPlayerTags:true]", "[IncludedPlayerTags:GVK-BaseSite-StandIn]"],
    "Nobody passes: the condition for stand-in contracts"))

c.append(section("MISSIONS (free: no reward, no collateral)"))
TEST_NOTE = f" TEST BUILD: {TEST_COOLDOWN} s cooldowns." if TEST_COOLDOWN else ""
MISSIONS = {
    "Claim": ("Claim Base Site", "Deploy a {f} Base at this site. Open to players in Friendly standing with {f}, while this site is inside {f} territory. Adds 50 Influence to {f}."),
    "Turret": ("Deploy Defense Turret", "Places one {f} Defense Turret around the Base at this site. One every 20 minutes, counted from when the last one was placed, up to 4 standing."),
    "Restore": ("Restore Base", "Repairs every damaged block on the {f} Base at this site. Destroyed blocks are not rebuilt. Once every 2 hours."),
}
HOSTILE = ("hostile player nearby", "Unavailable while a player hostile to {f} is within 5 km of this site.")
# Stand-ins: shown in place of a contract the site's state blocks. (name, contract, title suffix, description)
STANDINS = [
    ("ClaimHostile", "Claim") + HOSTILE,
    ("TurretHostile", "Turret") + HOSTILE,
    ("TurretDeploying", "Turret", "deploying", "A Defense Turret is being placed. If no spot is found, this contract opens again within a minute."),
    ("TurretAtCap", "Turret", f"{TURRET_CAP} of {TURRET_CAP} standing", f"This Base already has {TURRET_CAP} Defense Turrets. A slot opens within a minute of one being destroyed or removed."),
    ("TurretCooling", "Turret", "cooling down", "One Defense Turret every 20 minutes, counted from when the last one was placed."),
    ("RestoreHostile", "Restore") + HOSTILE,
    ("RestoreCooling", "Restore", "cooling down", "Once every 2 hours."),
]
def mission(subtype, title, desc, lead, code):
    return comp(subtype, [
        "[MES Mission]", "[MissionType:Custom]", f"[Title:{title}]", f"[Description:{desc}{TEST_NOTE}]",
        "[Reward:0]", "[Collateral:0]", "[ReputationReward:0]", "[FailReputationPrice:0]",
        f"[OverrideFaction:{lead[1]}]", "[SoloMission:true]", f"[LeadPlayerConditionIds:{lead[0]}]",
        f"[InstanceEventGroupId:{P}-TemplateGroup-Contract]", "[ReplaceKeys:{BoardCode}]", f"[ReplaceValues:{code}]"])
for kind, (title, desc) in MISSIONS.items():
    for f in F:
        # No player-in-territory check: the board only shows Claim while the site is inside the Territory and the player
        # stands at the board, so a second check on the player can only refuse someone who qualifies.
        c.append(mission(f"{P}-Mission-{kind}-{f}", f"{title} - {f}", desc.format(f=f),
                         (f"{P}-PlayerCondition-Friendly{f}", f), f"GVK-BaseSite-Board-{kind}-{f}"))
for name, kind, suffix, desc in STANDINS:
    for f in F:
        c.append(mission(f"{P}-Mission-{name}-{f}", f"{MISSIONS[kind][0]} - {f} ({suffix})",
                         desc.format(f=f) + " This contract can't be accepted.", (f"{P}-PlayerCondition-Never", f),
                         "GVK-BaseSite-Board-StandIn"))

# Board states: exactly one refresh rule matches each state, and each rule lists the contracts its board shows.
def m(name, f):
    return f"{P}-Mission-{name}-{f}"
below_cap = [(TCOUNT, TURRET_CAP, "Less")]
at_cap = [(TCOUNT, TURRET_CAP, "GreaterOrEqual")]
refresh_rules = [  # (name, true, false, counters, missions)
    ("Locked", [LOCK], [BASE["SOBAN"], BASE["KHAANEPH"]], [], []),
    ("Pending", [PEND], [BASE["SOBAN"], BASE["KHAANEPH"], LOCK], [], []),
]
# No Base, no lock, nothing pending. Per alliance the site is outside its Territory (no Claim), inside it (Claim), or
# inside it with a hostile player near (stand-in), so 3 x 3 rules cover every case.
def claim_state(f, state):
    return {"Open": ([TERR[f]], [HOST[f]], [m("Claim", f)]), "Out": ([], [TERR[f]], []),
            "Hostile": ([TERR[f], HOST[f]], [], [m("ClaimHostile", f)])}[state]
for s_state in ["Open", "Out", "Hostile"]:
    for k_state in ["Open", "Out", "Hostile"]:
        (st, sf, sm), (kt, kf, km) = claim_state("SOBAN", s_state), claim_state("KHAANEPH", k_state)
        refresh_rules.append((f"Claim-SOBAN{s_state}-KHAANEPH{k_state}", st + kt,
                              [BASE["SOBAN"], BASE["KHAANEPH"], LOCK, PEND] + sf + kf, [], sm + km))
# A Base stands. The Turret contract is deploying, at the cap, cooling down or open (checked in that order), and Restore
# is cooling down or open: 4 x 2 rules, plus one for a hostile player near.
TURRET_STATES = [("Deploying", [TPEND], [], [], "TurretDeploying"), ("AtCap", [], [TPEND], at_cap, "TurretAtCap"),
                 ("Cooling", [TCOOL], [TPEND], below_cap, "TurretCooling"), ("Open", [], [TPEND, TCOOL], below_cap, "Turret")]
RESTORE_STATES = [("Cooling", [RCOOL], [], "RestoreCooling"), ("Open", [], [RCOOL], "Restore")]
for f in F:
    b, h = BASE[f], HOST[f]
    refresh_rules.append((f"{f}-Hostile", [b, h], [], [], [m("TurretHostile", f), m("RestoreHostile", f)]))
    for ts, tt, tf, tc, tm in TURRET_STATES:
        for rs, rt, rf, rm in RESTORE_STATES:
            refresh_rules.append((f"{f}-Turret{ts}-Restore{rs}", [b] + tt + rt, [h] + tf + rf, tc, [m(tm, f), m(rm, f)]))
BOARDS = {}
for i, (name, true, false, counters, missions) in enumerate(refresh_rules):
    board = "_".join(x[len(f"{P}-Mission-"):] for x in missions) or "Empty"
    BOARDS[board] = missions
    refresh_rules[i] = (name, true, false, counters, board)

c.append(section("CONTRACT BLOCK PROFILES (one per board state)"))
for name, ids in BOARDS.items():
    c.append(comp(f"{P}-Board-{name}", ["[MES Contract Block]"] + [f"[MissionIds:{i}]" for i in ids]))

c.append(section("ACCEPTED CONTRACT: TELL THE BASE SITE, THEN SUCCEED"))
c.append(comp(f"{P}-TemplateGroup-Contract", ["[MES Event TemplateGroup]", f"[TemplateEventIds:{P}-EventTemplate-Contract]"]))
c.append(comp(f"{P}-EventTemplate-Contract", [
    "[MES Event Template]", "[UseEvent:true]", "[UniqueEvent:true]", "[StartsReady:true]",
    "[MinCooldownMs:0]", "[MaxCooldownMs:1]", "[ActionExecution:All]",
    f"[ActionIds:{P}-EventActionTemplate-Contract]"]))
c.append(comp(f"{P}-EventActionTemplate-Contract", [
    "[MES Event Action Template]", "[BroadcastCommandProfiles:true]",
    f"[CommandProfileIds:{P}-Command-Board]", "[CommandProfileOriginCoords:{ContractBlockLocation}]",
    "[OverrideCommandCode:{BoardCode}]", "[TryContractSuccess:true]"],
    "{ContractBlockLocation} is the board's position, so only that site's Base Site hears it"))
c.append(command(f"{P}-Command-Board", "GVK-BaseSite-Board", 150))

header = """\t\t<!--
\t\tAlliance Base Site contract board (GVK-Settings#653).
\t\tThe Base Site's contract block (named "NPC Contracts") shows free contracts: Claim Base Site, Deploy Defense Turret and
\t\tRestore Base. Accepting one sends a command to that Base Site, which does the work and keeps the site's state; the
\t\tcontract then succeeds. The Base Site picks which board profile to show (GVK-Alliance-PresetBases-Site-Behavior.sbc).
\t\tDesign and reasons: Docs/design/preset-bases.md.
\t\t-->"""
write(PB / "GVK-Alliance-PresetBases-Contracts.sbc", doc(header, c))

# ---------------------------------------------------------------- Base Site behavior file
t = []
t.append(section("BASE SITE BEHAVIOR"))
TALLY_MAX = TURRET_CAP + 2
triggers = ["Session", "PeriodicRefresh", "BaseKilled", "BaseGone", "BaseWatchdog", "TurretUp", "TurretUpPending",
            "TurretLost", "TurretUpTally", "TurretLostTally", "TurretRollCall", "TurretRollCallAck", "TurretHere",
            "TurretRollCallEnd", "LockEnd", "ClaimPendingEnd", "TurretPendingEnd", "TurretCoolEnd", "RestoreCoolEnd"]
triggers += [f"TurretTally-{n}" for n in range(TALLY_MAX + 1)]
for f in F:
    triggers += [f"Claim-{f}", f"Turret-{f}", f"Restore-{f}", f"BaseUp-{f}", f"BaseAlive-{f}",
                 f"HostileArrived-{f}", f"HostileStillNear-{f}", f"HostileClear-{f}",
                 f"EnterTerritory-{f}", f"LeaveTerritory-{f}"]
    triggers += [f"BoardUsed-{kind}-{f}" for kind in MISSIONS]
for r in refresh_rules:
    triggers.append(f"Refresh-{r[0]}")
t.append(comp(f"{P}-Site-Behavior", [
    "[MES AI Behavior]", "[BehaviorName:Passive]", "[UseRetreatTimer:false]", "[UseNoTargetTimer:false]",
    "[UsePlayerDistanceTimer:false]"] + [f"[Triggers:{P}-Site-Trigger-{x}]" for x in triggers]))

t.append(section("CONTRACTS ACCEPTED ON THIS BASE SITE'S BOARD"))
for f in F:
    other = "KHAANEPH" if f == "SOBAN" else "SOBAN"
    t.append(trig(f"{P}-Site-Trigger-Claim-{f}", "CommandReceived", [f"{P}-Site-Action-Claim-{f}"],
                  f"{P}-Site-Condition-CanClaim-{f}", [f"[CommandReceiveCode:GVK-BaseSite-Board-Claim-{f}]"]))
    t.append(cond(f"{P}-Site-Condition-CanClaim-{f}", [], [BASE[f], BASE[other], LOCK, PEND, HOST[f]]))
    t.append(action(f"{P}-Site-Action-Claim-{f}", [
        "[SpawnEncounter:true]", f"[Spawner:{P}-Spawner-Base-{f}]", f"[SetBooleansTrue:{PEND}]",
        f"[SetBooleansFalse:{TCOOL}]", f"[SetBooleansFalse:{RCOOL}]", f"[ResetCounters:{TCOUNT}]",
        "[ResetCooldownTimeOfTriggers:true]", f"[ResetTriggerCooldownNames:{P}-Site-Trigger-ClaimPendingEnd]"], refresh=True))
    t.append(trig(f"{P}-Site-Trigger-Turret-{f}", "CommandReceived", [f"{P}-Site-Action-Turret"],
                  f"{P}-Site-Condition-CanTurret-{f}", [f"[CommandReceiveCode:GVK-BaseSite-Board-Turret-{f}]"]))
    t.append(cond(f"{P}-Site-Condition-CanTurret-{f}", [BASE[f]], [HOST[f], TCOOL, TPEND], below_cap))
    t.append(trig(f"{P}-Site-Trigger-Restore-{f}", "CommandReceived", [f"{P}-Site-Action-Restore"],
                  f"{P}-Site-Condition-CanRestore-{f}", [f"[CommandReceiveCode:GVK-BaseSite-Board-Restore-{f}]"]))
    t.append(cond(f"{P}-Site-Condition-CanRestore-{f}", [BASE[f]], [HOST[f], RCOOL]))
for f in F:
    for kind in MISSIONS:
        t.append(trig(f"{P}-Site-Trigger-BoardUsed-{kind}-{f}", "CommandReceived", [f"{P}-Site-Action-Refresh"],
                      extra=[f"[CommandReceiveCode:GVK-BaseSite-Board-{kind}-{f}]"]))
# The cooldown starts when the Turret reports in (TurretUpPending), so a spawn that finds no spot costs nothing.
t.append(action(f"{P}-Site-Action-Turret", [
    "[BroadcastCommandProfiles:true]", f"[CommandProfileIds:{P}-Command-SpawnDefenseTurret]", f"[SetBooleansTrue:{TPEND}]",
    "[ResetCooldownTimeOfTriggers:true]", f"[ResetTriggerCooldownNames:{P}-Site-Trigger-TurretPendingEnd]"], refresh=True))
t.append(action(f"{P}-Site-Action-Restore", [
    "[BroadcastCommandProfiles:true]", f"[CommandProfileIds:{P}-Command-RestoreBase]", f"[SetBooleansTrue:{RCOOL}]",
    "[ResetCooldownTimeOfTriggers:true]", f"[ResetTriggerCooldownNames:{P}-Site-Trigger-RestoreCoolEnd]"], refresh=True))
t.append(command(f"{P}-Command-SpawnDefenseTurret", "GVK-BaseSite-SpawnDefenseTurret", 1100, cross_owner=True))
t.append(command(f"{P}-Command-RestoreBase", "GVK-BaseSite-RestoreBase", 1100, cross_owner=True))

t.append(section("REPORTS FROM THIS SITE'S BASE"))
for f in F:
    other = "KHAANEPH" if f == "SOBAN" else "SOBAN"
    t.append(trig(f"{P}-Site-Trigger-BaseUp-{f}", "CommandReceived", [f"{P}-Site-Action-BaseUp-{f}"],
                  f"{P}-Site-Condition-NewBase-{f}", [f"[CommandReceiveCode:GVK-BaseSite-BaseUp-{f}]"]))
    t.append(cond(f"{P}-Site-Condition-NewBase-{f}", [], [BASE[f], LOCK]))
    t.append(action(f"{P}-Site-Action-BaseUp-{f}", [
        f"[SetBooleansTrue:{BASE[f]}]", f"[SetBooleansFalse:{BASE[other]}]", f"[SetBooleansFalse:{PEND}]"], refresh=True))
    t.append(trig(f"{P}-Site-Trigger-BaseAlive-{f}", "CommandReceived", [f"{P}-Site-Action-BaseAlive"],
                  extra=[f"[CommandReceiveCode:GVK-BaseSite-BaseUp-{f}]"]))
t.append(action(f"{P}-Site-Action-BaseAlive", [
    "[ResetCooldownTimeOfTriggers:true]", f"[ResetTriggerCooldownNames:{P}-Site-Trigger-BaseWatchdog]"]))
t.append(trig(f"{P}-Site-Trigger-BaseKilled", "CommandReceived", [f"{P}-Site-Action-BaseKilled"],
              extra=["[CommandReceiveCode:GVK-BaseSite-BaseKilled]"]))
t.append(action(f"{P}-Site-Action-BaseKilled", RESET_STATE + [
    f"[SetBooleansTrue:{LOCK}]", "[ResetCooldownTimeOfTriggers:true]",
    f"[ResetTriggerCooldownNames:{P}-Site-Trigger-LockEnd]"], refresh=True))
t.append(trig(f"{P}-Site-Trigger-BaseGone", "CommandReceived", [f"{P}-Site-Action-BaseGone"],
              extra=["[CommandReceiveCode:GVK-BaseSite-BaseGone]"]))
t.append(action(f"{P}-Site-Action-BaseGone", RESET_STATE, refresh=True))
t.append(trig(f"{P}-Site-Trigger-BaseWatchdog", "Timer", [f"{P}-Site-Action-BaseSilent"], f"{P}-Site-Condition-AnyBase",
              starts_ready=False, cooldown=900000))
t.append(cond(f"{P}-Site-Condition-AnyBase", [BASE["SOBAN"], BASE["KHAANEPH"]], any_true=True))
t.append(action(f"{P}-Site-Action-BaseSilent", [f"[SetBooleansFalse:{BASE['SOBAN']}]", f"[SetBooleansFalse:{BASE['KHAANEPH']}]"],
                refresh=True))
t.append(trig(f"{P}-Site-Trigger-TurretUp", "CommandReceived", [f"{P}-Site-Action-TurretUp"],
              extra=["[CommandReceiveCode:GVK-BaseSite-TurretUp]"]))
t.append(action(f"{P}-Site-Action-TurretUp", [f"[IncreaseCounters:{TCOUNT}]"], refresh=True))
t.append(trig(f"{P}-Site-Trigger-TurretUpPending", "CommandReceived", [f"{P}-Site-Action-TurretUpPending"],
              f"{P}-Site-Condition-TurretPendingEnd", ["[CommandReceiveCode:GVK-BaseSite-TurretUp]"]))
t.append(action(f"{P}-Site-Action-TurretUpPending", [
    f"[SetBooleansFalse:{TPEND}]", f"[SetBooleansTrue:{TCOOL}]", "[ResetCooldownTimeOfTriggers:true]",
    f"[ResetTriggerCooldownNames:{P}-Site-Trigger-TurretCoolEnd]"], refresh=True))
t.append(trig(f"{P}-Site-Trigger-TurretLost", "CommandReceived", [f"{P}-Site-Action-TurretLost"],
              f"{P}-Site-Condition-HasTurret", ["[CommandReceiveCode:GVK-BaseSite-TurretLost]"]))
t.append(cond(f"{P}-Site-Condition-HasTurret", counters=[(TCOUNT, 1, "GreaterOrEqual")]))
t.append(action(f"{P}-Site-Action-TurretLost", [f"[DecreaseCounters:{TCOUNT}]"], refresh=True))

t.append(section("DEFENSE TURRET ROLL CALL (keeps the count right when a Turret vanishes without reporting)"))
# Every minute the Base Site asks its Base to call its Turrets. Each live Turret answers through the Base, and when the
# window closes the count is set to the answers. An admin delete sends no report, so without this the slot never frees.
# The count is set only if the Base answered: a Base that isn't loaded can't count its Turrets.
t.append(trig(f"{P}-Site-Trigger-TurretRollCall", "Timer", [f"{P}-Site-Action-TurretRollCall"],
              f"{P}-Site-Condition-RollCallReady", cooldown=60000))
t.append(cond(f"{P}-Site-Condition-RollCallReady", [BASE["SOBAN"], BASE["KHAANEPH"]], [ROLL], any_true=True))
t.append(action(f"{P}-Site-Action-TurretRollCall", [
    f"[SetBooleansTrue:{ROLL}]", f"[SetBooleansFalse:{ROLLACK}]", f"[ResetCounters:{TALLY}]",
    "[BroadcastCommandProfiles:true]", f"[CommandProfileIds:{P}-Command-TurretRollCall]",
    "[ResetCooldownTimeOfTriggers:true]", f"[ResetTriggerCooldownNames:{P}-Site-Trigger-TurretRollCallEnd]"]))
t.append(command(f"{P}-Command-TurretRollCall", "GVK-BaseSite-TurretRollCall", 1100, cross_owner=True))
t.append(cond(f"{P}-Site-Condition-RollCallOpen", [ROLL]))
t.append(trig(f"{P}-Site-Trigger-TurretRollCallAck", "CommandReceived", [f"{P}-Site-Action-TurretRollCallAck"],
              f"{P}-Site-Condition-RollCallOpen", ["[CommandReceiveCode:GVK-BaseSite-TurretRollCallAck]"]))
t.append(action(f"{P}-Site-Action-TurretRollCallAck", [f"[SetBooleansTrue:{ROLLACK}]"]))
for name, code in [("TurretHere", "GVK-BaseSite-TurretHere"), ("TurretUpTally", "GVK-BaseSite-TurretUp")]:
    t.append(trig(f"{P}-Site-Trigger-{name}", "CommandReceived", [f"{P}-Site-Action-TallyUp"],
                  f"{P}-Site-Condition-RollCallOpen", [f"[CommandReceiveCode:{code}]"]))
t.append(action(f"{P}-Site-Action-TallyUp", [f"[IncreaseCounters:{TALLY}]"]))
t.append(trig(f"{P}-Site-Trigger-TurretLostTally", "CommandReceived", [f"{P}-Site-Action-TallyDown"],
              f"{P}-Site-Condition-RollCallHasTally", ["[CommandReceiveCode:GVK-BaseSite-TurretLost]"]))
t.append(cond(f"{P}-Site-Condition-RollCallHasTally", [ROLL], counters=[(TALLY, 1, "GreaterOrEqual")]))
t.append(action(f"{P}-Site-Action-TallyDown", [f"[DecreaseCounters:{TALLY}]"]))
t.append(trig(f"{P}-Site-Trigger-TurretRollCallEnd", "Timer", [f"{P}-Site-Action-TurretRollCallEnd"],
              f"{P}-Site-Condition-RollCallOpen", starts_ready=False, cooldown=5000))
t.append(action(f"{P}-Site-Action-TurretRollCallEnd", [
    f"[SetBooleansFalse:{ROLL}]", "[ManuallyActivateTrigger:true]", f"[ManuallyActivatedTriggerTags:{P}-TriggerTags-ApplyTally]"]))
# MES drops 0 from integer lists, so a tally of 0 is matched with Less 1 and applied with ResetCounters.
for n in range(TALLY_MAX + 1):
    cmp = (TALLY, 1, "Less") if n == 0 else (TALLY, n, "GreaterOrEqual" if n == TALLY_MAX else "Equal")
    t.append(trig(f"{P}-Site-Trigger-TurretTally-{n}", "Manual", [f"{P}-Site-Action-TurretTally-{n}"],
                  f"{P}-Site-Condition-TurretTally-{n}", tags=[f"{P}-TriggerTags-ApplyTally"]))
    t.append(cond(f"{P}-Site-Condition-TurretTally-{n}", [ROLLACK], counters=[cmp]))
    t.append(action(f"{P}-Site-Action-TurretTally-{n}",
                    [f"[ResetCounters:{TCOUNT}]"] if n == 0 else [f"[SetCounters:{TCOUNT}]", f"[SetCountersValues:{n}]"],
                    refresh=True))

t.append(section("COOLDOWNS (restarted by the action that starts them)"))
# TurretPendingEnd fires only when no Turret reported within a minute of the order: the spawn found no spot.
TURRET_FAILED = [f"[UseChatBroadcast:true]", f"[ChatData:{P}-Site-Chat-TurretFailed]"]
for name, flag, ms, extra in [("LockEnd", LOCK, 7200000, []), ("ClaimPendingEnd", PEND, 120000, []),
                              ("TurretPendingEnd", TPEND, 60000, TURRET_FAILED),
                              ("TurretCoolEnd", TCOOL, TURRET_COOL_MS, []), ("RestoreCoolEnd", RCOOL, RESTORE_COOL_MS, [])]:
    t.append(trig(f"{P}-Site-Trigger-{name}", "Timer", [f"{P}-Site-Action-{name}"], f"{P}-Site-Condition-{name}",
                  starts_ready=False, cooldown=ms))
    t.append(cond(f"{P}-Site-Condition-{name}", [flag]))
    t.append(action(f"{P}-Site-Action-{name}", [f"[SetBooleansFalse:{flag}]"] + extra, refresh=True))
t.append(comp(f"{P}-Site-Chat-TurretFailed", [
    "[RivalAI Chat]", "[UseChat:true]", "[StartsReady:true]", "[Chance:100]", "[MaxChats:-1]", "[BroadcastRandomly:false]",
    "[Author:Base Site]", "[Color:Blue]",
    "[ChatMessages:No clear spot was found for the Defense Turret. The contract is open again, with no cooldown.]",
    "[ChatAudio:ArcHudSensors]", "[BroadcastChatType:Chat]", "[IgnoreAntennaRequirement:true]",
    "[IgnoredAntennaRangeOverride:5000]"]))

t.append(section("HOSTILE PLAYERS WITHIN 5 KM (per alliance)"))
for f in F:
    pc = f"[PlayerConditionIds:{P}-PlayerCondition-Hostile{f}]"
    t.append(trig(f"{P}-Site-Trigger-HostileArrived-{f}", "PlayerNear", [f"{P}-Site-Action-HostileArrived-{f}"],
                  f"{P}-Site-Condition-NotHostile-{f}", ["[TargetDistance:5000]", "[UsePlayerCondition:true]", pc], cooldown=10000))
    t.append(cond(f"{P}-Site-Condition-NotHostile-{f}", [], [HOST[f]]))
    t.append(action(f"{P}-Site-Action-HostileArrived-{f}", [f"[SetBooleansTrue:{HOST[f]}]"], refresh=True))
    t.append(trig(f"{P}-Site-Trigger-HostileStillNear-{f}", "PlayerNear", [f"{P}-Site-Action-HostileStillNear-{f}"],
                  extra=["[TargetDistance:5000]", "[UsePlayerCondition:true]", pc], cooldown=10000))
    t.append(action(f"{P}-Site-Action-HostileStillNear-{f}", [
        "[ResetCooldownTimeOfTriggers:true]", f"[ResetTriggerCooldownNames:{P}-Site-Trigger-HostileClear-{f}]"]))
    t.append(trig(f"{P}-Site-Trigger-HostileClear-{f}", "Timer", [f"{P}-Site-Action-HostileClear-{f}"],
                  f"{P}-Site-Condition-Hostile-{f}", starts_ready=False, cooldown=60000))
    t.append(cond(f"{P}-Site-Condition-Hostile-{f}", [HOST[f]]))
    t.append(action(f"{P}-Site-Action-HostileClear-{f}", [f"[SetBooleansFalse:{HOST[f]}]"], refresh=True))

t.append(section("SITE INSIDE EACH ALLIANCE'S TERRITORY"))
for f in F:
    t.append(trig(f"{P}-Site-Trigger-EnterTerritory-{f}", "InsideActiveZone", [f"{P}-Site-Action-EnterTerritory-{f}"],
                  f"{P}-Site-Condition-OutsideTerritory-{f}", [f"[ZoneName:{f}_Zone]"], cooldown=10000))
    t.append(cond(f"{P}-Site-Condition-OutsideTerritory-{f}", [], [TERR[f]]))
    t.append(action(f"{P}-Site-Action-EnterTerritory-{f}", [f"[SetBooleansTrue:{TERR[f]}]"], refresh=True))
    t.append(trig(f"{P}-Site-Trigger-LeaveTerritory-{f}", "OutsideActiveZone", [f"{P}-Site-Action-LeaveTerritory-{f}"],
                  f"{P}-Site-Condition-InsideTerritory-{f}", [f"[ZoneName:{f}_Zone]"], cooldown=10000))
    t.append(cond(f"{P}-Site-Condition-InsideTerritory-{f}", [TERR[f]]))
    t.append(action(f"{P}-Site-Action-LeaveTerritory-{f}", [f"[SetBooleansFalse:{TERR[f]}]"], refresh=True))

t.append(section("BOARD REFRESH: exactly one rule matches each state"))
t.append(trig(f"{P}-Site-Trigger-Session", "Session", [f"{P}-Site-Action-Refresh"]))
t.append(trig(f"{P}-Site-Trigger-PeriodicRefresh", "Timer", [f"{P}-Site-Action-Refresh"], cooldown=600000))
t.append(action(f"{P}-Site-Action-Refresh", [], refresh=True))
for name, true, false, counters, board in refresh_rules:
    t.append(trig(f"{P}-Site-Trigger-Refresh-{name}", "Manual", [f"{P}-Site-Action-Board-{board}"],
                  f"{P}-Site-Condition-Refresh-{name}", tags=[f"{P}-TriggerTags-RefreshBoard"]))
    t.append(cond(f"{P}-Site-Condition-Refresh-{name}", true, false, counters))
for board in BOARDS:
    t.append(action(f"{P}-Site-Action-Board-{board}", [
        "[ApplyContractProfiles:true]", "[ClearContractContentsFirst:true]", "[ContractBlocks:NPC Contracts]",
        f"[ContractBlockProfiles:{P}-Board-{board}]"]))

t.append(section("BASE SPAWN SPAWNERS"))
for f in F:
    t.append(comp(f"{P}-Spawner-Base-{f}", [
        "[MES AI Spawn]", "[UseSpawn:true]", "[SpawningType:CustomSpawn]", "[StartsReady:true]",
        "[ProcessAsAdminSpawn:true]", f"[SpawnGroups:{P}-Base-SpawnGroup-{f}]", "[MinDistance:200]",
        "[MaxDistance:500]", "[MinAltitude:0]", "[MaxAltitude:1]", "[InheritNpcAltitude:false]",
        "[IgnoreSafetyChecks:true]"],
        "One Base per site: the RC code GVK-Alliance-Base gate (1100 m) in the Base spawn conditions exceeds MaxDistance 500" if f == "SOBAN" else None))

theader = """\t\t<!--
\t\tBase Site grid (NST [UNKN] Base Site): runs the site's contract board (GVK-Settings#653, contracts in GVK-Alliance-PresetBases-Contracts.sbc).
\t\tState is local to each Base Site: which alliance's Base stands here, the 2-hour lock after a kill, the 20-minute turret
\t\tand 2-hour restore cooldowns, a Turret being placed, the standing Defense Turret count (re-counted by a roll call every
\t\tminute), whether players hostile to each alliance are within 5 km, and whether the site is inside each alliance's
\t\tTerritory (an alliance's Claim shows only while it is).
\t\tEvery change re-applies the one board profile that matches the new state. A contract the state blocks shows as a
\t\tstand-in that names the reason and can't be accepted.
\t\tThe Base reports to its Base Site with commands (GVK-Alliance-PresetBases-BaseSite.sbc). Design: Docs/design/preset-bases.md.
\t\t-->"""
write(PB / "GVK-Alliance-PresetBases-Site-Behavior.sbc", doc(theader, t))

# ---------------------------------------------------------------- Base and Defense Turret side
B = f"{P}-Base"
T = f"{P}-Turret"
CLAIMED, KILLED = "GVK_Site_Claimed", "GVK_Site_BaseKilled"
REPORTED, LOSTSENT = "GVK_Site_TurretReported", "GVK_Site_TurretLostSent"
s = []
s.append(section("BASE TRIGGER GROUPS (one per alliance)"))
base_shared = ["SpawnDefenseTurret", "Restore", "Gone", "RelayTurretUp", "RelayTurretLost", "RelayTurretHere", "RollCall"]
for f in F:
    s.append(comp(f"{B}-TriggerGroup-{f}", ["[RivalAI TriggerGroup]"] +
                  [f"[Triggers:{B}-Trigger-{x}-{f}]" for x in ["Claimed", "Heartbeat", "SpawnDefenseTurret", "Killed", "FriendlyKill"]] +
                  [f"[Triggers:{B}-Trigger-{x}]" for x in base_shared if x != "SpawnDefenseTurret"]))
s.append(cond(f"{B}-Condition-NotClaimed", [], [CLAIMED]))
s.append(cond(f"{B}-Condition-Standing", [], [KILLED]))
s.append(cond(f"{B}-Condition-NotDamagedByNonFriendlyPlayer", [], ["DamagedByNeutralPlayer", "DamagedByEnemyPlayer"]))

s.append(section("CLAIM: +50 INFLUENCE ONCE, THEN REPORT EVERY 5 MINUTES"))
for f in F:
    s.append(trig(f"{B}-Trigger-Claimed-{f}", "Session", [f"{B}-Action-Claimed-{f}"], f"{B}-Condition-NotClaimed"))
    s.append(action(f"{B}-Action-Claimed-{f}", [
        f"[SetBooleansTrue:{CLAIMED}]", "[SetCustomStrings:true]", f"[CustomStrings:IncreaseFactionName,{f}]",
        "[CustomStrings:IncreaseFactionAmount,50]", f"[IncreaseSandboxCounters:{f}_Influence]",
        "[IncreaseSandboxCountersAmount:50]", "[UseChatBroadcast:true]", "[ChatData:GVK-Alliance-Chat-InfluenceAdjustAwarded]"]))
    s.append(trig(f"{B}-Trigger-Heartbeat-{f}", "Timer", [f"{B}-Action-Heartbeat-{f}"], f"{B}-Condition-Standing", cooldown=300000))
    s.append(action(f"{B}-Action-Heartbeat-{f}", ["[BroadcastCommandProfiles:true]", f"[CommandProfileIds:{B}-Command-BaseUp-{f}]"]))
    s.append(command(f"{B}-Command-BaseUp-{f}", f"GVK-BaseSite-BaseUp-{f}", 1100, cross_owner=True))

s.append(section("ORDERS FROM THE BASE SITE'S BOARD"))
for f in F:
    s.append(trig(f"{B}-Trigger-SpawnDefenseTurret-{f}", "CommandReceived", [f"GVK-Alliance-Base-Action-SpawnTurret-{f}"],
                  f"{B}-Condition-Standing", ["[CommandReceiveCode:GVK-BaseSite-SpawnDefenseTurret]"]))
s.append(trig(f"{B}-Trigger-Restore", "CommandReceived", [f"{B}-Action-Restore"], f"{B}-Condition-Standing",
              ["[CommandReceiveCode:GVK-BaseSite-RestoreBase]"]))
s.append(action(f"{B}-Action-Restore", [
    "[RepairBlocks:true]", "[RepairBlocksIncludeSubgrids:true]", "[MaxProjectedBlocksToBuild:100000]",
    "[ToggleBlocksOfType:true]", "[BlockTypesToToggle:MyObjectBuilder_SafeZoneBlock/SafeZoneBlockNPC]", "[BlockTypeToggles:On]",
    "[UseChatBroadcast:true]", f"[ChatData:{B}-Chat-Restored]"]))
s.append(comp(f"{B}-Chat-Restored", [
    "[RivalAI Chat]", "[UseChat:true]", "[StartsReady:true]", "[Chance:100]", "[MaxChats:-1]", "[BroadcastRandomly:false]",
    "[Author:Sensors]", "[Color:Blue]", "[ChatMessages:Repair crews have restored the Base. Destroyed blocks stay lost.]",
    "[ChatAudio:ArcHudSensors]", "[BroadcastChatType:Chat]", "[IgnoreAntennaRequirement:true]", "[IgnoredAntennaRangeOverride:5000]"]))

s.append(section("LOSING THE BASE"))
for f in F:
    tag = f"GVK-Alliance-TriggerTags-InfluenceCompromised-AllianceBase-{f}"
    s.append(trig(f"{B}-Trigger-Killed-{f}", "Manual", [f"{B}-Action-Killed"], tags=[tag]))
    s.append(trig(f"{B}-Trigger-FriendlyKill-{f}", "Manual", ["GVK-Alliance-Action-InfluenceDespawned-AllianceBase"],
                  f"{B}-Condition-NotDamagedByNonFriendlyPlayer", tags=[tag]))
s.append(action(f"{B}-Action-Killed", [
    f"[SetBooleansTrue:{KILLED}]", "[BroadcastCommandProfiles:true]", f"[CommandProfileIds:{B}-Command-BaseKilled]",
    f"[CommandProfileIds:{B}-Command-DespawnDefenseTurrets]"]))
s.append(trig(f"{B}-Trigger-Gone", "DespawnMES", [f"{B}-Action-Gone"], f"{B}-Condition-Standing", ["[DespawnTypeFromSpawner:Any]"]))
s.append(action(f"{B}-Action-Gone", [
    "[BroadcastCommandProfiles:true]", f"[CommandProfileIds:{B}-Command-BaseGone]",
    f"[CommandProfileIds:{B}-Command-DespawnDefenseTurrets]"]))
s.append(command(f"{B}-Command-BaseKilled", "GVK-BaseSite-BaseKilled", 1100, cross_owner=True))
s.append(command(f"{B}-Command-BaseGone", "GVK-BaseSite-BaseGone", 1100, cross_owner=True))
s.append(command(f"{B}-Command-DespawnDefenseTurrets", "GVK-BaseSite-DespawnDefenseTurrets", 1100, ["[MatchReceiverChild:true]"]))

s.append(section("DEFENSE TURRET COUNT: RELAY CHILD REPORTS TO THE BASE SITE"))
for d in ["Up", "Lost", "Here"]:
    s.append(trig(f"{B}-Trigger-RelayTurret{d}", "CommandReceived", [f"{B}-Action-RelayTurret{d}"], f"{B}-Condition-Standing",
                  [f"[CommandReceiveCode:GVK-BaseSite-Turret{d}-ToBase]"]))
    s.append(action(f"{B}-Action-RelayTurret{d}", ["[BroadcastCommandProfiles:true]", f"[CommandProfileIds:{B}-Command-Turret{d}]"]))
    s.append(command(f"{B}-Command-Turret{d}", f"GVK-BaseSite-Turret{d}", 1100, cross_owner=True))
# Roll call: answer the Base Site (so it knows the count can be trusted), then call this Base's Turrets.
s.append(trig(f"{B}-Trigger-RollCall", "CommandReceived", [f"{B}-Action-RollCall"], f"{B}-Condition-Standing",
              ["[CommandReceiveCode:GVK-BaseSite-TurretRollCall]"]))
s.append(action(f"{B}-Action-RollCall", ["[BroadcastCommandProfiles:true]", f"[CommandProfileIds:{B}-Command-RollCallAck]",
                                         f"[CommandProfileIds:{B}-Command-RollCallTurrets]"]))
s.append(command(f"{B}-Command-RollCallAck", "GVK-BaseSite-TurretRollCallAck", 1100, cross_owner=True))
s.append(command(f"{B}-Command-RollCallTurrets", "GVK-BaseSite-TurretRollCall-ToTurrets", 1100, ["[MatchReceiverChild:true]"]))

s.append(section("DEFENSE TURRET TRIGGER GROUPS (one per alliance)"))
for f in F:
    s.append(comp(f"{T}-TriggerGroup-{f}", ["[RivalAI TriggerGroup]", f"[Triggers:{T}-Trigger-Reported]",
                  f"[Triggers:{T}-Trigger-DespawnOrder]", f"[Triggers:{T}-Trigger-Lost-{f}]", f"[Triggers:{T}-Trigger-Despawned]",
                  f"[Triggers:{T}-Trigger-RollCall]"],
                  "Shared with lone Encounter Turrets: with no parent Base, their reports reach no one" if f == "SOBAN" else None))
s.append(cond(f"{T}-Condition-NotReported", [], [REPORTED]))
s.append(cond(f"{T}-Condition-NotLost", [], [LOSTSENT]))
s.append(trig(f"{T}-Trigger-Reported", "Session", [f"{T}-Action-Reported"], f"{T}-Condition-NotReported"))
s.append(action(f"{T}-Action-Reported", [f"[SetBooleansTrue:{REPORTED}]", "[BroadcastCommandProfiles:true]",
                                         f"[CommandProfileIds:{T}-Command-TurretUp]"]))
s.append(trig(f"{T}-Trigger-DespawnOrder", "CommandReceived", [f"{T}-Action-DespawnOrder"],
              extra=["[CommandReceiveCode:GVK-BaseSite-DespawnDefenseTurrets]"]))
s.append(action(f"{T}-Action-DespawnOrder", ["[SetBooleansTrue:GVK_DespawnedByRule]", "[ForceDespawn:true]"]))
for f in F:
    s.append(trig(f"{T}-Trigger-Lost-{f}", "Manual", [f"{T}-Action-Lost"], f"{T}-Condition-NotLost",
                  tags=[f"GVK-Alliance-TriggerTags-InfluenceCompromised-AllianceTurret-{f}"]))
s.append(trig(f"{T}-Trigger-Despawned", "DespawnMES", [f"{T}-Action-Lost"], f"{T}-Condition-NotLost", ["[DespawnTypeFromSpawner:Any]"]))
s.append(action(f"{T}-Action-Lost", [f"[SetBooleansTrue:{LOSTSENT}]", "[BroadcastCommandProfiles:true]",
                                     f"[CommandProfileIds:{T}-Command-TurretLost]"]))
s.append(trig(f"{T}-Trigger-RollCall", "CommandReceived", [f"{T}-Action-RollCall"], f"{T}-Condition-NotLost",
              ["[CommandReceiveCode:GVK-BaseSite-TurretRollCall-ToTurrets]"]))
s.append(action(f"{T}-Action-RollCall", ["[BroadcastCommandProfiles:true]", f"[CommandProfileIds:{T}-Command-TurretHere]"]))
for d in ["Up", "Lost", "Here"]:
    s.append(command(f"{T}-Command-Turret{d}", f"GVK-BaseSite-Turret{d}-ToBase", 1100, ["[MatchReceiverParent:true]"]))

sheader = """\t\t<!--
\t\tBase Site, Base and Defense Turret side (GVK-Settings#653). Each Base behavior adds its alliance's Base trigger group,
\t\teach Turret behavior its Turret trigger group.
\t\t- Base: +50 Influence once when it first spawns, a report to its Base Site every 5 minutes, Defense Turrets and Restore on
\t\t  the Base Site's orders, and a report when it is killed or despawned (its Defense Turrets despawn with it).
\t\t- A kill costs its alliance 50 Influence even when no enemy or neutral player damaged it (closes the claim-and-kill farm).
\t\t- Defense Turret: reports to its parent Base when it spawns, when it is lost and at each roll call; the Base relays all
\t\t  three to the Base Site.
\t\tBase Site side: GVK-Alliance-PresetBases-Site-Behavior.sbc. Design: Docs/design/preset-bases.md.
\t\t-->"""
write(PB / "GVK-Alliance-PresetBases-BaseSite.sbc", doc(sheader, s))
print("rules", len(refresh_rules), "boards", len(BOARDS), "site triggers", len(triggers))
