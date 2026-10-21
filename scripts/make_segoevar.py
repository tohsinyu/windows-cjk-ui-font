"""Build static stand-ins for every family/weight the stock Segoe UI Variable exposes.

usage: python -P -E make_segoevar.py <dir with SegoeUI-Sarasa-*.ttf from make_segoe.py> <out_dir>

Writes 20 fonts (4 families x 5 weights) plus registry_map.json ({registry value name: file}).
"""
import json
import sys
from pathlib import Path
from fontTools.ttLib import TTFont

SRC, OUT = Path(sys.argv[1]), Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)

FAMILIES = ["Segoe UI Variable", "Segoe UI Variable Small", "Segoe UI Variable Text", "Segoe UI Variable Display"]
WEIGHTS = [
    ("Light",     300, "SegoeUI-Sarasa-Light.ttf"),
    ("Semilight", 350, "SegoeUI-Sarasa-Semilight.ttf"),
    ("Regular",   400, "SegoeUI-Sarasa-Regular.ttf"),
    ("Semibold",  600, "SegoeUI-Sarasa-Semibold.ttf"),
    ("Bold",      700, "SegoeUI-Sarasa-Bold.ttf"),
]
RENAMED_IDS = {1, 2, 3, 4, 6, 16, 17, 21, 22}
GDI_MAX = 31  # GDI face names are cut at 31 chars; the stock FontLink keys use the same cut.

registry = {}
for family in FAMILIES:
    for wname, wclass, src in WEIGHTS:
        font = TTFont(SRC / src)
        name = font["name"]
        tag = (name.getDebugName(3) or "").split(";", 1)[-1] or "Sarasa-UI"
        name.names = [r for r in name.names if r.nameID not in RENAMED_IDS]

        ribbi = wname in ("Regular", "Bold")
        full = family if wname == "Regular" else f"{family} {wname}"
        legacy_family = (family if ribbi else full)[:GDI_MAX]
        legacy_style = wname if ribbi else "Regular"
        ps = family.replace(" ", "") + ("" if wname == "Regular" else f"-{wname}")

        records = {
            1: legacy_family, 2: legacy_style, 3: f"{full};{tag}", 4: full, 6: ps,
            16: family, 17: wname,
        }
        for nid, text in records.items():
            name.setName(text, nid, 3, 1, 0x409)
            name.setName(text, nid, 1, 0, 0)

        bold = wname == "Bold"
        os2 = font["OS/2"]
        os2.usWeightClass = wclass
        sel = os2.fsSelection & ~0b1100001
        sel |= (1 << 5) if bold else (1 << 6)
        os2.fsSelection = sel
        font["head"].macStyle = 1 if bold else 0

        fname = f"SegoeUIVar-Sarasa-{family.replace('Segoe UI Variable', '').strip() or 'Base'}-{wname}.ttf"
        font.save(OUT / fname)
        registry[f"{full} (TrueType)"] = fname
        print(f"{full:36} legacy={legacy_family!r:34} -> {fname}")

(OUT / "registry_map.json").write_text(json.dumps(registry, indent=2), encoding="utf-8")
print(f"{len(registry)} fonts written")
