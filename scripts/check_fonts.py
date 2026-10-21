"""Print naming, weight, style bits and CJK coverage for every .ttf in a folder.

usage: python -P -E check_fonts.py <dir>
Set PYTHONIOENCODING=utf-8 if the console cannot print CJK.
"""
import sys
from pathlib import Path
from fontTools.ttLib import TTFont

# 记录详细资续华 (simplified-only) + 已歸檔 (traditional) + Latin
PROBE = "记录详细资续华已歸檔Aa1"

files = sorted(Path(sys.argv[1]).glob("*.ttf"))
if not files:
    sys.exit("no .ttf files found")
bad = 0
for f in files:
    t = TTFont(f, lazy=True)
    n = t["name"]
    langs = sorted({(r.platformID, r.langID) for r in n.names if r.nameID in (1, 2, 4, 16, 17)})
    os2 = t["OS/2"]
    cmap = t.getBestCmap()
    missing = [hex(ord(c)) for c in PROBE if ord(c) not in cmap]
    extra_langs = [l for l in langs if l not in ((1, 0), (3, 0x409))]
    if missing or extra_langs:
        bad += 1
    print(f"{f.name:40} 1={n.getDebugName(1)!r:34} 2={n.getDebugName(2)!r:13} "
          f"16={n.getDebugName(16)!r:28} 17={n.getDebugName(17)!r:18} "
          f"w={os2.usWeightClass} sel={os2.fsSelection:#06x} mac={t['head'].macStyle} "
          f"extra_langs={extra_langs or '-'} missing={missing or '-'}")
print(f"{len(files)} files, {bad} with problems")
sys.exit(1 if bad else 0)
