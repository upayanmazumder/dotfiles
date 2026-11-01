#!/usr/bin/env python3
"""
Renders the raster assets for the "obsidian" Plymouth theme.

This is a *build-time* tool, not a boot-time dependency. Plymouth's script
plugin can only load pre-rendered PNG files, so the shipped theme ships
static assets under theme/obsidian/assets/. This script is the single
source of truth for how those assets were produced: re-run it after
editing the constants below to regenerate the PNGs deterministically.

Usage:
    python3 tools/render_assets.py

Requires: Pillow (pip install pillow / pacman -S python-pillow)
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "theme" / "obsidian" / "assets"

# --------------------------------------------------------------------------
# Palette (see README.md "Color Palette" section — keep in sync)
# --------------------------------------------------------------------------
DEEP_COBALT = (27, 58, 107)      # #1B3A6B
MUTED_SAPPHIRE = (76, 110, 145)  # #4C6E91
DESAT_AZURE = (124, 147, 168)    # #7C93A8
BLACK = (0, 0, 0)

# --------------------------------------------------------------------------
# Loading ring geometry — thin, precise, symmetrical, no bulk.
# --------------------------------------------------------------------------
SUPERSAMPLE = 4
RING_CANVAS = 512                       # final ring.png is RING_CANVAS^2
RING_RADIUS = 196                       # px, at final resolution
TICK_COUNT = 48                         # ticks around the circle
TICK_LENGTH = 20                        # radial length of one tick, px
TICK_WIDTH = 5                          # stroke width, px
TRAIL_ARC_DEGREES = 132                 # portion of the ring that "sweeps"
TRAIL_MAX_ALPHA = 232                   # leading edge opacity (0-255)
TRAIL_MIN_ALPHA = 18                    # trailing edge opacity, before baseline
BASELINE_ALPHA = 12                     # always-visible faint ring, rest of circle

# --------------------------------------------------------------------------
# Password / question bullet dot
# --------------------------------------------------------------------------
DOT_SIZE = 16                           # final px diameter

# --------------------------------------------------------------------------
# Solid-fill helper pixels (scaled at runtime by the .script file)
# --------------------------------------------------------------------------
PIXEL_SIZE = 8


def _lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def _lerp_color(c1, c2, t: float):
    return tuple(int(round(_lerp(c1[i], c2[i], t))) for i in range(3))


def render_ring() -> None:
    """Draws a thin ring of radial ticks with a comet-style brightness sweep.

    The leading tick (angle 0, pointing straight up) is brightest. Moving
    clockwise, brightness and color fall off smoothly across TRAIL_ARC_DEGREES
    from desaturated azure to deep cobalt. The remainder of the ring stays at
    a very faint, constant baseline so the circle always reads as a complete,
    symmetrical shape rather than a disconnected arc popping in and out.
    """
    size = RING_CANVAS * SUPERSAMPLE
    scale = SUPERSAMPLE
    cx = cy = size / 2
    radius = RING_RADIUS * scale
    tick_len = TICK_LENGTH * scale
    tick_w = TICK_WIDTH * scale

    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    for i in range(TICK_COUNT):
        angle_deg = (i * 360.0 / TICK_COUNT) % 360.0
        if angle_deg <= TRAIL_ARC_DEGREES:
            t = angle_deg / TRAIL_ARC_DEGREES
            color = _lerp_color(DESAT_AZURE, DEEP_COBALT, t)
            alpha = int(round(_lerp(TRAIL_MAX_ALPHA, TRAIL_MIN_ALPHA, t)))
        else:
            color = DEEP_COBALT
            alpha = BASELINE_ALPHA

        theta = math.radians(angle_deg - 90.0)  # angle_deg=0 -> straight up
        r0 = radius - tick_len / 2
        r1 = radius + tick_len / 2
        x0 = cx + r0 * math.cos(theta)
        y0 = cy + r0 * math.sin(theta)
        x1 = cx + r1 * math.cos(theta)
        y1 = cy + r1 * math.sin(theta)

        fill = (*color, alpha)
        draw.line([(x0, y0), (x1, y1)], fill=fill, width=int(tick_w))
        # Round the caps by capping each end with a matching circle.
        cap_r = tick_w / 2
        for px, py in ((x0, y0), (x1, y1)):
            draw.ellipse([px - cap_r, py - cap_r, px + cap_r, py + cap_r], fill=fill)

    img = img.resize((RING_CANVAS, RING_CANVAS), Image.LANCZOS)
    img.save(ASSETS / "ring.png")


def render_dot() -> None:
    """Small filled circle used as a per-character marker in password/question prompts."""
    size = DOT_SIZE * SUPERSAMPLE
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([0, 0, size - 1, size - 1], fill=(*DESAT_AZURE, 235))
    img = img.resize((DOT_SIZE, DOT_SIZE), Image.LANCZOS)
    img.save(ASSETS / "dot.png")


def render_pixels() -> None:
    """Solid-color source pixels the script scales at runtime (curtain + hairline).

    Rendering a small flat swatch (rather than a 1x1 pixel) avoids any
    filter-dependent edge artifacts when the script scales it up to
    arbitrary window/line dimensions.
    """
    black = Image.new("RGBA", (PIXEL_SIZE, PIXEL_SIZE), (*BLACK, 255))
    black.save(ASSETS / "pixel_black.png")

    accent = Image.new("RGBA", (PIXEL_SIZE, PIXEL_SIZE), (*MUTED_SAPPHIRE, 255))
    accent.save(ASSETS / "pixel_accent.png")


def main() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    render_ring()
    render_dot()
    render_pixels()
    print(f"Assets written to {ASSETS}")


if __name__ == "__main__":
    main()
