#!/usr/bin/env python3
"""The app's store icons, made from the artwork already in the repo.

    python3 tool/icons.py ios       # AppIcon PNGs rewritten opaque (no alpha)
    python3 tool/icons.py android   # adaptive + monochrome launcher icon,
                                    # and the status-bar notification icon
    python3 tool/icons.py check     # fails if any of it is out of date

Needs Pillow (pip install pillow). Run from the repository's root.

iOS: App Store Connect refuses a marketing icon with an alpha channel
(ITMS-90717), and the set had one on every PNG, though every pixel was
opaque. Each is composited onto the icon's own background colour and saved
as RGB, so it looks exactly as before; the script checks that no pixel
changed.

Android: the launcher icon was a legacy square PNG with rounded corners
drawn in. An adaptive icon is a background layer (the teal, a colour
resource) and a foreground layer (the yellow artwork, transparent around
it) that the launcher masks to its own shape; the monochrome layer is the
same artwork in one colour, for Android 13's themed icons. The artwork
fills the 72 dp the launcher shows of the 108 dp layer, as the legacy icon
filled its square; past that its edges are carried on, so the lines that
run off the icon still do when the launcher moves the layer. The
notification icon is the artwork in white on transparent, as the status bar
draws it.
"""

import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
ARTWORK = ROOT / "assets/icons/app_icon.png"
IOS_SET = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
RES = ROOT / "android/app/src/main/res"

TEAL = (23, 165, 143)     # #17A58F, the icon's background
YELLOW = (249, 255, 161)  # #F9FFA1, its lines

DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


# --- iOS -------------------------------------------------------------------

def background_of(image):
    """The icon's own background: the commonest opaque colour on its edge."""
    rgba = image.convert("RGBA")
    w, h = rgba.size
    edge = [rgba.getpixel((x, y)) for x in range(w) for y in (0, h - 1)]
    edge += [rgba.getpixel((x, y)) for y in range(h) for x in (0, w - 1)]
    opaque = [p[:3] for p in edge if p[3] == 255] or [TEAL]
    return max(set(opaque), key=opaque.count)


def flatten(path):
    """Rewrite one PNG as opaque RGB. True when it changed the file."""
    image = Image.open(path)
    if image.mode == "RGB" and "transparency" not in image.info:
        return False
    rgba = image.convert("RGBA")
    flat = Image.new("RGB", rgba.size, background_of(rgba))
    flat.paste(rgba, mask=rgba.getchannel("A"))
    # Where the icon was opaque, nothing may change.
    before, after = list(rgba.getdata()), list(flat.getdata())
    for old, new in zip(before, after):
        if old[3] == 255 and old[:3] != new:
            raise SystemExit(f"{path.name}: a pixel would change")
    flat.save(path, "PNG", optimize=True)
    return True


def ios():
    for path in sorted(IOS_SET.glob("*.png")):
        if flatten(path):
            print(f"flattened {path.relative_to(ROOT)}")


def ios_problems():
    return [
        f"{p.relative_to(ROOT)} has an alpha channel"
        for p in sorted(IOS_SET.glob("*.png"))
        if Image.open(p).mode != "RGB"
    ]


# --- Android ---------------------------------------------------------------

def artwork():
    """The artwork as a full square: its rounded corners filled with teal."""
    art = Image.open(ARTWORK).convert("RGBA")
    square = Image.new("RGB", art.size, TEAL)
    square.paste(art, mask=art.getchannel("A"))
    return square


def lines_mask(square):
    """How much of each pixel is the yellow lines (0-255), the teal being 0."""
    span = [y - t for y, t in zip(YELLOW, TEAL)]
    norm = sum(d * d for d in span)
    mask = Image.new("L", square.size)
    out = []
    for pixel in square.getdata():
        dot = sum((c - t) * d for c, t, d in zip(pixel, TEAL, span))
        out.append(max(0, min(255, round(255 * dot / norm))))
    mask.putdata(out)
    return mask


def bleed(layer, size, inner):
    """[layer] scaled to [inner] px, centred on [size] px, its edges carried
    out to the border (not cut off where the launcher may slide it)."""
    # Resampling leaves a faint ring of near-zero values at the edge; carried
    # out across the bleed it would draw lines there.
    art = layer.resize((inner, inner), Image.LANCZOS).point(lambda v: 0 if v < 24 else v)
    margin = (size - inner) // 2
    canvas = Image.new(layer.mode, (size, size))
    canvas.paste(art, (margin, margin))
    far = margin + inner
    canvas.paste(art.crop((0, 0, inner, 1)).resize((inner, margin)), (margin, 0))
    canvas.paste(art.crop((0, inner - 1, inner, inner)).resize((inner, size - far)), (margin, far))
    canvas.paste(art.crop((0, 0, 1, inner)).resize((margin, inner)), (0, margin))
    canvas.paste(art.crop((inner - 1, 0, inner, inner)).resize((size - far, inner)), (far, margin))
    for (x, y), (cx, cy) in {
        (0, 0): (0, 0),
        (far, 0): (inner - 1, 0),
        (0, far): (0, inner - 1),
        (far, far): (inner - 1, inner - 1),
    }.items():
        w = margin if x == 0 else size - far
        h = margin if y == 0 else size - far
        canvas.paste(Image.new(layer.mode, (w, h), art.getpixel((cx, cy))), (x, y))
    return canvas


def coloured(mask, colour):
    image = Image.new("RGBA", mask.size, colour + (0,))
    image.putalpha(mask)
    return image


def android_files():
    """Every Android icon file, as {path: image}."""
    mask = lines_mask(artwork())
    files = {}
    for density, scale in DENSITIES.items():
        size = round(108 * scale)
        inner = round(72 * scale)
        layer = bleed(mask, size, inner)
        files[RES / f"mipmap-{density}/ic_launcher_foreground.png"] = coloured(layer, YELLOW)
        files[RES / f"mipmap-{density}/ic_launcher_monochrome.png"] = coloured(layer, (255, 255, 255))
        # The status-bar icon: 24 dp, the artwork in the middle 22.
        small = round(24 * scale)
        inside = round(22 * scale)
        icon = Image.new("L", (small, small))
        offset = (small - inside) // 2
        icon.paste(mask.resize((inside, inside), Image.LANCZOS), (offset, offset))
        files[RES / f"drawable-{density}/ic_stat_notification.png"] = coloured(icon, (255, 255, 255))
    return files


def android():
    for path, image in android_files().items():
        path.parent.mkdir(parents=True, exist_ok=True)
        image.save(path, "PNG", optimize=True)
        print(f"wrote {path.relative_to(ROOT)}")


def android_problems():
    problems = []
    for path, image in android_files().items():
        if not path.exists():
            problems.append(f"{path.relative_to(ROOT)} is missing")
        elif list(Image.open(path).convert("RGBA").getdata()) != list(image.getdata()):
            problems.append(f"{path.relative_to(ROOT)} is out of date")
    return problems


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "ios":
        ios()
    elif command == "android":
        android()
    elif command == "check":
        problems = ios_problems() + android_problems()
        print("\n".join(problems) or "icons are up to date")
        sys.exit(1 if problems else 0)
    else:
        print(__doc__)
        sys.exit(2)
