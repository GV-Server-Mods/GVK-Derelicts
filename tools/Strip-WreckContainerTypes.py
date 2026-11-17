"""Strip Keen's loot tables from the prefabs that get GVK loot, so their crates roll Kharak loot (GVK-Settings#815).

A prefab gets GVK loot when a spawn group spawns it with a manipulation that sets [UseLootProfiles:true]; the wrecks
also set [ClearExistingContainerTypes:true]. MES clears a cargo container's type only in the first loot profile that
runs (and never without the clear flag), and it never sees Keen's random-cargo component on other blocks (freight
crates, barrels, beds, bodies), so those keep rolling Keen's tables. This script removes both from the prefab files.
Container types that GVK-ContainerTypes.sbc defines (GVK's own, or GVK overrides of Keen names) are kept.

Usage (from the repo root): python tools/Strip-WreckContainerTypes.py [--check]
Run it after re-exporting such a prefab. --check lists what it would strip and exits 1 if anything is left, without
writing. Files keep their BOM and line endings. Design: Docs/design/wreck-prefabs.md.
"""
import argparse
import re
import sys
from pathlib import Path

ARGS = argparse.ArgumentParser()
ARGS.add_argument("--check", action="store_true")
CHECK = ARGS.parse_args().check

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "Content/Data"

CARGO_TYPE = re.compile(r"[ \t]*<ContainerType>([^<]+)</ContainerType>\r?\n")
RANDOM_CARGO = re.compile(
    r"[ \t]*<ComponentData>\r?\n[ \t]*<TypeId>MyRandomCargoEntityComponent</TypeId>"
    r"(?:(?!</ComponentData>).)*?<ContainerType>([^<]+)</ContainerType>(?:(?!</ComponentData>).)*</ComponentData>\r?\n",
    re.S,
)


def read(path):
    return path.read_text(encoding="utf-8-sig", errors="replace")


def loot_manipulations():
    names = set()
    for f in DATA.glob("Encounters/**/*.sbc"):
        for comp in re.findall(r"<EntityComponent[^>]*>.*?</EntityComponent>", read(f), re.S):
            m = re.search(r"<SubtypeId>([^<]+)</SubtypeId>", comp)
            if m and ("[ClearExistingContainerTypes:true]" in comp or "[UseLootProfiles:true]" in comp):
                names.add(m.group(1))
    return names


def wreck_prefabs(manips):
    names = set()
    for f in DATA.glob("Encounters/**/*.sbc"):
        for group in re.findall(r"<SpawnGroup>.*?</SpawnGroup>", read(f), re.S):
            if set(re.findall(r"\[ManipulationProfiles:([^\]]+)\]", group)) & manips:
                names.update(re.findall(r'<Prefab SubtypeId="([^"]+)"', group))
    return names


def main():
    keep = set(re.findall(r"<TypeId>ContainerTypeDefinition</TypeId>\s*<SubtypeId>([^<]+)</SubtypeId>",
                          read(DATA / "GVK-ContainerTypes.sbc")))
    wrecks = wreck_prefabs(loot_manipulations())
    found = 0
    for f in sorted(DATA.glob("Prefabs/*.sbc")):
        raw = f.read_bytes()
        bom = raw.startswith(b"\xef\xbb\xbf")
        text = raw[3 if bom else 0:].decode("utf-8")
        m = re.search(r'<Id[^>]*Subtype="([^"]+)"', text)
        if not m or m.group(1) not in wrecks or "<ContainerType>" not in text:
            continue
        stripped = []

        def drop(match):
            if match.group(1) in keep:
                return match.group(0)
            stripped.append(match.group(1))
            return ""

        text = RANDOM_CARGO.sub(drop, text)
        text = CARGO_TYPE.sub(drop, text)
        if not stripped:
            continue
        found += len(stripped)
        print(f"{f.name}: {len(stripped)} ({', '.join(sorted(set(stripped)))})")
        if not CHECK:
            f.write_bytes((b"\xef\xbb\xbf" if bom else b"") + text.encode("utf-8"))
    verb = "found" if CHECK else "stripped"
    print(f"{found} Keen container type(s) {verb} on {len(wrecks)} prefabs that get GVK loot.")
    return 1 if CHECK and found else 0


if __name__ == "__main__":
    sys.exit(main())
