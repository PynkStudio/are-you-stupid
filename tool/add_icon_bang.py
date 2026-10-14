"""Turn the icon artwork's "ARE YOU STUPID?" into "ARE YOU STUPID?!".

The original icon.png (kept as icon_source.png) only has the "?". The name is
always written with "?!" (docs/Gameplay/Game Design Pillars.md), so this
shrinks the artwork a little, shifts it left and draws a matching "!" — the
"?"'s yellow gradient, thick black outline and soft dark halo — after it.
Run from the repo root, then regenerate the platform icons:

    python3 tool/add_icon_bang.py
    python3 tool/make_apple_icons.py && python3 tool/make_tv_icons.py
"""
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "icon_source.png"
OUT = ROOT / "icon.png"

BG = (10, 10, 10)
SCALE = 0.9
SHIFT_X = -66
SS = 4  # supersampling for smooth edges


def bang_mask(size: int) -> Image.Image:
    """The "!" silhouette (stem + dot) at SS resolution, upright."""
    w, h = 150 * SS, 300 * SS
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    # Tapered, rounded stem: wide at the top like the chunky display font.
    top_w, bottom_w = 122 * SS, 80 * SS
    stem_h = 160 * SS
    cx = w // 2
    d.polygon(
        [
            (cx - top_w // 2, 28 * SS),
            (cx + top_w // 2, 28 * SS),
            (cx + bottom_w // 2, stem_h),
            (cx - bottom_w // 2, stem_h),
        ],
        fill=255,
    )
    d.ellipse((cx - top_w // 2, 0, cx + top_w // 2, 60 * SS), fill=255)
    d.ellipse((cx - bottom_w // 2, stem_h - 24 * SS, cx + bottom_w // 2, stem_h + 24 * SS), fill=255)
    dot = 92 * SS
    d.ellipse((cx - dot // 2, h - dot - 6 * SS, cx + dot // 2, h - 6 * SS), fill=255)
    return mask


def dilate(mask: Image.Image, px: int) -> Image.Image:
    return mask.filter(ImageFilter.MaxFilter(px * 2 + 1)) if px < 12 else mask.filter(
        ImageFilter.GaussianBlur(px / 2)
    ).point(lambda v: 255 if v > 8 else 0)


def main() -> None:
    src = Image.open(SOURCE).convert("RGB")
    n = src.width
    canvas = Image.new("RGB", (n, n), BG)
    small = src.resize((round(n * SCALE), round(n * SCALE)), Image.Resampling.LANCZOS)
    off = round((n - small.width) / 2)
    canvas.paste(small, (off + SHIFT_X, off))
    # Fill the strip the shift uncovered on the right with background.
    ImageDraw.Draw(canvas).rectangle((off + SHIFT_X + small.width, 0, n, n), fill=BG)

    shape = bang_mask(n)
    outline = dilate(shape, 15 * SS)
    halo = outline.filter(ImageFilter.GaussianBlur(10 * SS))

    w, h = shape.size
    # Vertical yellow gradient sampled from the "?" (top → bottom).
    grad = Image.new("RGB", (w, h))
    gd = ImageDraw.Draw(grad)
    top, bottom = (255, 236, 6), (253, 182, 1)
    for y in range(h):
        t = y / (h - 1)
        gd.line([(0, y), (w, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    # Soft top-left highlight, like the glossy letters.
    hl = shape.filter(ImageFilter.GaussianBlur(14 * SS))
    hl = ImageChops.offset(hl, -8 * SS, -10 * SS)
    hl = ImageChops.multiply(hl, shape).point(lambda v: v * 0.35)

    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    layer.paste((40, 40, 42, 255), (0, 0), halo.point(lambda v: v * 0.55))
    layer.paste((0, 0, 0, 255), (0, 0), outline)
    layer.paste(grad, (0, 0), shape)
    # Bevel: a deeper orange rim on the lower-right edge, like the letters.
    inner = ImageChops.offset(shape, -7 * SS, -9 * SS)
    rim = ImageChops.subtract(shape, inner).filter(ImageFilter.GaussianBlur(2 * SS))
    layer.paste((236, 150, 0), (0, 0), rim)
    layer.paste((255, 250, 210), (0, 0), hl.convert("L"))

    # Tilt with the lettering and place it right after the "?".
    pad = 20 * SS
    big = Image.new("RGBA", (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
    big.paste(layer, (pad, pad))
    big = big.rotate(-9, resample=Image.Resampling.BICUBIC, expand=True)
    big = big.resize((round(big.width * 1.06 / SS), round(big.height * 1.06 / SS)), Image.Resampling.LANCZOS)
    x = 1006
    y = 572
    canvas = canvas.convert("RGBA")
    canvas.alpha_composite(big, (x, y))
    canvas.convert("RGB").save(OUT, "PNG", optimize=True)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
