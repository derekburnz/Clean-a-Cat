"""Store art layout (issue #24): lays the raw renders from `store_art.py` over bright backdrops, adds the words, and
makes the draft sheet with each option shown at its real size and at the small sizes players see.

    python3 assets/clean-a-cat/blender/store_compose.py <raw folder> <out folder> [sheet.png] [--final]

Plain Python with Pillow (not Blender). Fonts: Inter Black from the system (`fc-list | grep "Inter Black"`); swap
FONT for the game's UI font once the ui-designer picks one. Words: three at most, huge, high contrast, never "free".
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT = "/usr/share/fonts/opentype/inter/Inter-Black.otf"
INK = (46, 42, 92)                 # the outline: deep navy, reads on every pastel
WHITE = (255, 255, 255)
CREAM = (255, 246, 236)
BUTTER = (255, 226, 140)

# key: (kind, backdrop inner, backdrop outer, words, where the words go)
OPTIONS = {
    "icon-a": ("icon", (255, 214, 226), (255, 150, 182), None, None),
    "icon-b": ("icon", (196, 236, 255), (98, 186, 246), "CAT SPA", "bottom"),
    "icon-c": ("icon", (255, 214, 226), (255, 150, 182), "CLEAN A CAT", "bottom"),
    "thumb-1": ("thumb", (214, 240, 255), (110, 192, 248), "CLEAN A CAT", "left"),
    "thumb-2": ("thumb", (255, 226, 234), (255, 160, 190), "MUDDY TO FLUFFY", "top"),
    "thumb-3": ("thumb", (214, 245, 232), (120, 210, 178), "YOUR CAT SPA", "left"),
}
TITLES = {
    "icon-a": "Icon A: the scrub, no words",
    "icon-b": "Icon B: the whole cat, CAT SPA",
    "icon-c": "Icon C: clean and fluffy, CLEAN A CAT",
    "thumb-1": "Thumbnail 1: scrubbing at the tub",
    "thumb-2": "Thumbnail 2: muddy to fluffy",
    "thumb-3": "Thumbnail 3: your spa at work",
}


def backdrop(size, inner, outer):
    """A soft radial glow from the middle, with a few faint bubble rings."""
    w, h = size
    small = Image.new("RGB", (64, 64))
    px = small.load()
    for y in range(64):
        for x in range(64):
            d = min(1.0, (((x - 32) / 32) ** 2 + ((y - 30) / 32) ** 2) ** 0.5)
            t = d ** 1.4
            px[x, y] = tuple(int(inner[i] + (outer[i] - inner[i]) * t) for i in range(3))
    bg = small.resize(size, Image.BICUBIC).convert("RGBA")
    rings = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(rings)
    s = min(w, h)
    for fx, fy, fr in ((0.08, 0.16, 0.05), (0.9, 0.2, 0.035), (0.14, 0.82, 0.03), (0.88, 0.78, 0.055),
                       (0.5, 0.06, 0.025)):
        r = fr * s
        cx, cy = fx * w, fy * h
        d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(255, 255, 255, 110), width=max(2, int(s * 0.008)))
        d.ellipse((cx - r * 0.45, cy - r * 0.6, cx - r * 0.15, cy - r * 0.3), fill=(255, 255, 255, 120))
    return Image.alpha_composite(bg, rings)


def crop_to_content(im, pad=0.02):
    box = im.getchannel("A").point(lambda a: 255 if a > 60 else 0).getbbox()   # past the faint shadow edge
    if not box:
        return im
    p = int(pad * max(im.size))
    return im.crop((max(0, box[0] - p), max(0, box[1] - p), min(im.width, box[2] + p), min(im.height, box[3] + p)))


def fit(im, box_w, box_h):
    k = min(box_w / im.width, box_h / im.height)
    return im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)


def words(canvas, text, cx, cy, max_w, size):
    """Big white words with a thick navy outline and a soft drop shadow, centred on (cx, cy), shrunk to max_w."""
    while True:
        font = ImageFont.truetype(FONT, size)
        stroke = max(3, size // 9)
        l, t, r, b = font.getbbox(text, stroke_width=stroke)
        if r - l <= max_w or size < 12:
            break
        size = int(size * 0.94)
    w, h = r - l, b - t
    x, y = int(cx - w / 2 - l), int(cy - h / 2 - t)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).text((x, y + stroke), text, font=font, fill=INK + (150,), stroke_width=stroke,
                                stroke_fill=INK + (150,))
    shadow = shadow.filter(ImageFilter.GaussianBlur(stroke * 0.6))
    canvas.alpha_composite(shadow)
    ImageDraw.Draw(canvas).text((x, y), text, font=font, fill=WHITE, stroke_width=stroke, stroke_fill=INK)
    return h


def compose(key, raw_dir, final=False):
    kind, inner, outer, text, where = OPTIONS[key]
    raw = Image.open(os.path.join(raw_dir, f"raw-{key}.png")).convert("RGBA")
    if kind == "icon":
        size = (512, 512)
        bg = backdrop(size, inner, outer)
        art = raw.resize(size, Image.LANCZOS) if raw.size != size else raw
        if text:                                                  # the words take the bottom fifth: lift the art
            art = fit(crop_to_content(art), 512 * 0.92, 512 * 0.8)
            bg.alpha_composite(art, ((512 - art.width) // 2, max(0, int(512 * 0.8) - art.height)))
            words(bg, text, 256, 512 * 0.87, 512 * 0.9, 96)
        else:
            bg.alpha_composite(art)
        return bg
    size = (1920, 1080) if final else (1280, 720)
    w, h = size
    bg = backdrop(size, inner, outer)
    art = crop_to_content(raw)
    if where == "left":                                           # words on the left third, art on the right
        art = fit(art, w * 0.66, h * 0.86)
        bg.alpha_composite(art, (int(w * 0.97 - art.width), int(h * 0.95 - art.height)))
        parts = text.split()
        lines = [" ".join(parts[:-1]), parts[-1]] if len(parts) > 1 else parts
        y = h * 0.36
        for ln in lines:
            y += words(bg, ln, w * 0.2, y, w * 0.36, int(h * 0.17)) * 1.25
    else:                                                         # words across the top, art below
        art = fit(art, w * 0.94, h * 0.72)
        top = int(h * 0.97 - art.height)
        bg.alpha_composite(art, ((w - art.width) // 2, top))
        words(bg, text, w / 2, h * 0.14, w * 0.9, int(h * 0.15))
        if key == "thumb-2":                                      # an arrow from muddy to fluffy
            d = ImageDraw.Draw(bg)
            cx, cy, s = w * 0.5, top + art.height * 0.4, h * 0.07
            pts = [(cx - s * 1.3, cy - s * 0.35), (cx + s * 0.2, cy - s * 0.35), (cx + s * 0.2, cy - s * 0.8),
                   (cx + s * 1.3, cy), (cx + s * 0.2, cy + s * 0.8), (cx + s * 0.2, cy + s * 0.35),
                   (cx - s * 1.3, cy + s * 0.35)]
            d.polygon(pts, fill=BUTTER, outline=INK, width=max(4, int(s * 0.12)))
    return bg


def rounded(im, radius_frac=0.12):
    m = Image.new("L", im.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, im.width - 1, im.height - 1), int(im.width * radius_frac), fill=255)
    out = im.copy()
    out.putalpha(m)
    return out


def label(d, xy, text, size=22, fill=INK):
    d.text(xy, text, font=ImageFont.truetype(FONT.replace("Black", "Bold"), size), fill=fill)


def sheet(made, out):
    """All six options at a readable size, each icon also at 150 and 48 px and each thumbnail at 150 px wide."""
    W, H = 2160, 1360
    sh = Image.new("RGBA", (W, H), CREAM + (255,))
    d = ImageDraw.Draw(sh)
    label(d, (48, 30), "Clean a Cat store art, draft for Derek's pick (issue #24)", 40)
    label(d, (48, 84), "Pick one icon and one or more thumbnails. Small copies show what a player sees on a phone.", 24,
          (90, 86, 120))
    for i, key in enumerate(("icon-a", "icon-b", "icon-c")):
        x, y = 48 + i * 700, 150
        im = made[key]
        sh.alpha_composite(rounded(im.resize((420, 420), Image.LANCZOS)), (x, y + 36))
        label(d, (x, y), TITLES[key], 24)
        sm = rounded(im.resize((150, 150), Image.LANCZOS))
        sh.alpha_composite(sm, (x + 440, y + 36))
        label(d, (x + 440, y + 192), "150 px", 18, (90, 86, 120))
        tiny = rounded(im.resize((48, 48), Image.LANCZOS))
        sh.alpha_composite(tiny, (x + 440, y + 230))
        label(d, (x + 500, y + 242), "48 px", 18, (90, 86, 120))
    for i, key in enumerate(("thumb-1", "thumb-2", "thumb-3")):
        x, y = 48 + i * 700, 680
        im = made[key]
        big = im.resize((640, 360), Image.LANCZOS)
        sh.alpha_composite(big, (x, y + 36))
        label(d, (x, y), TITLES[key], 24)
        sm = im.resize((150, 84), Image.LANCZOS)
        sh.alpha_composite(sm, (x, y + 410))
        label(d, (x + 164, y + 440), "150 px wide", 18, (90, 86, 120))
    notes = ["Rules kept: the first minute's action (a muddy cat, a sponge, foam), Common cats only (Smudge, Muffin,",
             "Cotton, Inky), no cat cropped, three words at most, never the word free. Rendered from the real models.",
             "After the pick: a final 512 x 512 icon and 1920 x 1080 thumbnails. Nothing is uploaded until Derek says."]
    for j, n in enumerate(notes):
        label(d, (48, 1240 + 34 * j), n, 24, (90, 86, 120))
    sh.convert("RGB").save(out)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--final"]
    final = "--final" in sys.argv
    raw_dir, out_dir = args[0], args[1]
    os.makedirs(out_dir, exist_ok=True)
    made = {}
    for key in OPTIONS:
        if os.path.exists(os.path.join(raw_dir, f"raw-{key}.png")):
            made[key] = compose(key, raw_dir, final)
            made[key].convert("RGB").save(os.path.join(out_dir, f"{key}.png"))
    if len(args) > 2:
        sheet(made, args[2])
