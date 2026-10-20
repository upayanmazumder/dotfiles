#!/bin/sh
# Wraps a game launch for max performance on the 780M iGPU + 2880x1800 panel:
# gamemode (performance profile, high GPU perf level, via ~/.config/gamemode.ini)
# + gamescope (render at half native res, FSR-upscale to full panel, uncapped fps,
# CAS sharpening to recover quality lost to upscaling).
# Steam launch option: ~/Scripts/bin/game-launch %command%
exec gamemoderun gamescope -w 1440 -h 900 -W 2880 -H 1800 -f -F fsr --sharpness 5 -- "$@"
