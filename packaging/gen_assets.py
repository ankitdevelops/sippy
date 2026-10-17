"""Generate Sippy artwork: droplet app icon + styled DMG background.

Outputs (under packaging/):
  AppIcon.icns      - droplet icon for the .app
  dmg_bg.png        - 640x400 installer window background
Usage: python3 packaging/gen_assets.py
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
S = 1024  # master icon size


def droplet_mask(size):
    """White droplet silhouette on black (L)."""
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    cx = size // 2
    k = size / 1024
    # Bulb: circle centered a bit below middle.
    r = int(240 * k)
    cxx, cyy = cx, int(640 * k)
    d.ellipse([cxx - r, cyy - r, cxx + r, cyy + r], fill=255)
    # Tip: triangle from apex down into the bulb.
    apex = (cx, int(130 * k))
    base_y = int(570 * k)
    half = int(215 * k)
    d.polygon([apex, (cx + half, base_y), (cx - half, base_y)], fill=255)
    return m


def make_droplet():
    mask = droplet_mask(S)
    # Vertical gradient: icy light blue -> deep water blue.
    stops = [(143, 216, 255), (47, 169, 232), (11, 111, 174)]
    grad = Image.new("RGB", (1, S))
    gp = grad.load()
    for y in range(S):
        t = y / (S - 1) * (len(stops) - 1)
        i = min(int(t), len(stops) - 2)
        f = t - i
        gp[0, y] = tuple(int(stops[i][c] + (stops[i + 1][c] - stops[i][c]) * f) for c in range(3))
    grad = grad.resize((S, S))
    icon = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    icon.paste(Image.merge("RGBA", (*grad.split(), mask)), (0, 0))

    # Soft depth shade at the bottom.
    shade = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ds = ImageDraw.Draw(shade)
    ds.ellipse([S // 2 - 190, S - 420, S // 2 + 190, S - 60], fill=(4, 60, 110, 110))
    shade = shade.filter(ImageFilter.GaussianBlur(40))
    icon = Image.alpha_composite(icon, shade)

    # Glossy highlight, upper left, slightly tilted.
    hi = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dh = ImageDraw.Draw(hi)
    dh.ellipse([0, 0, 150, 260], fill=(255, 255, 255, 175))
    hi = hi.filter(ImageFilter.GaussianBlur(18)).rotate(-18, resample=Image.BICUBIC, center=(75, 130))
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    layer.alpha_composite(hi, (300, 330))
    # Clip highlight to droplet shape.
    empty = Image.new("L", (S, S), 0)
    layer.putalpha(Image.composite(layer.split()[3], empty, mask))
    icon = Image.alpha_composite(icon, layer)
    return icon


def make_iconset(icon):
    iconset = os.path.join(HERE, "AppIcon.iconset")
    os.makedirs(iconset, exist_ok=True)
    for size in (16, 32, 64, 128, 256, 512):
        for scale in (1, 2) if size <= 512 else (1,):
            px = size * scale
            if px > 1024:
                continue
            name = f"icon_{size}x{size}{'@2x' if scale == 2 else ''}.png"
            icon.resize((px, px), Image.LANCZOS).save(os.path.join(iconset, name))
    return iconset


def make_dmg_bg():
    W, H = 640, 400
    bg = Image.new("RGB", (W, H))
    bp = bg.load()
    top, bot = (52, 52, 56), (22, 22, 25)
    for y in range(H):
        f = y / (H - 1)
        bp_top = tuple(int(top[c] + (bot[c] - top[c]) * f) for c in range(3))
        for x in range(W):
            bp[x, y] = bp_top
    d = ImageDraw.Draw(bg, "RGBA")
    # Soft blue glow behind the app icon (left slot).
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dg = ImageDraw.Draw(glow)
    dg.ellipse([40, 60, 300, 320], fill=(47, 169, 232, 70))
    bg = Image.alpha_composite(bg.convert("RGBA"), glow.filter(ImageFilter.GaussianBlur(60))).convert("RGB")
    d = ImageDraw.Draw(bg)
    try:
        f_title = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 30)
        f_sub = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)
    except Exception:
        f_title = f_sub = ImageFont.load_default()
    t = "Install Sippy"
    bb = d.textbbox((0, 0), t, font=f_title)
    d.text(((W - (bb[2] - bb[0])) / 2, 22), t, font=f_title, fill=(245, 245, 247))
    s = "Drag Sippy into Applications"
    sb = d.textbbox((0, 0), s, font=f_sub)
    d.text(((W - (sb[2] - sb[0])) / 2, 66), s, font=f_sub, fill=(160, 160, 165))
    # Dashed arrow lane between the two icon slots.
    for x in range(235, 405, 14):
        d.line([x, 215, x + 8, 215], fill=(120, 120, 128), width=3)
    d.polygon([(405, 205), (405, 225), (422, 215)], fill=(120, 120, 128))
    out = os.path.join(HERE, "dmg_bg.png")
    bg.save(out)
    return out


if __name__ == "__main__":
    icon = make_droplet()
    iconset = make_iconset(icon)
    print("iconset:", iconset)
    print("dmg bg:", make_dmg_bg())
