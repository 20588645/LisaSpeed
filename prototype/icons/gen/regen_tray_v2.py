#!/usr/bin/env python3
"""Regenerate the LisaSpeed menu-bar template icons.

Three states of the power glyph, drawn crisp for an 18pt slot:
  tray_icon.png / tray_icon_dark.png : outline glyph          (disconnected)
  tray_icon_disconnected.png         : dashed-arc outline     (connecting)
  tray_icon_connected.png            : filled disc, knockout  (connected)

The stem sits on the circle's outer edge — it must not poke above the
ring, or the 18pt template looks glued to the top of the menu bar.
The whole glyph is centered on the 128px canvas so padding is even.

128px canvases rendered at 4x supersampling with hand-stamped round caps
(PIL arcs/lines have butt caps). macOS renders these as template masks, so
only the alpha channel matters there; the colours keep Windows/Linux trays
sensible.
"""

from PIL import Image, ImageChops, ImageDraw
import math
import os

S = 4  # supersample factor
CANVAS = 128
CX = 64
CY = 64

# PIL draws arc/ellipse *width inside the bbox*, so R is the visual outer
# radius. Stem caps must sit on that same outer edge — not above it —
# otherwise the 18pt template looks glued to the top of the menu bar.
STROKE = 12
R = 50  # outer radius → 14px padding
GAP = 40  # degrees each side of 12 o'clock
STEM_TOP = CY - R + STROKE / 2  # 20 — cap outer aligns with the ring
STEM_BOT = CY - 8  # 56 — into the interior, not past center

# Connected disc matches the outline's outer radius so states share a size.
# Knockout is shifted down 4px so the stem/dots don't optically hug the
# top of the disc (the glyph is heavier above its geometric center).
DISC_R = 50
KNOCK_CY = CY + 4
KNOCK_STROKE = 14
KNOCK_R = 32  # knockout outer radius
KNOCK_STEM_TOP = KNOCK_CY - KNOCK_R + KNOCK_STROKE / 2
KNOCK_STEM_BOT = KNOCK_CY - 6

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
    stroke = STROKE * S
    cx, cy, r = CX * S, CY * S, R * S
    # Arc: gap of 2×GAP degrees centered at the top (270 in PIL terms).
    a0, a1 = 270 + GAP, 270 - GAP  # 310 → 230, wrapping through the bottom
    if not dashed:
        arc_with_caps(d, cx, cy, r, a0, a1, stroke, color)
    else:
        total, dashes = 360 - 2 * GAP, 4
        gaps = dashes - 1
        dash_len = 49
        gap_len = (total - dashes * dash_len) / gaps
        a = a0
        for _ in range(dashes):
            arc_with_caps(d, cx, cy, r, a % 360, (a + dash_len) % 360, stroke, color)
            a += dash_len + gap_len
    stem_with_caps(d, cx, STEM_TOP * S, STEM_BOT * S, stroke, color)
    return img.resize((CANVAS, CANVAS), Image.LANCZOS)


def filled_glyph(color):
    """Connected: filled disc with a knocked-out power symbol, both centered."""
    img = Image.new('RGBA', (CANVAS * S, CANVAS * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy, disc_r = CX * S, CY * S, DISC_R * S
    d.ellipse([cx - disc_r, cy - disc_r, cx + disc_r, cy + disc_r], fill=color)

    knock = Image.new('L', (CANVAS * S, CANVAS * S), 0)
    kd = ImageDraw.Draw(knock)
    stroke = KNOCK_STROKE * S
    r = KNOCK_R * S
    kcx, kcy = CX * S, KNOCK_CY * S
    a0, a1 = 270 + GAP, 270 - GAP
    kd.arc([kcx - r, kcy - r, kcx + r, kcy + r], a0, a1, fill=255, width=int(round(stroke)))
    for deg in (a0, a1):
        x, y = pt(kcx, kcy, r, deg)
        rr = stroke / 2
        kd.ellipse([x - rr, y - rr, x + rr, y + rr], fill=255)
    x = kcx
    y0, y1 = KNOCK_STEM_TOP * S, KNOCK_STEM_BOT * S
    kd.line([x, y0, x, y1], fill=255, width=int(round(stroke)))
    for y in (y0, y1):
        rr = stroke / 2
        kd.ellipse([x - rr, y - rr, x + rr, y + rr], fill=255)

    alpha = img.getchannel('A')
    inv = ImageChops.invert(knock)
    alpha = ImageChops.multiply(alpha, inv)
    img.putalpha(alpha)
    return img.resize((CANVAS, CANVAS), Image.LANCZOS)


def save(img, name):
    path = os.path.normpath(os.path.join(OUT, name))
    img.save(path)
    print('wrote', path)


def save_ico(img, name):
    path = os.path.normpath(os.path.join(OUT, name))
    img.save(path, format='ICO', sizes=[(16, 16), (32, 32), (48, 48), (64, 64)])
    print('wrote', path)


if __name__ == '__main__':
    white = outline_glyph(WHITE)
    navy = outline_glyph(NAVY)
    dashed = outline_glyph(WHITE, dashed=True)
    connected = filled_glyph(MINT)
    save(white, 'tray_icon.png')
    save(navy, 'tray_icon_dark.png')
    save(dashed, 'tray_icon_disconnected.png')
    save(connected, 'tray_icon_connected.png')
    save_ico(white, 'tray_icon.ico')
    save_ico(navy, 'tray_icon_dark.ico')
    save_ico(dashed, 'tray_icon_disconnected.ico')
    save_ico(connected, 'tray_icon_connected.ico')
