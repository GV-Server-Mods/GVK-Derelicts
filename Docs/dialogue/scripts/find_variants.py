"""Find autogen mishearings of lore proper nouns: transcript 1-3 word spans fuzzy-close to a canonical term."""
import csv, os, re, sys, glob, collections, difflib

HERE = os.path.dirname(os.path.abspath(__file__))
W = os.path.join(HERE, "..")

CANON = ["Kapisi", "Gaalsien", "S'jet", "Rachel S'jet", "Jaraci", "Khar-Toba", "Sajuuk", "Kiith", "Siidim",
         "Sakala", "Khagaan", "Kharak", "Tiir", "Soban", "Khaaneph", "Baserunner", "Sandskimmer", "Honorguard",
         "Ashoka", "K'had Sajuuk", "Kalash", "Faagan", "Kushan", "Daiamid", "Kiith-Sa", "Saju-ka", "Mashaad",
         "Hiigara", "Taiidan", "Khadiim", "Skaal Brii", "Naabal", "Manaan", "Somtaaw", "Paktu", "Gritiidim",
         "Kah'a", "Hand of Sajuuk", "Great Banded Desert", "Frontier Wall", "StormBreaker", "Guidestone"]
norm = lambda s: re.sub(r"[^a-z ]", "", s.lower().replace("-", " "))
canon_n = {norm(c): c for c in CANON}

text = []
# Usage: find_variants.py [clean/<name>.tsv ...]. The default is the two story transcripts.
paths = sys.argv[1:] or [os.path.join(W, "reference", "clean", n + ".tsv") for n in ("cutscenes", "playthrough")]
for path in paths:
    with open(path, encoding="utf-8") as f:
        text += [r[2] for r in csv.reader(f, delimiter="\t")]
tokens = norm(" ".join(text)).split()

COMMON = set("the a an and of to in is it we our you they this that be for on with as are was at by from or not have has but all will can".split())
hits = collections.defaultdict(collections.Counter)
for n in (1, 2, 3):
    for i in range(len(tokens) - n + 1):
        span = tokens[i:i + n]
        if span[0] in COMMON or span[-1] in COMMON:
            continue
        s = " ".join(span)
        for cn, c in canon_n.items():
            if abs(len(s) - len(cn)) > 3 or cn.count(" ") + 1 != n and abs(cn.count(" ") + 1 - n) > 1:
                continue
            r = difflib.SequenceMatcher(None, s.replace(" ", ""), cn.replace(" ", "")).ratio()
            if r >= 0.75:
                hits[c][s] += 1

out = os.path.join(W, "analysis", "variants.txt" if len(sys.argv) == 1 else "variants-new.txt")
with open(out, "w", encoding="utf-8") as f:
    for c in CANON:
        if hits[c]:
            f.write(f"{c}: " + ", ".join(f"{v}({k})" for v, k in hits[c].most_common(12)) + "\n")
        else:
            f.write(f"{c}: -\n")
print(open(out, encoding="utf-8").read())
