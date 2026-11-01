#!/usr/bin/env python3
"""
Renders static preview frames and an animated GIF of the obsidian theme's
boot sequence, by re-implementing the exact math from obsidian.script
(tween timing, ease_in_out_cubic, constant-speed ring rotation) over a
1920x1080 canvas. This is not a mockup — every constant here is copied
from Obsidian.* in theme/obsidian/obsidian.script and tools/render_assets.py,
so the frames are a faithful, reproducible preview of what Plymouth renders.

Usage:
    python3 tools/render_preview.py

Requires: Pillow
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "theme" / "obsidian" / "assets"
PREVIEW = ROOT / "preview"

CANVAS_W, CANVAS_H = 1920, 1080
BG = (11, 15, 20, 255)  # #0B0F14

# --- copied from obsidian.script's Obsidian.* tunables ---------------------
RING_DIAMETER_FRACTION = 0.16
RING_PERIOD_MS = 1800
CURTAIN_FADE_IN_MS = 650
RING_IN_DELAY_MS = 260
RING_IN_MS = 520
RING_OUT_MS = 280
CURTAIN_OUT_DELAY_MS = 120
CURTAIN_OUT_MS = 480
DOT_DIAMETER_FRACTION = 0.011
DOT_GAP_FRACTION = 0.020
DIALOG_GAP_FRACTION = 0.085
LINE_WIDTH_FRACTION = 0.15


def ease_in_out_cubic(t: float) -> float:
    if t < 0.5:
        return 4 * t ** 3
    p = -2 * t + 2
    return 1 - (p ** 3) / 2


def clamp(v, lo=0.0, hi=1.0):
    return max(lo, min(hi, v))


def lerp(a, b, t):
    return a + (b - a) * t


def tween(elapsed_ms, from_v, to_v, t0, dur):
    if dur <= 0:
        return to_v
    t = clamp((elapsed_ms - t0) / dur)
    return lerp(from_v, to_v, ease_in_out_cubic(t))


class Scene:
    """Mirrors the tween bookkeeping in obsidian.script closely enough to
    render arbitrary points in time, including the entry and exit sequences."""

    def __init__(self):
        self.ring = Image.open(ASSETS / "ring.png").convert("RGBA")
        self.dot = Image.open(ASSETS / "dot.png").convert("RGBA")
        diameter = int(CANVAS_H * RING_DIAMETER_FRACTION)
        self.ring = self.ring.resize((diameter, diameter), Image.LANCZOS)
        self.ring_d = diameter
        self.ring_pos = ((CANVAS_W - diameter) // 2, (CANVAS_H - diameter) // 2)

    def frame(self, elapsed_ms: float, quitting_from_ms: float | None = None,
              dialog_active: bool = False, active_bullets: int = 0) -> Image.Image:
        canvas = Image.new("RGBA", (CANVAS_W, CANVAS_H), BG)

        # Ring opacity: fades in at RING_IN_DELAY_MS, fades out on quit.
        ring_opacity = tween(elapsed_ms, 0, 1, RING_IN_DELAY_MS, RING_IN_MS)
        if quitting_from_ms is not None:
            ring_opacity = tween(elapsed_ms, 1, 0, quitting_from_ms, RING_OUT_MS)

        angle = 2 * math.pi * ((elapsed_ms % RING_PERIOD_MS) / RING_PERIOD_MS)
        rotated = self.ring.rotate(-math.degrees(angle), resample=Image.BICUBIC, expand=False)
        r = rotated.copy()
        alpha = r.getchannel("A").point(lambda a: int(a * ring_opacity))
        r.putalpha(alpha)
        canvas.alpha_composite(r, self.ring_pos)

        # Dialog (hairline + dots), only in the password-prompt preview frame.
        if dialog_active:
            line_w = int(CANVAS_W * LINE_WIDTH_FRACTION)
            line_h = max(2, CANVAS_H // 650)
            line_x = (CANVAS_W - line_w) // 2
            line_y = self.ring_pos[1] + self.ring_d + int(CANVAS_H * DIALOG_GAP_FRACTION)
            line_img = Image.new("RGBA", (line_w, line_h), (76, 110, 145, 255))
            canvas.alpha_composite(line_img, (line_x, line_y))

            dot_d = max(4, int(CANVAS_H * DOT_DIAMETER_FRACTION))
            dot_img = self.dot.resize((dot_d, dot_d), Image.LANCZOS)
            gap = int(CANVAS_H * DOT_GAP_FRACTION)
            row_y = line_y - dot_d - int(CANVAS_H * 0.018)
            for i in range(active_bullets):
                canvas.alpha_composite(dot_img, (line_x + i * gap, row_y))

        # Curtain (black), fading in at start, back in on quit.
        curtain_opacity = tween(elapsed_ms, 1, 0, 0, CURTAIN_FADE_IN_MS)
        if quitting_from_ms is not None:
            curtain_opacity = tween(elapsed_ms, 0, 1, quitting_from_ms + CURTAIN_OUT_DELAY_MS, CURTAIN_OUT_MS)
        if curtain_opacity > 0.001:
            curtain = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, int(255 * curtain_opacity)))
            canvas.alpha_composite(curtain)

        return canvas.convert("RGB")


def main():
    PREVIEW.mkdir(parents=True, exist_ok=True)
    scene = Scene()

    frames = {
        "01-firmware-black.png": scene.frame(0),
        "02-fade-in-early.png": scene.frame(150),
        "03-fade-in-settled.png": scene.frame(950),
        "04-steady-loading-a.png": scene.frame(2200),
        "05-steady-loading-b.png": scene.frame(2650),
        "06-password-prompt.png": scene.frame(3200, dialog_active=True, active_bullets=5),
        "07-fade-out.png": scene.frame(3400 + 150, quitting_from_ms=3400),
    }
    for name, img in frames.items():
        img.save(PREVIEW / name)
        print(f"wrote {name}")

    # Animated GIF: one full entrance + a rotation + exit, ~6.3s at 20fps.
    gif_frames = []
    t = 0.0
    step = 50  # ms per gif frame (20fps)
    entrance_end = 900
    steady_end = entrance_end + RING_PERIOD_MS * 1.5
    quit_start = steady_end
    total_end = quit_start + RING_OUT_MS + CURTAIN_OUT_DELAY_MS + CURTAIN_OUT_MS + 200

    while t <= total_end:
        quitting = quit_start if t >= quit_start else None
        frame = scene.frame(t, quitting_from_ms=quitting)
        gif_frames.append(frame.resize((960, 540), Image.LANCZOS))
        t += step

    gif_frames[0].save(
        PREVIEW / "boot-sequence.gif",
        save_all=True,
        append_images=gif_frames[1:],
        duration=step,
        loop=0,
        optimize=True,
    )
    print(f"wrote boot-sequence.gif ({len(gif_frames)} frames)")


if __name__ == "__main__":
    main()
