"""App Store screenshots for the Stupid Streak iMessage app.

Same visual language as generate_store_screenshots.py (it reuses its
helpers), built from real captures of the extension running in Messages on
the iPhone 17 Pro Max simulator (build/screenshots/imessage/). Run from the
repository root:

    python3 store_assets/generate_imessage_screenshots.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

import generate_store_screenshots as base

SHOTS = base.ROOT / "build" / "screenshots" / "imessage"
OUT = base.OUT

# (capture, eyebrow, headline, pill, accent, crop_bottom)
# crop_bottom trims the empty lower half of the expanded extension so the
# real UI fills the card instead of a black void.
SLIDES = [
    ("00_chat_card.png", "STUPID STREAK.", "A 1V1 IN MESSAGES.", "DARE A FRIEND IN ANY CHAT", base.YELLOW, 1500),
    ("01_start.png", "SAME TRAPS.", "SAME ORDER.", "THREE INCREASINGLY STUPID ROUNDS", base.RED, None),
    ("02_challenge.png", "LOOKS EASY.", "THAT'S THE TRAP.", "ONE INSTRUCTION. A FEW SECONDS.", base.GREEN, 1250),
    ("03_fail.png", "FAILED?", "THE CHAT WILL KNOW.", "EVERY FAIL EXPLAINED IN ONE LINE", base.RED, 1250),
    ("04_result.png", "SEND IT.", "THEIR TURN. PROBABLY.", "YOUR SCORE STAYS HIDDEN UNTIL THEY PLAY", base.BLUE, 820),
]


def capture(name: str, crop_bottom: int | None) -> Path:
    src = SHOTS / name
    if not crop_bottom:
        return src
    tmp = base.ROOT / "build" / "screenshots" / "raw" / f"crop_{name}"
    Image.open(src).crop((0, 0, 1320, crop_bottom)).save(tmp)
    return tmp


def render(size, folder, margin, eyebrow_size, head_max, pill_scale):
    w, h = size
    for i, (name, eyebrow, headline, detail, accent, crop) in enumerate(SLIDES):
        image = base.campaign_background(size, i, accent)
        draw = ImageDraw.Draw(image)
        draw.text((margin, round(h * 0.036)), f"0{i + 1}  /  0{len(SLIDES)}", font=base.font(round(eyebrow_size * 0.6)), fill=base.MUTED)
        draw.text((margin, round(h * 0.062)), eyebrow, font=base.font(eyebrow_size), fill=accent)
        draw.text((margin, round(h * 0.086)), headline, font=base.fit_text(draw, headline, head_max, round(eyebrow_size * 2.6)), fill=base.INK)
        base.pill(draw, (margin, round(h * 0.152)), detail, accent, pill_scale)
        src = capture(name, crop)
        shot = Image.open(src)
        top = round(h * 0.235)
        max_w, max_h = w - 2 * margin, h - top - round(h * 0.05)
        ratio = min(max_w / shot.width, max_h / shot.height)
        cw, ch = round(shot.width * ratio), round(shot.height * ratio)
        x0 = (w - cw) // 2
        y0 = top + (max_h - ch) // 2  # short crops sit centred, not stuck to the header
        base.screenshot_card(image, src, (x0, y0, x0 + cw, y0 + ch), round(min(w, h) * 0.055))
        base.save(image, OUT / folder / f"{i + 1:02d}.png")


if __name__ == "__main__":
    render((1320, 2868), "imessage-iphone-6.9", 88, 42, 1135, 1.0)
    render((2064, 2752), "imessage-ipad-13", 132, 50, 1780, 1.22)
    print(f"Wrote iMessage screenshots to {OUT}")
