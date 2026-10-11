"""Fix autogen mishearings, then split the playthrough into cutscene vs gameplay rows (unit chatter, alerts)."""
import csv, os, re, collections

HERE = os.path.dirname(os.path.abspath(__file__))
W = os.path.join(HERE, "..")

from fixes import fix


def load(name):
    with open(os.path.join(W, "reference", "clean", name + ".tsv"), encoding="utf-8") as f:
        return [(int(r[0]), r[1], fix(r[2])) for r in csv.reader(f, delimiter="\t")]


cut = load("cutscenes")
play = load("playthrough")
words = lambda t: re.sub(r"[^a-z' ]", " ", t.lower()).split()
grams = set()
for _, _, t in cut:
    w = words(t)
    grams.update(tuple(w[i:i + 4]) for i in range(len(w) - 3))

# Cutscene playthrough rows share most of their 4-grams with the cutscene transcript.
kept, chatter = [], []
for secs, _, t in play:
    w = words(t)
    g = [tuple(w[i:i + 4]) for i in range(len(w) - 3)]
    share = sum(x in grams for x in g) / len(g) if g else 0
    (kept if share >= 0.3 else chatter).append((secs, t, round(share, 2)))

for name, rows in (("cutscenes_norm", [(s, c, t) for s, c, t in cut]),):
    with open(os.path.join(W, "reference", "clean", name + ".tsv"), "w", encoding="utf-8", newline="") as f:
        csv.writer(f, delimiter="\t").writerows(rows)
with open(os.path.join(W, "reference", "clean", "gameplay.tsv"), "w", encoding="utf-8", newline="") as f:
    csv.writer(f, delimiter="\t").writerows(chatter)

print(f"playthrough rows: {len(play)} -> cutscene-like {len(kept)}, gameplay {len(chatter)} "
      f"({sum(len(t.split()) for _, t, _ in chatter)} words)")
fixed = collections.Counter()
for _, _, t in cut + play:
    for term in ("Gaalsien", "Kapisi", "Sakala", "Khar-Toba", "Sajuuk", "S'jet", "Siidim", "Jaraci", "Khagaan", "Baserunner", "Ashoka", "kiith"):
        fixed[term] += t.count(term)
print("canonical term counts after fixes:", dict(fixed))
