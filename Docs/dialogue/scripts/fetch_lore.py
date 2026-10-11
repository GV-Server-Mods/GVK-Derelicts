"""Download lore pages as wikitext through the Homeworld Fandom MediaWiki API into reference/lore-json/."""
import json, os, urllib.parse, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "reference", "lore-json")
PAGES = ["Coalition_of_the_Northern_Kiithid", "Kiith_S'jet", "Kiith_Gaalsien", "Kiith_Soban", "Khaaneph"]

os.makedirs(OUT, exist_ok=True)
for page in PAGES:
    url = ("https://homeworld.fandom.com/api.php?action=parse&prop=wikitext&format=json&redirects=1&page="
           + urllib.parse.quote(page))
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 GVK-lore-research"})
    data = json.load(urllib.request.urlopen(req, timeout=30))
    name = page.replace("'", "")
    with open(os.path.join(OUT, name + ".json"), "w", encoding="utf-8") as f:
        json.dump(data, f)
    print(name, len(data["parse"]["wikitext"]["*"]), "chars")
