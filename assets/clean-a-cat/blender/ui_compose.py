"""Finishes the pictures `ui_renders.py` made (#127): trims, outlines, sizes them and draws the check sheet.

    python3 assets/clean-a-cat/blender/ui_compose.py <raw folder> <out folder> [sheet.png]

Plain Python with Pillow (not Blender). For every raw picture it writes two finals:

  <name>.png        the picture alone on a see-through background
  <name>_ink.png    the same with the ink outline round it, so it stands off any backdrop

Icons are 256 px, portraits and shop pictures 512 px. An icon is trimmed to its model and centred with a small margin; a portrait
keeps its framing (the chest runs off the bottom edge on purpose, for a round or rounded frame). The outline is the
UI's ink (dark plum, never black), about 3% of the picture wide, with no outline along a portrait's cut-off edge.
The sheet shows every final on cream and on mint, then all of them at 64 px and 32 px: an icon that does not read
there is not done.
"""

import os
import sys

from PIL import Image, ImageChops, ImageFilter

INK = (59, 45, 69)                       # the ui-designer's ink, #3B2D45
CREAM, MINT = (255, 246, 236), (168, 230, 207)
ICON, PORTRAIT = 256, 512
OUTLINE = 0.03                           # of the final size
MARGIN = 0.08                            # round a trimmed icon, of the final size


def _square(im, size, trim):
    """The picture at `size`, trimmed to its alpha and centred with a margin when `trim`."""
    if trim:
        box = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
        im = im.crop(box)
        inner = round(size * (1 - 2 * MARGIN))
        k = inner / max(im.size)
        im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
        out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        out.alpha_composite(im, ((size - im.width) // 2, (size - im.height) // 2))
        return out
    return im.resize((size, size), Image.LANCZOS)


def _inked(im, open_bottom):
    """im with an ink outline grown from its alpha. open_bottom: no outline along the bottom edge (a portrait's
    chest is cut there on purpose)."""
    size = im.width
    r = max(2, round(size * OUTLINE))
    alpha = im.getchannel("A")
    work = alpha
    if open_bottom:                                  # carry the bottom row down so the growth has nothing to round
        work = Image.new("L", (size, size + 2 * r), 0)
        work.paste(alpha, (0, 0))
        last = alpha.crop((0, size - 1, size, size))
        for y in range(size, size + 2 * r):
            work.paste(last, (0, y))
    grown = work.filter(ImageFilter.MaxFilter(2 * r + 1)).filter(ImageFilter.GaussianBlur(0.8))
    grown = grown.crop((0, 0, size, size))
    ink = Image.new("RGBA", (size, size), INK + (0,))
    ink.putalpha(ImageChops.lighter(grown, alpha))
    ink.alpha_composite(im)
    return ink


def finish(raw_path, out_dir):
    name = os.path.splitext(os.path.basename(raw_path))[0]
    is_portrait = name.startswith("portrait_")
    im = Image.open(raw_path).convert("RGBA")
    if name.startswith("shop_"):                     # a shop card's picture (#1030): trimmed like an icon, portrait size
        plain = _square(im, PORTRAIT, trim=True)
        inked = _inked(plain, open_bottom=False)
    elif is_portrait:
        plain = _square(im, PORTRAIT, trim=False)
        inked = _inked(plain, open_bottom=True)
    else:                                            # leave room for the outline inside the frame
        plain = _square(im, ICON, trim=True)
        inked = _inked(plain, open_bottom=False)
    plain.save(os.path.join(out_dir, name + ".png"))
    inked.save(os.path.join(out_dir, name + "_ink.png"))
    return name, plain, inked


def sheet(done, path):
    """Every final at 128 px on cream (plain) and on mint (inked), then the inked ones at 64 px and 32 px."""
    cols = 12
    rows = (len(done) + cols - 1) // cols
    cell = 136
    w = cols * cell
    block = rows * cell
    small = ((len(done) * 68 + w - 1) // w) * 68 + ((len(done) * 36 + w - 1) // w) * 36
    img = Image.new("RGB", (w, 2 * block + small + 24), CREAM)
    img.paste(MINT, (0, block, w, 2 * block))
    for i, (_name, plain, inked) in enumerate(done):
        x, y = (i % cols) * cell + 4, (i // cols) * cell + 4
        img.paste(plain.resize((128, 128), Image.LANCZOS), (x, y), plain.resize((128, 128), Image.LANCZOS))
        t = inked.resize((128, 128), Image.LANCZOS)
        img.paste(t, (x, block + y), t)
    y0 = 2 * block + 8
    for px in (64, 32):
        per = w // (px + 4)
        for i, (_name, _plain, inked) in enumerate(done):
            t = inked.resize((px, px), Image.LANCZOS)
            img.paste(t, ((i % per) * (px + 4) + 2, y0 + (i // per) * (px + 4)), t)
        y0 += ((len(done) + per - 1) // per) * (px + 4) + 8
    img.save(path)
    return path


def main(argv):
    raw_dir, out_dir = argv[0], argv[1]
    os.makedirs(out_dir, exist_ok=True)
    names = sorted(f for f in os.listdir(raw_dir) if f.endswith(".png") and f.startswith(("portrait_", "icon_", "shop_")))
    done = [finish(os.path.join(raw_dir, f), out_dir) for f in names]
    print(f"ui: {len(done)} pictures in {out_dir}")
    if len(argv) > 2:
        print("ui sheet:", sheet(done, argv[2]))


if __name__ == "__main__":
    main(sys.argv[1:])
