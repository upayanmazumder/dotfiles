-- Fix Steam client UI being tiny on HiDPI (2880x1800 @ 1.5 scale).
-- Newer Steam versions read the Xft.dpi X resource (set via xrdb in
-- custom/execs.lua) rather than this variable, but older builds still
-- honor it, so set both for safety.
hl.env("STEAM_FORCE_DESKTOPUI_SCALING", "1.5")
