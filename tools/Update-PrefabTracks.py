"""Move prefab suspensions, wheels and tracks off the hidden GVK_Suspension blocks, onto blocks players can build.

Every prefab and store prefab, projector copies included, gets the same swap (owner, 2026-11-25: "This job should be
identical across all prefabs"):
- Short Track and Lifted Short Track suspensions -> Keen's Short and GVK's Lifted Short suspension of the same size
  and hand (same block size, mount and physics; GVK_Suspension Docs/design/track-wheel-swap.md, Part C).
- Real Track Wheels -> Keen's tire of that size, mirrored on a mirrored suspension (Keen's own pairing).
- Track Wheel 1x1 and Short Track Wheel 1x1 blocks (1x2x1) -> Keen's Wheel 1x1 in the block's hull-side cell, same
  facing. Every saved track that lists the block moves its roller to the new cell.
- Keen's Wheel 1x1 in a track is turned to face out (its top away from the hull, like the suspensions), the way the
  Track Wheel 1x1 look swapped onto it is drawn.
- Every saved track gets its prefab's tread (design_for): Kharak Double Tread on COALITION and SOBAN NPCs (owner,
  2026-11-25: "Make all of the COAL and SOBA NPCs use the Kharak Double tread"), Rubber Track on every other grid,
  store grids included (owner, 2026-11-23).
The 3x3 Track Wheel blocks are left as they are and listed.

Usage (from the repo root): python tools/Update-PrefabTracks.py [--check]
--check lists what it would change and exits 1 if anything is left, without writing. Files keep their BOM and line
endings. Checks every track roller against the [Blocks] lines in GVK_Suspension's TankTracks.ini: a roller with no
style for its track's tread makes Tank Tracks drop the whole track.
"""
import argparse
import base64
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ARGS = argparse.ArgumentParser()
ARGS.add_argument("--check", action="store_true")
CHECK = ARGS.parse_args().check

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "Content/Data"
TANK_TRACKS_INI = ROOT.parent / "GVK_Suspension/Content/Data/TankTracks.ini"
KEY = "1b597013-2bd3-4de5-a591-f0b0ee9ec513"     # Tank Tracks' mod storage key (SerializedTrack, protobuf)
RUBBER, DOUBLE = "GVK_RubberTrack_Large", "KharakDoubleTread_Large"
XSI = "{http://www.w3.org/2001/XMLSchema-instance}type"

SUSPENSIONS = {}
for size, keen_m in (("1x1", "mirrored"), ("2x2", "Mirrored"), ("3x3", "mirrored"), ("5x5", "mirrored")):
    SUSPENSIONS["LiftedShortTrackSuspension" + size] = "LiftedShortSuspension" + size
    SUSPENSIONS["LiftedShortTrackSuspension" + size + "mirrored"] = "LiftedShortSuspension" + size + keen_m
    SUSPENSIONS["ShortTrackSuspension" + size] = "ShortSuspension" + size
    SUSPENSIONS["ShortTrackSuspension" + size + "mirrored"] = "ShortSuspension" + size + keen_m
WHEELS = {"RealTrackWheel1x1": ("RealWheel1x1", "RealWheel1x1mirrored"),
          "RealTrackWheel2x2": ("RealWheel2x2", "RealWheel2x2Mirrored"),
          "RealTrackWheel": ("RealWheel", "RealWheelmirrored"),
          "RealTrackWheel5x5": ("RealWheel5x5", "RealWheel5x5mirrored")}
TRACK_WHEEL_1X1 = ("TankWheelBlock1x1", "ShortTankWheelBlock1x1")
TRACK_WHEEL_3X3 = ("TankWheelBlock3x3", "ShortTankWheelBlock3x3")
DIRS = {"Forward": (0, 0, -1), "Backward": (0, 0, 1), "Left": (-1, 0, 0), "Right": (1, 0, 0),
        "Up": (0, 1, 0), "Down": (0, -1, 0)}
NAMES = {v: k for k, v in DIRS.items()}


# --- protobuf (as protobuf-net writes it) ---

def varint(b, i):
    r = s = 0
    while True:
        c = b[i]; i += 1
        r |= (c & 0x7F) << s; s += 7
        if not c & 0x80:
            return r, i


def enc_varint(v):
    v &= (1 << 64) - 1
    out = bytearray()
    while True:
        c = v & 0x7F; v >>= 7
        out.append(c | (0x80 if v else 0))
        if not v:
            return bytes(out)


def fields(b):
    i, out = 0, []
    while i < len(b):
        k, i = varint(b, i)
        f, w = k >> 3, k & 7
        if w == 0:
            v, i = varint(b, i)
        elif w == 2:
            n, i = varint(b, i)
            v = b[i:i + n]; i += n
        else:
            raise ValueError("wire type %d" % w)
        out.append((f, w, v))
    return out


