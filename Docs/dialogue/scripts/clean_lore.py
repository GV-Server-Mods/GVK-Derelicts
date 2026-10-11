"""Wikitext JSON (MediaWiki parse API) -> plain text + lexicon of linked proper nouns."""
import json, re, glob, os, collections

HERE = os.path.dirname(os.path.abspath(__file__))
LORE = os.path.join(HERE, "..", "lore")
lexicon = collections.Counter()


def strip(w):
    w = re.sub(r"<ref[^>]*/>|<ref.*?</ref>", "", w, flags=re.S)
    w = re.sub(r"<!--.*?-->", "", w, flags=re.S)
    for _ in range(5):  # nested templates
        w = re.sub(r"\{\{[^{}]*\}\}", "", w)
    w = re.sub(r"\{\|.*?\|\}", "", w, flags=re.S)  # tables
    w = re.sub(r"\[\[(?:File|Image|Category):[^\]]*\]\]", "", w)

    def link(m):
        target, _, label = m.group(1).partition("|")
        lexicon[target.strip()] += 1
        return label or target
    w = re.sub(r"\[\[([^\]]+)\]\]", link, w)
    w = re.sub(r"\[https?://\S+ ([^\]]+)\]", r"\1", w)
    w = re.sub(r"'''?", "", w)
    w = re.sub(r"<[^>]+>", "", w)
    w = re.sub(r"\n{3,}", "\n\n", w)
    return w.strip()


for path in sorted(glob.glob(os.path.join(HERE, "..", "reference", "lore-json", "*.json"))):
    name = os.path.splitext(os.path.basename(path))[0]
    wt = json.load(open(path, encoding="utf-8"))["parse"]["wikitext"]["*"]
    text = strip(wt)
    open(os.path.join(LORE, name + ".txt"), "w", encoding="utf-8").write(text)
    print(f"{name}: {len(wt)} -> {len(text)} chars, {len(text.split())} words")

with open(os.path.join(LORE, "lexicon.txt"), "w", encoding="utf-8") as f:
    for term, n in lexicon.most_common():
        f.write(f"{n}\t{term}\n")
print("lexicon terms:", len(lexicon))
