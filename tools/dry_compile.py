"""Dry-compile Loot on Hover's Witcher 3 scripts over the game's scripts - REDkit's wcc_lite
compilescripts, no game launch. The recipe is the PowerShell agent's, as Witcher Gear Overhaul's tools/dry_compile.py
uses it (logic library: a script error anywhere stops the game at start-up for every mod - compile before every hand-over).
This copy keeps its own tree under this repo's build\\ folder, so it never touches another project's build.

    python tools/dry_compile.py [mod root ...]     default: dist   (each root holds Mods\\<mod>\\content\\scripts)

Prints "COMPILE OK" or the "[Error][WCC] [<line>]: ..." lines (they carry no file name; each is shown with the line of
our files it may point at). Exit 0 = compiled.
"""
import glob
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
TREE = os.path.join(REPO, "build", "compile_tree")
GAME = os.environ.get("W3_GAME", r"D:\Steam Library\steamapps\common\The Witcher 3")
REDKIT = os.environ.get("W3_REDKIT", os.path.join(os.path.dirname(GAME), "The Witcher 3 REDkit"))


def main():
    roots = sys.argv[1:] or [os.path.join(REPO, "dist")]
    exe = os.path.join(REDKIT, "bin", "x64_RedKit", "wcc_lite.exe")
    if not os.path.isfile(exe):
        sys.exit("REDkit's wcc_lite.exe not found at " + exe + " (set W3_REDKIT)")
    shutil.rmtree(TREE, ignore_errors=True)
    shutil.copytree(os.path.join(GAME, "content", "content0", "scripts"), TREE)
    mods = []
    for root in roots:
        for d in glob.glob(os.path.join(os.path.abspath(root), "Mods", "*", "content", "scripts")):
            mods.append((os.path.basename(os.path.dirname(os.path.dirname(d))).lower(), d))
    ours = []
    for name, d in sorted(mods, reverse=True):   # lowest priority first (the folder that sorts first wins in game)
        for src in glob.glob(os.path.join(d, "**", "*.ws"), recursive=True):
            dst = os.path.join(TREE, os.path.relpath(src, d))
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copyfile(src, dst)
            ours.append(dst)
    print("laid over: " + ", ".join(n for n, _ in sorted(mods)))
    p = subprocess.run([exe, "compilescripts", TREE + "\\", "-agreetoterms"], cwd=os.path.dirname(exe),
                       capture_output=True, text=True, errors="replace", timeout=1200)
    out = p.stdout + p.stderr
    os.makedirs(os.path.join(REPO, "build"), exist_ok=True)
    open(os.path.join(REPO, "build", "dry_compile.log"), "w", encoding="utf-8").write(out)
    errors = [l for l in out.splitlines() if "[Error][WCC]" in l]
    if "Success!" in out and not errors:
        print("COMPILE OK - " + next(l for l in out.splitlines() if "Success!" in l).strip())
        return 0
    print("COMPILE FAILED - %d error line(s) (full output: build\\dry_compile.log)" % len(errors))
    for l in errors:
        print("  " + l.strip())
        m = re.search(r"\[(\d+)\]", l)
        idents = re.findall(r"'([A-Za-z_]\w*)'", l)
        ln = int(m.group(1)) if m else 0
        for f in ours:
            text = open(f, encoding="utf-8", errors="replace").read().splitlines()
            if 0 < ln <= len(text) and any(i in text[ln - 1] for i in idents or [""]):
                print("     lead: %s(%d): %s" % (os.path.relpath(f, TREE), ln, text[ln - 1].strip()[:120]))
    return 1


if __name__ == "__main__":
    sys.exit(main())
