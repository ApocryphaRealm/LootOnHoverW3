"""Add (or remove) Loot on Hover's three pad bindings in an input.settings file.

    python tools/bindings.py "<path>\\input.settings"            add  (idempotent; backs the file up once per run)
    python tools/bindings.py "<path>\\input.settings" --remove   take them out again

The bindings sit beside the player's own in [Exploration] and [Swimming] - a key may carry several actions - so they
follow the face buttons whatever the player's map puts on them:
    IK_Pad_A_CROSS=(Action=LohTake)
    IK_Pad_X_SQUARE=(Action=LohTakeAll)
    IK_Pad_B_CIRCLE=(Action=LohClose)
Run it with the game (and Mod Organizer, for a profile's file) closed: the game writes the file while it runs.
"""
import os
import shutil
import sys
import time

LINES = ("IK_Pad_A_CROSS=(Action=LohTake)", "IK_Pad_X_SQUARE=(Action=LohTakeAll)", "IK_Pad_B_CIRCLE=(Action=LohClose)")
# earlier test builds also bound Y; --remove and a fresh add both take it out
OLD = ("IK_Pad_Y_TRIANGLE=(Action=LohOpenLoot)",)
CONTEXTS = {"[Exploration]": LINES, "[Swimming]": LINES}


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    path = sys.argv[1]
    remove = "--remove" in sys.argv[2:]
    raw = open(path, "rb").read()
    bom = raw.startswith(b"\xef\xbb\xbf")
    text = raw.decode("utf-8-sig")
    nl = "\r\n" if "\r\n" in text else "\n"
    lines = text.split(nl)

    out = [l for l in lines if l.strip() not in LINES and l.strip() not in OLD]
    removed = len(lines) - len(out)
    added = 0
    if not remove:
        result = []
        for l in out:
            result.append(l)
            if l.strip() in CONTEXTS:
                result.extend(CONTEXTS[l.strip()])
                added += len(CONTEXTS[l.strip()])
        out = result
        missing = [c for c in CONTEXTS if c not in (l.strip() for l in lines)]
        if missing:
            print("warning: no " + ", ".join(missing) + " section in " + path)

    if out == lines:
        print("unchanged: " + path)
        return 0
    backup = path + ".loot-on-hover-" + time.strftime("%Y%m%d-%H%M%S") + ".bak"
    shutil.copyfile(path, backup)
    data = nl.join(out).encode("utf-8")
    open(path, "wb").write((b"\xef\xbb\xbf" if bom else b"") + data)
    print("%s: %d binding line(s) removed, %d added (backup %s)" % (path, removed, added, os.path.basename(backup)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
