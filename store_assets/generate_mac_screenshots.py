"""Mac App Store screenshots (2880 × 1800) built from real window captures.

The Mac app is the full game (single player) plus the party host board, so
the set shows both. Captures live in build/screenshots/mac/: the Release-
equivalent Flutter macOS app driven through its own UI in English, windows
captured with `screencapture -o -l <window>` (home, challenge, fail,
gameover, chooser). The HOST ON THIS MAC board slides use the 2880 × 1800
board renders in build/screenshots/board-v3/ (AYSHostUI snapshot test,
`testStoreCaptures`), the same SwiftUI views the window shows. Reuses the
helpers of generate_store_screenshots.py. Run from the repository root:

    python3 store_assets/generate_mac_screenshots.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

import generate_store_screenshots as base

SHOTS = base.ROOT / "build" / "screenshots" / "mac"
BOARD = base.BOARD_SHOTS
OUT = base.OUT / "mac"
SIZE = (2880, 1800)

# (eyebrow, headline, label, accent, captures)
SLIDES = [
    ("PLAY SOLO ON YOUR MAC", "LOOKS EASY. ISN'T.", "DOZENS OF STUPIDLY SIMPLE TRAPS", base.GREEN, ["home.png", "challenge.png"]),
    ("FAIL FAST. RETRY FASTER.", "YOU HAD ONE JOB.", "EVERY FAIL EXPLAINED IN ONE LINE", base.RED, ["fail.png", "gameover.png"]),
    ("TWO WAYS TO PLAY", "SOLO OR PARTY HOST.", "PLAY ON THIS MAC  •  HOST ON THIS MAC", base.YELLOW, ["chooser.png"]),
    ("PARTY MODE", "YOUR MAC IS THE GAME BOARD.", "PHONES BECOME CONTROLLERS  •  UP TO 16", base.BLUE, ["board:mac-lobby-full.png"]),
    ("PARTY MODE", "EVERY FAIL GETS NAMED.", "ON THE BIG SCREEN. IN FRONT OF EVERYONE.", base.RED, ["board:mac-results-battle.png"]),
    ("THE FINAL", "ONE WINNER. EVERYONE ELSE: STUPID.", "AWARDS FOR THE FASTEST AND THE WORST", base.YELLOW, ["board:mac-final-winner.png"]),
]


def paste_window(canvas: Image.Image, source: Path, box: tuple[int, int, int, int]) -> None:
    """Fit a captured window (alpha-cornered) into box, centred, with a soft shadow."""
    x0, y0, x1, y1 = box
    shot = Image.open(source).convert("RGBA")
    ratio = min((x1 - x0) / shot.width, (y1 - y0) / shot.height)
    shot = shot.resize((round(shot.width * ratio), round(shot.height * ratio)), Image.Resampling.LANCZOS)
    if shot.getextrema()[3][0] == 255:
        # A flat board render has no window corners of its own: round them.
        mask = Image.new("L", shot.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, shot.width, shot.height), radius=28, fill=255)
        shot.putalpha(mask)
    sx = x0 + ((x1 - x0) - shot.width) // 2
    sy = y0 + ((y1 - y0) - shot.height) // 2
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (sx - 10, sy + 10, sx + shot.width + 10, sy + shot.height + 40), radius=40, fill=(0, 0, 0, 190)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(40))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(shot, (sx, sy))


def slide(index: int, eyebrow: str, headline: str, label: str, accent: str, captures: list[str]) -> None:
    w, h = SIZE
    canvas = base.background(SIZE, accent).convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    margin = 150
    draw.text((margin, 110), eyebrow, font=base.font(52), fill=accent)
    headline_font = base.fit_text(draw, headline, w - 2 * margin, 150)
    draw.text((margin, 180), headline, font=headline_font, fill=base.INK)
    # Plain accent line, no pill badge (matches the board's no-pill chrome).
    draw.text((margin, 380), label, font=base.font(48), fill=accent)

    top, bottom = 520, h - 90
    gap = 90
    slot = (w - 2 * margin - gap * (len(captures) - 1)) // len(captures)
    for i, name in enumerate(captures):
        x = margin + i * (slot + gap)
        source = BOARD / name.removeprefix("board:") if name.startswith("board:") else SHOTS / name
        paste_window(canvas, source, (x, top, x + slot, bottom))
    base.save(canvas, OUT / f"{index:02d}.png")


if __name__ == "__main__":
    for old in OUT.glob("*.png"):
        old.unlink()
    for index, spec in enumerate(SLIDES, 1):
        slide(index, *spec)
    print(f"Wrote {len(SLIDES)} Mac screenshots to {OUT}")
