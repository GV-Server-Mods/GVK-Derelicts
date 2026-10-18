"""Check drafts/ before building banks: line counts per cue and size, length, duplicates (within a draft, and the same
line in two factions' drafts), unit-class self-references, and copied text (any 5-word run shared with a transcript
in reference/clean/).

Usage (from Docs/dialogue): python scripts/check_drafts.py [drafts/<voice>.txt ...]
"""
import csv, glob, os, re, sys
from build_banks import parse_draft, DRAFTS
from fixes import fix

HERE = os.path.dirname(os.path.abspath(__file__))
CLEAN = os.path.join(HERE, "..", "reference", "clean")
MAX_LEN = 90
TARGET = 20      # lines per cue in each built bank
SPLIT = 10       # Unit cues: 10 shared + 10 per size
UNIT_CUES = ["TargetAcquired", "TargetStructure", "TargetAircraft", "TargetInfantry", "TargetFastMover", "TargetLongRange",
             "NoTargets", "NeutralAttacked", "EnemyAttacked", "FriendlyFire", "Defeated"]
OTHER_CUES = ["NeutralAttacked", "EnemyAttacked", "FriendlyFire", "Defeated"]
HOSTILE = {"GAALSIEN", "DERELICT"}
NOT_SPLIT = set()  # (voice, cue) pairs exempt from the line-count targets
NO_SMALL = {"Defeated"}  # Small Units (fighters, skimmers, LAVs) have no last words; the Sensors line is enough
# Cues only some voices speak, and the size tag their lines need (None: untagged). LaunchCraft plays when a Unit or convoy
# lead launches fighters or calls air support; DefensesDeployed when a structure or installation spawns its defenders.
EXTRA = {
    "Units-GAALSIEN": {"LaunchCraft": "Large", "DefensesDeployed": "Large"},
    "Units-KHAANEPH": {"LaunchCraft": "Large"},
    "Units-SOBAN": {"LaunchCraft": "Large"},
    "Structures-KHAANEPH": {"DefensesDeployed": None},
    "Structures-SOBAN": {"DefensesDeployed": None},
    "Installations-GAALSIEN": {"DefensesDeployed": None},
}
# Unit-class names: a size bank holds several designs, so a line must not name the speaker's own class.
CLASS_WORDS = re.compile(r"\b(sandskimmers?|skimmers?|interceptors?|honou?rguards?|baserunners?|runners?|salvagers?|"
                         r"LAVs?|bombers?|gunships?|horsefl(?:y|ies)|production cruisers?|torpedo|artillery cruisers?)\b", re.I)
words = lambda t: re.sub(r"[^a-z' ]", " ", t.lower()).split()

grams = set()
for p in glob.glob(os.path.join(CLEAN, "*.tsv")):
    with open(p, encoding="utf-8") as f:
        for row in csv.reader(f, delimiter="\t"):
            w = words(fix(row[-1] if not p.endswith("gameplay.tsv") else row[1]))
            grams.update(tuple(w[i:i + 5]) for i in range(len(w) - 4))

norm = lambda t: re.sub(r"\W", "", t.lower())
# Every line in every draft, so a line shared by two factions is caught even when only one draft is checked.
owners = {}
for p in glob.glob(os.path.join(DRAFTS, "*.txt")):
    v = os.path.splitext(os.path.basename(p))[0]
    for entries in parse_draft(p)[1].values():
        for _, text in entries:
            owners.setdefault(norm(text), set()).add((v.split("-")[1], v))

paths = sys.argv[1:] or sorted(glob.glob(os.path.join(DRAFTS, "*.txt")))
issues = 0
for path in paths:
    voice = os.path.splitext(os.path.basename(path))[0]
    category, faction = voice.split("-")
    _, cues = parse_draft(path)
    expected = UNIT_CUES if category == "Units" else OTHER_CUES
    if faction in HOSTILE:
        expected = [c for c in expected if c not in ("NeutralAttacked", "FriendlyFire")]
        if category == "Installations":
            expected = ["EnemyAttacked", "Defeated"]
    report = []
    if faction in HOSTILE:
        # Hostile factions are never neutral or friendly to anyone, so these cues have nothing to say
        report += [f"{cue}: {faction} never speaks this cue; remove the section" for cue in ("NeutralAttacked", "FriendlyFire") if cue in cues]
    for cue in expected:
        entries = cues.get(cue, [])
        if category == "Units" and cue in NO_SMALL:
            per = {s: sum(1 for only, _ in entries if only and s in only) for s in ("Small", "Medium", "Large")}
            if any(only is None for only, _ in entries) or per["Small"]:
                report.append(f"{cue}: Small Units stay silent here; tag every line [M], [L] or [ML]")
            if per["Medium"] < TARGET or per["Large"] < TARGET:
                report.append(f"{cue}: M{per['Medium']}/L{per['Large']} (want {TARGET} each)")
        elif category == "Units" and (voice, cue) not in NOT_SPLIT:
            shared = sum(1 for only, _ in entries if only is None)
            per = {s: sum(1 for only, _ in entries if only and s in only) for s in ("Small", "Medium", "Large")}
            if shared < SPLIT or any(n < SPLIT for n in per.values()):
                report.append(f"{cue}: {shared} shared, S{per['Small']}/M{per['Medium']}/L{per['Large']} (want {SPLIT} each)")
        elif len(entries) < TARGET and (voice, cue) not in NOT_SPLIT:
            report.append(f"{cue}: {len(entries)} lines (want {TARGET})")
    for cue, size in EXTRA.get(voice, {}).items():
        entries = cues.get(cue, [])
        n = sum(1 for only, _ in entries if (size in only if only else size is None))
        if n < TARGET:
            report.append(f"{cue}: {n} {size or 'untagged'} lines (want {TARGET})")
    seen = {}
    for cue, entries in cues.items():
        for only, text in entries:
            if len(text) > MAX_LEN:
                report.append(f"{cue}: too long ({len(text)}): {text}")
            key = norm(text)
            if key in seen:
                report.append(f"{cue}: duplicate of {seen[key]}: {text}")
            seen[key] = cue
            others = sorted(v for f, v in owners.get(key, ()) if f != faction)
            if others:
                report.append(f"{cue}: same line as {', '.join(others)}; each faction needs its own wording: {text}")
            if category == "Units" and CLASS_WORDS.search(text) and not cue.startswith("Target"):
                report.append(f"{cue}: names a unit class, check it isn't self-reference: {text}")
            w = words(text)
            if any(tuple(w[i:i + 5]) in grams for i in range(len(w) - 4)):
                report.append(f"{cue}: shares 5+ words with a transcript: {text}")
    total = sum(len(e) for e in cues.values())
    print(f"{voice}: {total} lines, {'OK' if not report else str(len(report)) + ' issue(s)'}")
    for r in report:
        print("   ", r)
    issues += len(report)
sys.exit(1 if issues else 0)