def enc_fields(fs):
    out = bytearray()
    for f, w, v in fs:
        out += enc_varint(f << 3 | w)
        out += enc_varint(v) if w == 0 else enc_varint(len(v)) + v
    return bytes(out)


def signed(v):
    return v - (1 << 64) if v >= 1 << 63 else v


def dec_v3i(b):
    d = {f: signed(v) for f, _, v in fields(b)}
    return (d.get(1, 0), d.get(4, 0), d.get(7, 0))     # VRageMath.Vector3I: X=1, Y=4, Z=7


def enc_v3i(p):
    return enc_fields([(f, 0, v) for f, v in zip((1, 4, 7), p)])     # saved with zeros written out


def read_track(raw):
    rollers, design = [], None
    for f, _, v in fields(base64.b64decode(raw)):
        if f == 1:
            rollers.append(dec_v3i(next(x for g, _, x in fields(v) if g == 1)))
        elif f == 2:
            design = v.decode()
    return design, rollers


def write_track(raw, design, moves):
    out = []
    for f, w, v in fields(base64.b64decode(raw)):
        if f == 1:
            v = enc_fields([(g, gw, enc_v3i(moves.get(dec_v3i(x), dec_v3i(x))) if g == 1 else x)
                            for g, gw, x in fields(v)])
        elif f == 2:
            v = design.encode()
        out.append((f, w, v))
    return base64.b64encode(enc_fields(out)).decode()


def design_for(path):
    """The tread every track on this prefab gets."""
    if path.parent.name == "Prefabs" and re.search(r"\[(COAL|SOBA)\]", path.name):
        return DOUBLE
    return RUBBER


# --- TankTracks.ini: each block's style list ---

def block_styles():
    styles, block = {}, False
    for line in TANK_TRACKS_INI.read_text(encoding="utf-8-sig").splitlines():
        line = line.split(";", 1)[0].strip()
        if line.startswith("["):
            block = line == "[Blocks]"
        elif block and "=" in line:
            name, value = line.split("=", 1)
            styles[name.strip().split("/", 1)[1]] = value
    return styles


# --- prefab blocks ---

def v(e):
    return (int(e.get("x")), int(e.get("y")), int(e.get("z")))


def add(a, b, k=1):
    return tuple(x + k * y for x, y in zip(a, b))


class Block:
    def __init__(self, el):
        self.el = el
        self.type = el.get(XSI, "").replace("MyObjectBuilder_", "")
        self.subtype = el.findtext("SubtypeName") or ""
        self.id = el.findtext("EntityId")
        mn = el.find("Min")
        self.min = v(mn) if mn is not None else (0, 0, 0)
        o = el.find("BlockOrientation")
        self.fwd = o.get("Forward") if o is not None else "Forward"
        self.up = o.get("Up") if o is not None else "Up"
        self.new = {}            # field -> new value: subtype, min, up, track
        self.track = None
        for item in el.findall("./ComponentContainer/Components/ComponentData/Component/Storage/dictionary/item"):
            if item.findtext("Key") == KEY:
                self.track = item.findtext("Value")


def grid_sets(root):
    yield "grid", root.findall(".//CubeGrids/CubeGrid")
    for i, pg in enumerate(root.iter("ProjectedGrids")):
        yield "projection %d" % (i + 1), pg.findall("MyObjectBuilder_CubeGrid")


