#!/usr/bin/env python3
"""Regenerate the LisaSpeed menu-bar template icons (v2).

Three states of the power glyph, drawn crisp for an 18pt slot:
  tray_icon.png / tray_icon_dark.png : outline glyph          (disconnected)
  tray_icon_disconnected.png         : dashed-arc outline     (connecting)
  tray_icon_connected.png            : filled disc, bold knockout (connected)

128px canvases rendered at 4x supersampling with hand-stamped round caps
(PIL arcs/lines have butt caps). macOS renders these as template masks, so
only the alpha channel matters there; the colours keep Windows/Linux trays
sensible.
"""

from PIL import Image, ImageDraw
import math
import os

S = 4  # supersample factor
CANVAS = 128

MINT = (46, 230, 197, 255)    # #2EE6C5
WHITE = (255, 255, 255, 255)
NAVY = (11, 61, 92, 255)      # #0B3D5C

OUT = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'hiddify-app', 'assets', 'images')


def pt(cx, cy, r, deg):
    """Point on a circle, PIL angle convention (clockwise from 3 o'clock, y down)."""
    rad = math.radians(deg)
    return (cx + r * math.cos(rad), cy + r * math.sin(rad))


def cap(draw, xy, stroke, color):
    x, y = xy
    r = stroke / 2
    draw.ellipse([x - r, y - r, x + r, y + r], fill=color)


def arc_with_caps(draw, cx, cy, r, start, end, stroke, color):
    bbox = [cx - r, cy - r, cx + r, cy + r]
    draw.arc(bbox, start, end, fill=color, width=int(round(stroke)))
    cap(draw, pt(cx, cy, r, start), stroke, color)
    cap(draw, pt(cx, cy, r, end), stroke, color)


def stem_with_caps(draw, x, y0, y1, stroke, color):
    draw.line([x, y0, x, y1], fill=color, width=int(round(stroke)))
    cap(draw, (x, y0), stroke, color)
    cap(draw, (x, y1), stroke, color)


def outline_glyph(color, dashed=False):
    """Outline power symbol: arc open at the top + stem through the gap."""
    img = Image.new('RGBA', (CANVAS * S, CANVAS * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    stroke = 12 * S
    cx, cy, r = 64 * S, 74 * S, 42 * S
    # Arc: gap of 2x40 degrees centered at the top (270 in PIL terms).
    a0, a1 = 310, 230  # PIL wraps end < start by +360 -> 280 degrees of arc
    if not dashed:
        arc_with_caps(d, cx, cy, r, a0, a1, stroke, color)
    else:
        # 4 long dashes with generous gaps across the same 280-degree sweep,
        # so the ring reads as dashed rather than beaded at 18pt.
        total, dashes = 280, 4
        gaps = dashes - 1
        dash_len = 49
        gap_len = (total - dashes * dash_len) / gaps
        a = a0
        for _ in range(dashes):
            arc_with_caps(d, cx, cy, r, a % 360, (a + dash_len) % 360, stroke, color)
            a += dash_len + gap_len
    stem_with_caps(d, cx, 8 * S, 54 * S, stroke, color)
    return img.resize((CANVAS, CANVAS), Image.LANCZOS)


def filled_glyph(color):
    """Connected: filled disc with a bold knocked-out power symbol."""
    img = Image.new('RGBA', (CANVAS * S, CANVAS * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy, R = 64 * S, 66 * S, 56 * S
    d.ellipse([cx - R, cy - R, cx + R, cy + R], fill=color)

    # Knockout drawn on a separate mask, then punched out of the disc.
    knock = Image.new('L', (CANVAS * S, CANVAS * S), 0)
    kd = ImageDraw.Draw(knock)
    stroke = 16 * S
    r = 30 * S
    a0, a1 = 312, 228  # slightly wider top gap so the negative space breathes
    kd.arc([cx - r, cy - r, cx + r, cy + r], a0, a1, fill=255, width=int(round(stroke)))
    for deg in (a0, a1):
        x, y = pt(cx, cy, r, deg)
        rr = stroke / 2
        kd.ellipse([x - rr, y - rr, x + rr, y + rr], fill=255)
    # Stem knockout: from above the disc edge down into the arc gap.
    x = cx
    y0, y1 = 22 * S, 58 * S
    kd.line([x, y0, x, y1], fill=255, width=int(round(stroke)))
    for y in (y0, y1):
        rr = stroke / 2
        kd.ellipse([x - rr, y - rr, x + rr, y + rr], fill=255)

    # Punch: zero the alpha where the knockout mask is set.
    alpha = img.getchannel('A')
    from PIL import ImageChops
    inv = ImageChops.invert(knock)
    alpha = ImageChops.multiply(alpha, inv)
    img.putalpha(alpha)
    return img.resize((CANVAS, CANVAS), Image.LANCZOS)


def save(img, name):
    path = os.path.normpath(os.path.join(OUT, name))
    img.save(path)
    print('wrote', path)


if __name__ == '__main__':
    save(outline_glyph(WHITE), 'tray_icon.png')
    save(outline_glyph(NAVY), 'tray_icon_dark.png')
    save(outline_glyph(WHITE, dashed=True), 'tray_icon_disconnected.png')
    save(filled_glyph(MINT), 'tray_icon_connected.png')
