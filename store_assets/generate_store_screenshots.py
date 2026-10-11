#!/usr/bin/env python3
"""Build App Store- and Google Play-ready marketing screenshots from real captured UI."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "store_assets" / "output"
PHONE = ROOT / "build" / "screenshots" / "iphone69"
TV = ROOT / "build" / "screenshots" / "raw" / "tv_1.png"

INK = "#F7F7FA"
MUTED = "#9B9BA8"
BG = "#08080D"
RED = "#FF3B44"
GREEN = "#23D36B"
YELLOW = "#FFD60A"
BLUE = "#3384F5"
PURPLE = "#160329"

FONT_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_REG = "/System/Library/Fonts/Supplemental/Arial.ttf"


def font(size: int, bold: bool = True) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_BOLD if bold else FONT_REG, size)


def fit_text(draw: ImageDraw.ImageDraw, text: str, width: int, start: int) -> ImageFont.FreeTypeFont:
    size = start
    while size > 24:
        candidate = font(size)
        if draw.textbbox((0, 0), text, font=candidate)[2] <= width:
            return candidate
        size -= 2
    return font(size)


def background(size: tuple[int, int], accent: str) -> Image.Image:
    image = Image.new("RGB", size, BG)
    draw = ImageDraw.Draw(image, "RGBA")
    w, h = size
    draw.ellipse((-w // 3, -w // 4, w // 2, w // 2), fill=accent + "26")
    draw.ellipse((w * 2 // 3, h * 2 // 3, w * 5 // 4, h + w // 3), fill=accent + "20")
    draw.rectangle((0, h - max(18, h // 100), w, h), fill=accent)
    return image


def rounded_screenshot(base: Image.Image, source: Path, box: tuple[int, int, int, int], radius: int) -> None:
    x0, y0, x1, y1 = box
    shot = Image.open(source).convert("RGB")
    target_w, target_h = x1 - x0, y1 - y0
    ratio = min(target_w / shot.width, target_h / shot.height)
    shot = shot.resize((round(shot.width * ratio), round(shot.height * ratio)), Image.Resampling.LANCZOS)
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sx = x0 + (target_w - shot.width) // 2
    sy = y0 + (target_h - shot.height) // 2
    sd.rounded_rectangle((sx - 18, sy - 18, sx + shot.width + 18, sy + shot.height + 18), radius=radius + 18, fill=(0, 0, 0, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    base.paste(shadow, (0, 0), shadow)
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, shot.width, shot.height), radius=radius, fill=255)
    base.paste(shot, (sx, sy), mask)


def add_header(base: Image.Image, eyebrow: str, headline: str, accent: str, margin: int, y: int, max_width: int) -> None:
    draw = ImageDraw.Draw(base)
    draw.text((margin, y), eyebrow, font=font(max(24, base.width // 48)), fill=accent)
    headline_font = fit_text(draw, headline, max_width, max(58, base.width // 10))
    draw.text((margin, y + max(50, base.width // 25)), headline, font=headline_font, fill=INK)


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGB").save(path, "PNG", optimize=True)


PHONE_SLIDES = [
    ("01_home.png", "ONE JOB.", "DON'T SCREW IT UP.", "ONE-HANDED  •  OFFLINE", YELLOW),
    ("02_challenge_tapgreen.png", "LOOKS EASY.", "UNTIL IT ISN'T.", "REACTION  •  COLORS  •  TIMING", GREEN),
    ("03_challenge_trick.png", "READ FAST.", "THINK FASTER.", "DOZENS OF STUPIDLY SIMPLE TRAPS", BLUE),
    ("03b_wrong_flash.png", "FAILED THAT?", "OF COURSE YOU DID.", "INSTANT FAILS. ZERO DOWNTIME.", RED),
    ("05_gameover.png", "YOUR SCORE.", "YOUR SHAME.", "BEAT YOUR BEST. DARE YOUR FRIENDS.", YELLOW),
    ("07_lobby.png", "PARTY MODE.", "PHONES ARE CONTROLLERS.", "UP TO 16 WITH PARTY PACK", BLUE),
]


def campaign_background(size: tuple[int, int], index: int, accent: str) -> Image.Image:
    """A continuous ribbon makes adjacent screenshots read as one carousel."""
    w, h = size
    image = Image.new("RGB", size, BG)
    draw = ImageDraw.Draw(image, "RGBA")
    offset = -index * w
    total = w * len(PHONE_SLIDES)
    draw.ellipse((offset - w, -w // 2, offset + total + w, w * 2), outline=accent + "32", width=max(20, w // 40))
    for x in range(-w, total + w, w // 2):
        px = offset + x
        draw.ellipse((px, h * 3 // 4, px + w // 2, h + w // 3), fill=accent + "18")
    draw.rectangle((0, 0, max(14, w // 85), h), fill=accent)
    return image


def pill(draw: ImageDraw.ImageDraw, xy: tuple[int, int], label: str, accent: str, scale: float = 1.0) -> None:
    f = font(round(28 * scale))
    box = draw.textbbox((0, 0), label, font=f)
    width = box[2] + round(52 * scale)
    height = round(62 * scale)
    x, y = xy
    draw.rounded_rectangle((x, y, x + width, y + height), radius=height // 2, fill=accent)
    draw.text((x + width // 2, y + height // 2), label, font=f, fill="#050508", anchor="mm")


def screenshot_card(base: Image.Image, source: Path, box: tuple[int, int, int, int], radius: int, crop_top: int = 0, focus_y: float = 0.5) -> None:
    x0, y0, x1, y1 = box
    shot = Image.open(source).convert("RGB")
    if crop_top:
        shot = shot.crop((0, crop_top, shot.width, shot.height))
    target_w, target_h = x1 - x0, y1 - y0
    ratio = max(target_w / shot.width, target_h / shot.height)
    shot = shot.resize((round(shot.width * ratio), round(shot.height * ratio)), Image.Resampling.LANCZOS)
    left = max(0, (shot.width - target_w) // 2)
    top = max(0, round((shot.height - target_h) * focus_y))
    shot = shot.crop((left, top, left + target_w, top + target_h))
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((x0 - 24, y0 - 24, x1 + 24, y1 + 24), radius=radius + 24, fill=(0, 0, 0, 175))
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    base.paste(shadow, (0, 0), shadow)
    mask = Image.new("L", (target_w, target_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, target_w, target_h), radius=radius, fill=255)
    base.paste(shot, (x0, y0), mask)


def phone_assets() -> None:
    size = (1320, 2868)
    for slide_index, (filename, eyebrow, headline, detail, accent) in enumerate(PHONE_SLIDES):
        image = campaign_background(size, slide_index, accent)
        draw = ImageDraw.Draw(image)
        draw.text((88, 105), f"0{slide_index + 1}  /  06", font=font(25), fill=MUTED)
        draw.text((88, 178), eyebrow, font=font(42), fill=accent)
        headline_font = fit_text(draw, headline, 1135, 112)
        draw.text((88, 245), headline, font=headline_font, fill=INK)
        pill(draw, (88, 420), detail, accent)
        # The UI dominates the panel; copy explains the benefit without inventing screens.
        if slide_index in (1, 2):
            screenshot_card(image, PHONE / filename, (92, 650, 1228, 2675), 72)
        else:
            screenshot_card(image, PHONE / filename, (205, 650, 1115, 2675), 72)
        save(image, OUT / "iphone-6.9-carousel" / f"{slide_index + 1:02d}.png")


def ipad_assets() -> None:
    size = (2064, 2752)
    for slide_index, (filename, eyebrow, headline, detail, accent) in enumerate(PHONE_SLIDES):
        image = campaign_background(size, slide_index, accent)
        draw = ImageDraw.Draw(image)
        draw.text((132, 100), f"0{slide_index + 1}  /  06", font=font(30), fill=MUTED)
        draw.text((132, 175), eyebrow, font=font(50), fill=accent)
        headline_font = fit_text(draw, headline, 1780, 132)
        draw.text((132, 250), headline, font=headline_font, fill=INK)
        pill(draw, (132, 450), detail, accent, 1.22)

        # On iPad the game fills the canvas. We show genuine UI detail as a
        # landscape editorial crop, never as a fake iPhone device mockup.
        focus = 0.36 if slide_index == 0 else 0.5
        screenshot_card(image, PHONE / filename, (132, 690, 1932, 2380), 58, crop_top=110, focus_y=focus)
        draw.rounded_rectangle((132, 2450, 1932, 2625), radius=40, fill="#15151D", outline="#343440", width=3)
        footer = [
            "NO ACCOUNT. NO INTERNET. NO EXCUSES.",
            "FAST ROUNDS. INSTANT RETRIES.",
            "MEMORY. REACTION. PURE PANIC.",
            "EVERY FAIL EXPLAINED IN ONE LINE.",
            "SHARE THE SCORE. HIDE THE SHAME.",
            "APPLE TV OR MAC HOSTS THE ROOM.",
        ][slide_index]
        draw.text((1032, 2538), footer, font=font(44), fill=INK, anchor="mm")
        save(image, OUT / "ipad-13-carousel" / f"{slide_index + 1:02d}.png")


IMESSAGE_SLIDES = [
    ("A 1V1 INSIDE MESSAGES.", "NO ACCOUNT. NO MATCHMAKING.", YELLOW, "start"),
    ("SAME TRAPS. SAME ORDER.", "FAIR SEED. UNFAIR PRESSURE.", GREEN, "challenge"),
    ("YOUR SCORE STAYS HIDDEN.", "UNTIL THEY FINISH THEIR TURN.", "#FF297D", "waiting"),
    ("THREE ROUNDS. GETS WORSE.", "FASTER. TRICKIER. STUPIDER.", BLUE, "score"),
    ("REMATCH. IF YOU DARE.", "BEST OF THREE. WORST OF YOU.", RED, "final"),
]


def message_bubble(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], title: str, subtitle: str, score: str = "") -> None:
    x0, y0, x1, y1 = box
    draw.rounded_rectangle(box, radius=52, fill="#1B1B25", outline="#333342", width=4)
    draw.ellipse((x0 + 48, y0 + 50, x0 + 176, y0 + 178), fill=YELLOW)
    draw.ellipse((x0 + 105, y0 + 92, x0 + 233, y0 + 220), fill="#FF297D")
    draw.text((x0 + 275, y0 + 64), title, font=font(50), fill=INK)
    draw.text((x0 + 278, y0 + 150), subtitle, font=font(30), fill=YELLOW)
    if score:
        draw.text((x1 - 55, y1 - 52), score, font=font(38), fill=MUTED, anchor="rs")


def extension_panel(base: Image.Image, mode: str, box: tuple[int, int, int, int]) -> None:
    x0, y0, x1, y1 = box
    draw = ImageDraw.Draw(base)
    draw.rounded_rectangle(box, radius=58, fill="#09090C", outline="#30303A", width=4)
    cx = (x0 + x1) // 2
    if mode == "start":
        draw.text((cx, y0 + 120), "STUPID STREAK", font=font(78), fill=INK, anchor="ma")
        draw.text((cx, y0 + 235), "Same traps. Same order.", font=font(34), fill=MUTED, anchor="ma")
        draw.text((cx, y0 + 283), "Three increasingly stupid rounds.", font=font(34), fill=MUTED, anchor="ma")
        draw.rounded_rectangle((x0 + 85, y0 + 410, x1 - 85, y0 + 565), radius=38, fill=YELLOW)
        draw.text((cx, y0 + 488), "START A 1V1 CHALLENGE", font=font(38), fill=BG, anchor="mm")
    elif mode == "challenge":
        draw.text((x0 + 70, y0 + 72), "ROUND 2   •   STREAK 6", font=font(28), fill=YELLOW)
        draw.text((cx, y0 + 190), "TAP THE OPPOSITE", font=font(66), fill=INK, anchor="ma")
        labels = [("YES", GREEN), ("NO", RED), ("LEFT", BLUE), ("RIGHT", YELLOW)]
        for i, (label, color) in enumerate(labels):
            col, row = i % 2, i // 2
            bx0 = x0 + 70 + col * 455
            by0 = y0 + 330 + row * 225
            draw.rounded_rectangle((bx0, by0, bx0 + 405, by0 + 190), radius=38, fill=color)
            draw.text((bx0 + 202, by0 + 96), label, font=font(52), fill=BG, anchor="mm")
        draw.text((cx, y0 + 825), "DON'T OVERTHINK IT.", font=font(28), fill=MUTED, anchor="ma")
    elif mode == "waiting":
        draw.text((cx, y0 + 135), "NOW WE WAIT", font=font(74), fill=INK, anchor="ma")
        draw.text((cx, y0 + 275), "Round 1 is in the chat.", font=font(36), fill=MUTED, anchor="ma")
        draw.text((cx, y0 + 332), "Their score stays hidden until they play.", font=font(32), fill=MUTED, anchor="ma")
        message_bubble(draw, (x0 + 75, y0 + 450, x1 - 75, y0 + 780), "ROUND 1", "YOUR TURN. PROBABLY.")
    elif mode == "score":
        draw.text((cx, y0 + 120), "ROUND 2 DONE", font=font(74), fill=INK, anchor="ma")
        draw.text((cx, y0 + 280), "2     —     0", font=font(106), fill=YELLOW, anchor="ma")
        draw.text((cx, y0 + 410), "FIRST PLAYER WAS LESS STUPID.", font=font(31), fill=INK, anchor="ma")
        draw.rounded_rectangle((x0 + 95, y0 + 540, x1 - 95, y0 + 700), radius=38, fill=YELLOW)
        draw.text((cx, y0 + 620), "PLAY ROUND 3", font=font(44), fill=BG, anchor="mm")
    else:
        draw.text((cx, y0 + 115), "THAT WAS THE MATCH", font=font(66), fill=INK, anchor="ma")
        draw.text((cx, y0 + 275), "2     —     1", font=font(108), fill=YELLOW, anchor="ma")
        draw.text((cx, y0 + 425), "YOU ARE OFFICIALLY LESS STUPID.", font=font(31), fill=INK, anchor="ma")
        draw.rounded_rectangle((x0 + 95, y0 + 555, x1 - 95, y0 + 715), radius=38, fill="#FF297D")
        draw.text((cx, y0 + 635), "REMATCH", font=font(48), fill=BG, anchor="mm")


def imessage_assets() -> None:
    size = (1320, 2868)
    for slide_index, (headline, detail, accent, mode) in enumerate(IMESSAGE_SLIDES):
        image = campaign_background(size, slide_index, accent)
        draw = ImageDraw.Draw(image)
        draw.text((86, 100), f"STUPID STREAK   0{slide_index + 1} / 05", font=font(25), fill=accent)
        headline_font = fit_text(draw, headline, 1145, 92)
        draw.text((86, 175), headline, font=headline_font, fill=INK)
        pill(draw, (86, 340), detail, accent)

        # Messages chrome establishes where the extension lives; the product
        # panel itself is drawn from the shipped UIKit copy and states.
        draw.rounded_rectangle((95, 540, 1225, 2710), radius=80, fill="#F4F4F7")
        draw.text((660, 605), "Messages", font=font(36), fill="#202027", anchor="ma")
        draw.text((165, 605), "‹", font=font(58), fill="#1686F7", anchor="ma")
        if mode in ("waiting", "final"):
            message_bubble(draw, (230, 760, 1130, 1110), "STUPID STREAK", "ROUND IN THE CHAT", "2–1" if mode == "final" else "0–0")
            extension_panel(image, mode, (150, 1240, 1170, 2570))
        else:
            extension_panel(image, mode, (150, 735, 1170, 2570))
        save(image, OUT / "imessage-6.9-carousel" / f"{slide_index + 1:02d}.png")


DESKTOP_SLIDES = [
    ("THE PARTY STARTS HERE.", "HOST ON APPLE TV OR MAC.", BLUE),
    ("SCAN. JOIN. PANIC.", "PHONES BECOME CONTROLLERS.", GREEN),
    ("UP TO 16 PLAYERS.", "ONE ROOM. ZERO DIGNITY.", RED),
]


def wide_asset(size: tuple[int, int], folder: str, index: int, headline: str, subhead: str, accent: str) -> None:
    image = background(size, accent)
    w, h = size
    draw = ImageDraw.Draw(image)
    margin = w // 16
    draw.text((margin, h // 24), "ARE YOU STUPID? — PARTY MODE", font=font(w // 72), fill=accent)
    headline_font = fit_text(draw, headline, w * 7 // 8, w // 16)
    headline_y = h // 10
    draw.text((margin, headline_y), headline, font=headline_font, fill=INK)
    headline_bottom = draw.textbbox((margin, headline_y), headline, font=headline_font)[3]
    draw.text((margin, headline_bottom + h // 80), subhead, font=font(max(28, w // 90)), fill=MUTED)
    rounded_screenshot(image, TV, (w // 11, h * 30 // 100, w * 10 // 11, h * 94 // 100), max(32, w // 80))
    save(image, OUT / folder / f"{index:02d}.png")


def desktop_assets() -> None:
    for index, (headline, subhead, accent) in enumerate(DESKTOP_SLIDES, 1):
        wide_asset((3840, 2160), "apple-tv", index, headline, subhead, accent)
        wide_asset((2880, 1800), "mac", index, headline, subhead, accent)


def play_assets() -> None:
    """Google Play: 9:16 phone screenshots (Play rejects anything past 2:1),
    the 1024×500 feature graphic and the 512×512 hi-res icon."""
    size = (1080, 1920)
    for index, (filename, eyebrow, headline, detail, accent) in enumerate(PHONE_SLIDES, 1):
        image = background(size, accent)
        add_header(image, eyebrow, headline, accent, 72, 80, 936)
        ImageDraw.Draw(image).text((72, 250), detail, font=font(24), fill=MUTED)
        rounded_screenshot(image, PHONE / filename, (250, 340, 830, 1860), 48)
        save(image, OUT / "play-phone" / f"{index:02d}.png")

    image = background((1024, 500), RED)
    draw = ImageDraw.Draw(image)
    draw.text((56, 70), "ONE JOB. DON'T MESS IT UP.", font=font(26), fill=RED)
    draw.text((56, 120), "ARE YOU", font=font(92), fill=INK)
    draw.text((56, 222), "STUPID?", font=font(92), fill=YELLOW)
    draw.text((56, 352), "ONE-HANDED. OFFLINE. NO ACCOUNT.", font=font(24), fill=MUTED)
    rounded_screenshot(image, PHONE / PHONE_SLIDES[1][0], (700, 30, 980, 470), 24)
    save(image, OUT / "play-feature" / "feature-graphic.png")

    icon = Image.open(ROOT / "icon.png").convert("RGB").resize((512, 512), Image.Resampling.LANCZOS)
    save(icon, OUT / "play-feature" / "icon-512.png")


def review_purchase_asset() -> None:
    """Reviewer-only Settings view for the three non-consumable purchases."""
    size = (1320, 2868)
    image = Image.new("RGB", size, BG)
    draw = ImageDraw.Draw(image)
    draw.text((72, 110), "SETTINGS", font=font(126), fill=INK)
    draw.text((72, 280), "IN-APP PURCHASES", font=font(38), fill=MUTED)

    rows = [
        ("REMOVE ADS", "One-time purchase. No more ads, ever.", "ONE-TIME", RED),
        ("PARTY PACK", "Unlocks 16-player lobbies. Ads stay.", "ONE-TIME", BLUE),
        ("PARTY BUNDLE", "16-player lobbies and no ads.", "ONE-TIME", YELLOW),
    ]
    y = 390
    for label, caption, price, accent in rows:
        draw.rounded_rectangle((60, y, 1260, y + 400), radius=44, fill="#1A1A22", outline="#30303B", width=4)
        draw.rectangle((60, y, 76, y + 400), fill=accent)
        draw.text((120, y + 82), label, font=font(62), fill=INK)
        draw.text((120, y + 180), caption, font=font(32, bold=False), fill=MUTED)
        price_font = font(48)
        price_w = draw.textbbox((0, 0), price, font=price_font)[2]
        draw.text((1190 - price_w, y + 142), price, font=price_font, fill=accent)
        y += 450

    draw.text((660, y + 24), "RESTORE PURCHASE", font=font(38), fill=MUTED, anchor="ma")
    draw.rounded_rectangle((60, y + 150, 1260, y + 430), radius=52, outline="#3A3A48", width=7)
    draw.text((660, y + 290), "BACK", font=font(58), fill=INK, anchor="mm")
    draw.text((660, 2650), "REVIEW PATH: HOME  ›  SETTINGS", font=font(30), fill=MUTED, anchor="mm")
    draw.text((660, 2720), "NON-CONSUMABLE · RESTORABLE", font=font(28), fill=GREEN, anchor="mm")
    save(image, OUT / "review" / "settings-purchases.png")


if __name__ == "__main__":
    phone_assets()
    ipad_assets()
    imessage_assets()
    desktop_assets()
    review_purchase_asset()
    play_assets()
    print(f"Wrote App Store screenshots to {OUT}")
