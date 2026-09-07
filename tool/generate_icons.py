"""Ginagawa ang buong hanay ng icon ng ShuttleQueue mula sa isang guhit.

Patakbuhin:  python tool/generate_icons.py

Bakit script at hindi naka-check-in na PNG lang? Para kapag inayos ang marka,
isang utos lang at pare-pareho ulit ang lahat ng laki — at nakasulat ang
hugis sa halip na nakabaon sa isang binary na walang makakabasa.

ANG MARKA: isang shuttlecock na ang tatlong balahibo ay pataas ang haba —
shuttlecock at pila sa iisang hugis. Iyon mismo ang app: badminton, nakapila.
"""

from PIL import Image, ImageDraw

# Ang mga kulay ng app. Pareho sa theme at sa splash ng index.html.
GREEN = (27, 94, 32)       # #1B5E20 — primary
CREAM = (244, 247, 242)    # #F4F7F2 — surface

SS = 4  # supersample: iginuguhit nang 4x tapos iniliit — dito nanggagaling
        # ang makinis na gilid, dahil walang antialiasing ang ImageDraw.


def _blade(draw, cx, y_bottom, y_top, half_bottom, half_top, fill):
    """Isang balahibo: tapered na quad, malapad sa itaas gaya ng totoo."""
    draw.polygon(
        [
            (cx - half_bottom, y_bottom),
            (cx + half_bottom, y_bottom),
            (cx + half_top, y_top),
            (cx - half_top, y_top),
        ],
        fill=fill,
    )


def draw_mark(size, fg, scale=1.0, tilt=-10):
    """Ang shuttlecock lang, sa transparent na layer, handang i-composite."""
    n = size * SS
    layer = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    u = n * scale          # laki ng marka sa loob ng canvas
    ox = (n - u) / 2       # offset para nasa gitna
    oy = (n - u) / 2

    def X(v):
        return ox + v * u

    def Y(v):
        return oy + v * u

    # --- Ang tapon (cork): bilog, ito ang nagpapakilala agad na shuttlecock.
    r = 0.158
    cy = 0.755
    d.ellipse([X(0.5 - r), Y(cy - r), X(0.5 + r), Y(cy + r)], fill=fg)

    # --- Tatlong balahibo, PANTAY at simetriko.
    #
    # Sinubukan ko munang pataasin nang sunod-sunod ang balahibo para
    # magmukha ring pila. Mali iyon: ang shuttlecock ay nakikilala sa
    # simetrya nito, at ang pagkiling ay nagpapamukhang korona o tilamsik.
    # Isang bagay lang ang hinahabol ng markang ito — agad na makilala —
    # at ang natitira ay tinanggal.
    # Ang palda ay MAS MALAPAD KAYSA MATAAS — iyon ang totoong sukat ng
    # shuttlecock. Noong mahaba at manipis ang balahibo, trident ang lumabas.
    # Magkadikit sila sa ibaba (isang leeg) at may makikitit na hiwa lang sa
    # itaas: palda na may siwang, hindi tatlong tulis.
    y_bot = Y(0.640)
    y_top = Y(0.280)

    for t in (-1, 0, 1):
        bx = 0.5 + t * 0.052   # sa ibaba: magkadikit, buo ang leeg
        tx = 0.5 + t * 0.238   # sa itaas: paypay palabas
        d.polygon(
            [
                (X(bx - 0.052), y_bot),
                (X(bx + 0.052), y_bot),
                (X(tx + 0.096), y_top),
                (X(tx - 0.096), y_top),
            ],
            fill=fg,
        )

    if tilt:
        layer = layer.rotate(tilt, resample=Image.BICUBIC, center=(n / 2, n * 0.62))

    return layer


def tile(size, *, radius_ratio, mark_scale, bg=GREEN, fg=CREAM):
    """Buong icon: kulay na tile + marka sa ibabaw."""
    n = size * SS
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    if radius_ratio <= 0:
        d.rectangle([0, 0, n, n], fill=bg)
    else:
        d.rounded_rectangle([0, 0, n - 1, n - 1], radius=n * radius_ratio, fill=bg)

    img.alpha_composite(draw_mark(size, fg, scale=mark_scale))
    return img.resize((size, size), Image.LANCZOS)


def main():
    import os

    root = os.path.join(os.path.dirname(__file__), "..")
    web = os.path.join(root, "web")
    icons = os.path.join(web, "icons")

    # Favicon: maliit, kaya malaki ang marka at mababaw ang rounding —
    # sa 16px, ang sobrang bilog ay nagiging mantsa.
    tile(64, radius_ratio=0.18, mark_scale=0.80).save(
        os.path.join(web, "favicon.png")
    )

    # Home-screen icons.
    for s in (192, 512):
        tile(s, radius_ratio=0.22, mark_scale=0.72).save(
            os.path.join(icons, f"Icon-{s}.png")
        )

    # Maskable: puno ang tile (gugupitin ito ng Android sa sarili nitong
    # hugis), at nasa loob ng ligtas na bilog ang marka — kaya mas maliit.
    for s in (192, 512):
        tile(s, radius_ratio=0, mark_scale=0.56).save(
            os.path.join(icons, f"Icon-maskable-{s}.png")
        )

    # Android launcher. Kung wala ito, ang nakikita sa home screen ng
    # telepono ay ang asul na logo ng Flutter — at doon mismo titingin
    # ang QM tuwing gabi ng laro.
    android = os.path.join(root, "android", "app", "src", "main", "res")
    for bucket, s in (
        ("mdpi", 48),
        ("hdpi", 72),
        ("xhdpi", 96),
        ("xxhdpi", 144),
        ("xxxhdpi", 192),
    ):
        target = os.path.join(android, f"mipmap-{bucket}", "ic_launcher.png")
        if os.path.isdir(os.path.dirname(target)):
            tile(s, radius_ratio=0.22, mark_scale=0.72).save(target)

    # Preview: sabay-sabay ang mga laki para makita agad kung nabubulok
    # ang hugis kapag maliit na.
    sizes = (128, 64, 32, 16)
    pad, gap = 18, 18
    w = pad * 2 + sum(sizes) + gap * (len(sizes) - 1)
    row_h = 128 + pad * 2
    preview = Image.new("RGBA", (w, row_h * 2), (255, 255, 255, 255))
    ImageDraw.Draw(preview).rectangle(
        [0, row_h, w, row_h * 2], fill=(32, 33, 36, 255)
    )
    for row in (0, 1):
        x = pad
        for sz in sizes:
            y = row * row_h + pad + (128 - sz) // 2
            preview.alpha_composite(
                tile(sz, radius_ratio=0.20, mark_scale=0.78), (x, y)
            )
            x += sz + gap
    preview.save(os.path.join(root, "build", "icon_preview.png"))
    print("isinulat ang mga icon + build/icon_preview.png")


if __name__ == "__main__":
    main()