def plan(path, styles, notes):
    text = path.read_bytes().decode("utf-8-sig")
    root = ET.fromstring(text.encode("utf-8"))
    order = [Block(el) for el in root.iter("MyObjectBuilder_CubeBlock")]
    by_el = {id(b.el): b for b in order}
    for label, grids in grid_sets(root):
        blocks = [[by_el[id(el)] for el in g.find("CubeBlocks")] for g in grids]
        wheels = {b.id: b for g in blocks for b in g if b.type == "Wheel"}
        for g in blocks:
            for b in g:
                if b.type == "MotorSuspension":
                    if b.subtype in SUSPENSIONS:
                        b.new["subtype"] = SUSPENSIONS[b.subtype]
                    w = wheels.get(b.el.findtext("TopBlockId"))
                    if w is not None and w.subtype in WHEELS:
                        w.new["subtype"] = WHEELS[w.subtype][b.subtype.lower().endswith("mirrored")]
                elif b.subtype in TRACK_WHEEL_1X1:
                    up = DIRS[b.up]
                    b.new["subtype"] = "Wheel1x1"
                    b.new["min"] = b.min if sum(up) > 0 else add(b.min, up, -1)   # the cell opposite its top
                elif b.subtype in TRACK_WHEEL_3X3:
                    notes.append("%s, %s: %s at %s left as it is" % (path.name, label, b.subtype, b.min))
        for w in wheels.values():
            if w.subtype in WHEELS and "subtype" not in w.new:
                notes.append("%s, %s: %s %s is on no suspension; left as it is" % (path.name, label, w.subtype, w.id))
        for g in blocks:
            at = {b.min: b for b in g}
            for b in g:
                if b.track is None:
                    continue
                design, rollers = read_track(b.track)
                parts = [at.get(r) for r in rollers]
                if None in parts:
                    sys.exit("%s, %s: a track on %s lists a roller with no block" % (path.name, label, b.subtype))
                outs = {DIRS[p.up] for p in parts if p.type == "MotorSuspension"}
                if len(outs) != 1:
                    sys.exit("%s, %s: the suspensions on one track face %d ways" % (path.name, label, len(outs)))
                out = outs.pop()
                axis = next(i for i in range(3) if out[i])
                hull = next(p.min for p in parts if p.type == "MotorSuspension")[axis] + out[axis]
                moves = {}
                for p in parts:
                    if p.new.get("subtype", p.subtype) != "Wheel1x1":
                        continue
                    if p.new.get("min", p.min) != p.min:
                        moves[p.min] = p.new["min"]
                    if DIRS[p.up] != out:
                        p.new["up"] = NAMES[out]
                    if p.new.get("min", p.min)[axis] != hull:
                        notes.append("%s, %s: Wheel 1x1 roller at %s is not against the hull; its look will float"
                                     % (path.name, label, p.new.get("min", p.min)))
                tread = design_for(path)
                for p in parts:
                    if tread + "_" not in styles.get(p.new.get("subtype", p.subtype), ""):
                        sys.exit("%s, %s: %s has no %s style in TankTracks.ini"
                                 % (path.name, label, p.new.get("subtype", p.subtype), tread))
                if design != tread or moves:
                    b.new["track"] = write_track(b.track, tread, moves)
                    if write_track(b.track, design, {}) != b.track:
                        sys.exit("%s: a saved track does not re-encode to itself; format changed?" % path.name)
    return text, order


START = re.compile(r'<MyObjectBuilder_CubeBlock xsi:type="([^"]+)"')
END = "</MyObjectBuilder_CubeBlock>"


def apply(text, order):
    starts = list(START.finditer(text))
    if len(starts) != len(order):
        sys.exit("block count mismatch between the XML and the text")
    out, last = [], 0
    for m, b in zip(starts, order):
        if m.group(1).replace("MyObjectBuilder_", "") != b.type:
            sys.exit("block order mismatch at %s" % b.id)
        if not b.new:
            continue
        s, e = m.start(), text.index(END, m.start())
        span = text[s:e]
        if "subtype" in b.new:
            span = span.replace("<SubtypeName>%s</SubtypeName>" % b.subtype,
                                "<SubtypeName>%s</SubtypeName>" % b.new["subtype"], 1)
        if "min" in b.new:
            span = re.sub(r'<Min x="-?\d+" y="-?\d+" z="-?\d+" />',
                          '<Min x="%d" y="%d" z="%d" />' % b.new["min"], span, count=1)
        if "up" in b.new:
            span = span.replace('Up="%s" />' % b.up, 'Up="%s" />' % b.new["up"], 1)
        if "track" in b.new:
            span = span.replace("<Value>%s</Value>" % b.track, "<Value>%s</Value>" % b.new["track"], 1)
        out.append(text[last:s]); out.append(span); last = e
    out.append(text[last:])
    return "".join(out)


def main():
    styles = block_styles()
    notes, left = [], 0
    for path in sorted(list(DATA.glob("Prefabs/*.sbc")) + list(DATA.glob("StorePrefabs/*.sbc"))):
        text, order = plan(path, styles, notes)
        changed = [b for b in order if b.new]
        if not changed:
            continue
        left += len(changed)
        kinds = {}
        for b in changed:
            for k in b.new:
                key = "tracks" if k == "track" else "%s %s" % (b.subtype, {"subtype": "->" + b.new.get("subtype", ""),
                                                                        "min": "moved", "up": "turned"}[k])
                kinds[key] = kinds.get(key, 0) + 1
        print(path.relative_to(DATA).as_posix())
        for k, n in sorted(kinds.items()):
            print("   %3d  %s" % (n, k))
        if not CHECK:
            new = apply(text, order)
            bom = path.read_bytes().startswith(b"\xef\xbb\xbf")
            with open(path, "w", encoding="utf-8-sig" if bom else "utf-8", newline="") as f:
                f.write(new)
    for n in notes:
        print("note:", n)
    if CHECK and left:
        sys.exit(1)


if __name__ == "__main__":
    main()
