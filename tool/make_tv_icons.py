"""Regenerates the tvOS App Icon (layered) and Top Shelf images from the
repo-root icon.png. Run from the repo root: python3 tool/make_tv_icons.py

icon.png is the iOS icon: art on a near-black rounded square with white
corners. tvOS wants full-bleed 16:10-ish layers instead, so the art is cut
out of its own background (colour distance + dilation keeps the dark
outlines around the letters) and composed on a full-bleed backdrop:
  back   - solid backdrop in the icon's own near-black, soft pink/yellow glow
  middle - empty (kept so the imagestack stays 3 layers deep)
  front  - the brain + title, transparent around it, for the parallax.
See docs/Architecture/Multiplayer Host (tvOS).md.
"""
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

BRAND = 'tvos/TVResources/Assets.xcassets/App Icon & Top Shelf Image.brandassets'
BG = (14, 13, 12)

src = Image.open('icon.png').convert('RGB')
S = src.size[0]

# Mask of "art" pixels: anything clearly different from the backdrop colour,
# inside the rounded square (drops the white corners), dilated so the black
# letter outlines adjacent to coloured pixels survive, then softened.
diff = ImageChops.difference(src, Image.new('RGB', src.size, BG)).convert('L')
art = diff.point(lambda v: 255 if v > 38 else 0)
inner = Image.new('L', src.size, 0)
m = int(S * 0.035)
ImageDraw.Draw(inner).rounded_rectangle([m, m, S - m, S - m], int(S * 0.19), fill=255)
art = ImageChops.multiply(art, inner)
art = art.filter(ImageFilter.MaxFilter(25)).filter(ImageFilter.GaussianBlur(4))
cut = src.convert('RGBA')
cut.putalpha(art)
cut = cut.crop(art.getbbox())


def backdrop(w, h):
    img = Image.new('RGB', (w, h), BG)
    glow = Image.new('RGB', (w, h), BG)
    d = ImageDraw.Draw(glow)
    d.ellipse([w * 0.18, -h * 0.25, w * 0.82, h * 0.75], fill=(70, 22, 48))
    d.ellipse([w * 0.25, h * 0.55, w * 0.75, h * 1.25], fill=(60, 48, 6))
    glow = glow.filter(ImageFilter.GaussianBlur(int(min(w, h) * 0.18)))
    return Image.blend(img, glow, 0.9)


def front(w, h, height_frac=0.86):
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    a = cut.copy()
    scale = h * height_frac / a.size[1]
    a = a.resize((int(a.size[0] * scale), int(a.size[1] * scale)), Image.LANCZOS)
    layer.paste(a, ((w - a.size[0]) // 2, (h - a.size[1]) // 2), a)
    return layer


def save_stack(stack, w, h):
    base = f'{BRAND}/{stack}.imagestack'
    for scale, suffix in [(1, ''), (2, '@2x')]:
        W, H = w * scale, h * scale
        backdrop(W, H).save(f'{base}/Back.imagestacklayer/Content.imageset/back{suffix}.png')
        Image.new('RGBA', (W, H), (0, 0, 0, 0)).save(
            f'{base}/Middle.imagestacklayer/Content.imageset/middle{suffix}.png')
        front(W, H).save(f'{base}/Front.imagestacklayer/Content.imageset/front{suffix}.png')


def top_shelf(name, w, h):
    font_path = '/System/Library/Fonts/Supplemental/Arial Black.ttf'
    lines = [('THE PARTY GAME', 0.11, (250, 245, 235)),
             ('FOR YOUR TV', 0.11, (254, 211, 3)),
             ('2-8 PLAYERS \u00b7 YOUR PHONE IS THE CONTROLLER', 0.05, (200, 195, 190))]
    for scale, suffix in [(1, ''), (2, '@2x')]:
        W, H = w * scale, h * scale
        img = backdrop(W, H).convert('RGBA')
        art = front(int(H * 1.25), H, 0.84)
        art = art.crop(art.getbbox())
        gap = int(H * 0.08)
        # Text block may use what's left of 84% of the width; shrink to fit.
        room = int(W * 0.84) - art.size[0] - gap
        fonts = []
        for text, size, _ in lines:
            px = int(H * size)
            f = ImageFont.truetype(font_path, px)
            while f.getlength(text) > room:
                px -= 2
                f = ImageFont.truetype(font_path, px)
            fonts.append(f)
        block_w = max(f.getlength(t) for f, (t, _, _) in zip(fonts, lines))
        x0 = int((W - (art.size[0] + gap + block_w)) / 2)
        img.alpha_composite(art, (x0, (H - art.size[1]) // 2))
        d = ImageDraw.Draw(img)
        heights = [f.getbbox(t)[3] for f, (t, _, _) in zip(fonts, lines)]
        spacing = int(H * 0.035)
        y = (H - (sum(heights) + spacing * (len(lines) - 1))) // 2
        tx = x0 + art.size[0] + gap
        for f, (t, _, colour), hgt in zip(fonts, lines, heights):
            d.text((tx, y), t, font=f, fill=colour)
            y += hgt + spacing
        img.convert('RGB').save(f'{BRAND}/{name}.imageset/{name.lower().replace(" ", "-")}{suffix}.png')


save_stack('App Icon', 400, 240)
save_stack('App Icon - App Store', 1280, 768)
top_shelf('Top Shelf Image', 1920, 720)
top_shelf('Top Shelf Image Wide', 2320, 720)
print('ok')
