"""Bumubuo ng mga font file na nasa `assets/fonts/`.

Bakit may script para dito: hindi kami gumagamit ng `google_fonts` package
dahil kumukuha yun sa network sa unang takbo — at ang buong punto ng app na
ito ay tumatakbo nang walang internet sa loob ng apat na oras. Kaya nakasilid
ang mga font sa repo bilang asset.

Dalawa ang pamilya, dalawa ang boses:

  Inter    — lahat ng babasahin nang malapitan: label, listahan, pera,
             pangalan. May `tnum` kaya hindi gumagalaw ang hanay ng numero
             habang nagbabago ang bilang.
  Archivo  — ang boses ng scoreboard: numero ng court, malalaking bilang,
             pamagat. Kinukuha namin ito sa `wdth` 88 — bahagyang makitid,
             kaya kasya ang mahabang pangalan sa TV sa dulo ng gym nang
             hindi nagmumukhang naipit.

Pareho silang may piso (U+20B1) at ñ. Sinuri ito ng script bago mag-save,
dahil ang isang nawawalang glyph ay lumalabas na kahon sa bill ng QM.

Ang orihinal na Inter ay isang variable font (876 KB). Hindi kayang i-animate
ng Flutter ang `fontWeight` sa variable font nang walang `fontVariations` sa
bawat TextStyle, kaya kinukuha namin ang mga static instance dito, tapos
sinusuklay para sa mga titik na talagang ginagamit — Latin, tilde-n, at ang
piso (U+20B1). Mula 876 KB, nagiging mga ~80 KB na file.

Patakbuhin kapag kailangang i-update ang bersyon ng font:

    python tool/build_fonts.py

Kailangan: pip install fonttools brotli
"""

from __future__ import annotations

import io
import sys
import urllib.parse
import urllib.request
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

RAW = "https://raw.githubusercontent.com/google/fonts/main/"

OUT = Path(__file__).resolve().parent.parent / "assets" / "fonts"

# Ang mga titik na pinapanatili. Lahat ng wala dito ay tinatanggal.
UNICODES = ",".join(
    [
        "U+0020-007E",  # basic latin
        "U+00A0-00FF",  # n-tilde, mga patinig na may tuldik
        "U+0100-017F",  # latin extended-A
        "U+2000-206F",  # gitling, panipi, ellipsis, bullet
        "U+20A0-20BF",  # piso (U+20B1) at kasamahan nitong pera
        "U+2190-21FF",  # mga arrow
        "U+2212",  # minus na pantay ang lapad sa plus
    ]
)

# family, source path sa google/fonts, at kung anong weight ang kailangan.
SOURCES = [
    {
        "family": "Inter",
        "path": "ofl/inter/Inter[opsz,wght].ttf",
        # opsz 16 ang pinipili: ito ang laki ng katawan ng teksto sa app.
        "pin": {"opsz": 16},
        # Walang 700: ang mas mabigat pa sa 600 ay trabaho na ng Archivo.
        "weights": [400, 500, 600],
    },
    {
        "family": "Archivo",
        "path": "ofl/archivo/Archivo[wdth,wght].ttf",
        "pin": {"wdth": 88},
        "weights": [600, 800],
    },
]


def fetch(path: str) -> bytes:
    url = RAW + urllib.parse.quote(path, safe=":/")
    with urllib.request.urlopen(url) as response:  # noqa: S310 - kilalang host
        if response.status != 200:
            raise RuntimeError(f"{response.status} para sa {url}")
        return response.read()


def trim(font: TTFont, out_path: Path) -> int:
    options = subset.Options()
    options.layout_features = ["*"]  # kasama ang tnum: hindi gumagalaw ang pera
    options.name_IDs = ["*"]
    options.notdef_outline = True
    options.recalc_bounds = True
    options.drop_tables += ["DSIG"]

    subsetter = subset.Subsetter(options=options)
    subsetter.populate(unicodes=subset.parse_unicodes(UNICODES))
    subsetter.subset(font)
    font.save(out_path)
    return out_path.stat().st_size


def peso_present(font: TTFont) -> bool:
    return any(0x20B1 in table.cmap for table in font["cmap"].tables)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    total = 0

    missing = []

    for source in SOURCES:
        family = source["family"]
        raw = fetch(source["path"])

        for weight in source["weights"]:
            axes = dict(source.get("pin", {}))
            axes["wght"] = weight
            static = instancer.instantiateVariableFont(
                TTFont(io.BytesIO(raw)), axes, updateFontNames=False, inplace=True
            )
            out_path = OUT / f"{family}-{weight}.ttf"
            if not peso_present(static):
                missing.append(out_path.name)
            size = trim(static, out_path)
            total += size
            print(f"  {out_path.name:28} {size // 1024:4} KB")

    print(f"  {'kabuuan':28} {total // 1024:4} KB")

    if missing:
        # Mas mabuting pumalya dito kaysa lumabas na kahon ang ₱ sa bill.
        print(f"walang piso sign: {', '.join(missing)}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
