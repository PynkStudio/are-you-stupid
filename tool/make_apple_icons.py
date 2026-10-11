"""Generate the iOS/iPadOS and macOS app-icon catalogs from icon.png.

Run from the repository root:

    python3 tool/make_apple_icons.py

The source is an opaque, square, full-bleed master. iOS and iPadOS receive
that artwork directly because the OS applies its own mask. macOS receives a
platform-style rounded tile on transparency, without a baked-in light rim.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "icon.png"
IOS_DIR = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
MAC_DIRS = (
    ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset",
)


def contain_for_mac(source: Image.Image, size: int) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # Apple's traditional 1024 px macOS icon grid uses an 824 px body.
    body_size = max(1, round(size * 824 / 1024))
    margin = (size - body_size) // 2
    radius = round(body_size * 0.22)

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_mask = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(shadow_mask).rounded_rectangle(
        (margin, margin + round(size * 0.018), margin + body_size, margin + body_size),
        radius=radius,
        fill=150,
    )
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(max(1, round(size * 0.018))))
    shadow.putalpha(shadow_mask)
    canvas.alpha_composite(shadow)

    tile = source.resize((body_size, body_size), Image.Resampling.LANCZOS)
    mask = Image.new("L", (body_size, body_size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, body_size - 1, body_size - 1), radius=radius, fill=255
    )
    tile.putalpha(mask)
    canvas.alpha_composite(tile, (margin, margin))
    return canvas


def main() -> None:
    source = Image.open(MASTER).convert("RGB")
    if source.width != source.height:
        raise ValueError("icon.png must be square")

    for path in IOS_DIR.glob("*.png"):
        with Image.open(path) as existing:
            size = existing.width
        source.resize((size, size), Image.Resampling.LANCZOS).save(path)

    for directory in MAC_DIRS:
        for path in directory.glob("*.png"):
            with Image.open(path) as existing:
                size = existing.width
            contain_for_mac(source, size).save(path)

    print("Regenerated iPhone, iPad, and both macOS app-icon catalogs.")


if __name__ == "__main__":
    main()
