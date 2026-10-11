"""Condense transcripts into small analysis files: recurring Coalition barks and alerts, and Gaalsien-voice excerpts."""
import csv, os, re, sys, collections
from fixes import fix

HERE = os.path.dirname(os.path.abspath(__file__))
W = os.path.join(HERE, "..")
words = lambda t: re.sub(r"[^a-z' -]", " ", t.lower()).split()

# 1. Recurring gameplay phrases (unit barks, alerts). Rows run barks together, so count n-grams, not rows.
# Usage: extract_phrases.py [clean/<name>.tsv]. The default is the Coalition gameplay split, plus the Gaalsien excerpts.
src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(W, "reference", "clean", "gameplay.tsv")
label = "coalition" if len(sys.argv) == 1 else os.path.splitext(os.path.basename(src))[0]
with open(src, encoding="utf-8") as f:
    rows = [fix(r[1] if src.endswith("gameplay.tsv") else r[2]) for r in csv.reader(f, delimiter="\t")]
counts = collections.Counter()
for t in rows:
    w = words(t)
    for n in range(2, 7):
        for i in range(len(w) - n + 1):
            counts[" ".join(w[i:i + n])] += 1
STOP = set("the a an and of to in is it we our you they this that be for on with as are was at by from or i".split())
cands = {g: c for g, c in counts.items()
         if c >= (4 if len(rows) > 1000 else 2) and g.split()[0] not in STOP - {"we", "i"} and g.split()[-1] not in STOP}
# Drop a phrase when a longer phrase containing it covers >=75% of its uses.
keep = []
for g, c in sorted(cands.items(), key=lambda x: (-len(x[0].split()), -x[1])):
    if any(g in k and kc >= 0.75 * c for k, kc in keep):
        continue
    keep.append((g, c))
keep.sort(key=lambda x: -x[1])
with open(os.path.join(W, "analysis", label + "_barks.txt"), "w", encoding="utf-8") as f:
    for g, c in keep[:250]:
        f.write(f"{c}\t{g}\n")
print("gameplay phrases kept:", len(keep), "(top 250 written)")

if len(sys.argv) > 1:
    sys.exit()

# 2. Gaalsien-voice excerpts: cutscene rows with religious/threat vocabulary, with one row of context.
KEYS = re.compile(r"sajuuk|heret|blasphem|faith|punish|sin\b|sacred|forbid|heaven|exile|prophe|great maker|"
                  r"sky|stars|gods?\b|pray|holy|curse|doom|kneel|cleans|purif|wrath|khagaan|k'had|faagan|"
                  r"turn back|leave this|you will die|desert will", re.I)
with open(os.path.join(W, "reference", "clean", "cutscenes_norm.tsv"), encoding="utf-8") as f:
    cut = list(csv.reader(f, delimiter="\t"))
hits, last = [], -5
for i, (secs, chap, t) in enumerate(cut):
    if KEYS.search(t):
        lo = max(i - 1, last + 1)
        if lo > last + 1:
            hits.append("---")
        hits += [f"{cut[j][0]}s [{cut[j][1][:28]}] {cut[j][2]}" for j in range(lo, min(i + 2, len(cut)))]
        last = i + 1
with open(os.path.join(W, "reference", "gaalsien_voice.txt"), "w", encoding="utf-8") as f:
    f.write("\n".join(hits) + "\n")
print("gaalsien-voice excerpt lines:", len(hits))
