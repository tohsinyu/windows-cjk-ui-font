"""Rebuild an open-licensed CJK UI font as drop-in "Segoe UI" fonts (12 registry weights).

usage:
  python -P -E make_segoe.py <src_dir> <out_dir> [--pattern "SarasaUiTC-{style}.ttf"] [--tag "Sarasa-UI-TC-1.0.42"]

{style} in --pattern is replaced by the source style names below. For each target the first
existing candidate is used, so fonts without italics or without some weights still work.
Only use fonts whose license allows modification (e.g. SIL OFL).
"""
import argparse
import sys
from pathlib import Path
from fontTools.ttLib import TTFont

# registry family, legacy family, legacy style, typographic subfamily, weight, source candidates
MAP = [
    ("Segoe UI",                  "Segoe UI",           "Regular",     None,               400, ["Regular"]),
    ("Segoe UI Bold",             "Segoe UI",           "Bold",        None,               700, ["Bold"]),
    ("Segoe UI Italic",           "Segoe UI",           "Italic",      None,               400, ["Italic", "Regular"]),
    ("Segoe UI Bold Italic",      "Segoe UI",           "Bold Italic", None,               700, ["BoldItalic", "Bold"]),
    ("Segoe UI Light",            "Segoe UI Light",     "Regular",     "Light",            300, ["Light", "ExtraLight", "Regular"]),
    ("Segoe UI Light Italic",     "Segoe UI Light",     "Italic",      "Light Italic",     300, ["LightItalic", "Light", "Italic", "Regular"]),
    ("Segoe UI Semilight",        "Segoe UI Semilight", "Regular",     "Semilight",        350, ["SemiLight", "Regular"]),
    ("Segoe UI Semilight Italic", "Segoe UI Semilight", "Italic",      "Semilight Italic", 350, ["SemiLightItalic", "Italic", "Regular"]),
    ("Segoe UI Semibold",         "Segoe UI Semibold",  "Regular",     "Semibold",         600, ["SemiBold", "Medium", "Bold"]),
    ("Segoe UI Semibold Italic",  "Segoe UI Semibold",  "Italic",      "Semibold Italic",  600, ["SemiBoldItalic", "SemiBold", "Medium", "BoldItalic", "Bold"]),
    ("Segoe UI Black",            "Segoe UI Black",     "Regular",     "Black",            900, ["Black", "Heavy", "Bold"]),
    ("Segoe UI Black Italic",     "Segoe UI Black",     "Italic",      "Black Italic",     900, ["BlackItalic", "Black", "BoldItalic", "Bold"]),
]
RENAMED_IDS = {1, 2, 3, 4, 6, 16, 17, 21, 22}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src", type=Path)
    ap.add_argument("out", type=Path)
    ap.add_argument("--pattern", default="SarasaUiTC-{style}.ttf")
    ap.add_argument("--tag", default="Sarasa-UI")
    a = ap.parse_args()
    a.out.mkdir(parents=True, exist_ok=True)

    for reg_name, family, style, typo_sub, weight, candidates in MAP:
        src = next((a.src / a.pattern.format(style=c) for c in candidates
                    if (a.src / a.pattern.format(style=c)).exists()), None)
        if src is None:
            sys.exit(f"No source for {reg_name}; tried {candidates} with pattern {a.pattern}")

        font = TTFont(src)
        name = font["name"]
        # Drop localized/old naming so Windows only sees the new English names.
        name.names = [n for n in name.names if n.nameID not in RENAMED_IDS]

        ps = reg_name.replace("Segoe UI", "SegoeUI").replace(" ", "-", 1).replace(" ", "")
        records = {1: family, 2: style, 3: f"{reg_name};{a.tag}", 4: reg_name, 6: ps}
        if typo_sub:
            records[16] = "Segoe UI"
            records[17] = typo_sub
        for nid, text in records.items():
            name.setName(text, nid, 3, 1, 0x409)  # Windows, Unicode BMP, en-US
            name.setName(text, nid, 1, 0, 0)      # Mac Roman, English

        italic = "Italic" in style
        bold = style.startswith("Bold")
        os2 = font["OS/2"]
        os2.usWeightClass = weight
        sel = os2.fsSelection & ~0b1100001  # clear ITALIC(0), BOLD(5), REGULAR(6)
        if italic:
            sel |= 1 << 0
        if bold:
            sel |= 1 << 5
        if not italic and not bold:
            sel |= 1 << 6
        os2.fsSelection = sel
        font["head"].macStyle = (1 if bold else 0) | (2 if italic else 0)

        out = a.out / f"SegoeUI-Sarasa-{reg_name.replace('Segoe UI', '').replace(' ', '') or 'Regular'}.ttf"
        font.save(out)
        print(f"{reg_name:28} <- {src.name:34} -> {out.name}")


if __name__ == "__main__":
    main()
