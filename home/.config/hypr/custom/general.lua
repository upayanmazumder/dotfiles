-- This file will not be overwritten across dots-hyprland updates.
-- The file name is for the sake of organization and does not matter
-- See the corresponding files in ~/.config/hypr/hyprland for examples

-- ── Monitor scale (HiDPI) ───────────────────────────────────────────────
-- eDP-1 is a 2880x1800 @120Hz panel. Upstream's hyprland/general.lua ships
-- scale = 1, which renders everything at roughly half the intended size on
-- this display; 1.5 gives a 1920x1200 logical workspace.
--
-- This was previously edited directly into the framework's general.lua, i.e.
-- it would have been silently reverted by the next dots-hyprland update,
-- leaving the desktop unusably small until noticed. Declared here instead.
-- Pairs with the XWayland HiDPI handling in custom/env.lua + custom/execs.lua
-- (STEAM_FORCE_DESKTOPUI_SCALING and the `Xft.dpi: 144` xrdb merge).
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1.5
})

-- Note: the framework's general.lua also had its hardcoded
-- general.col.active_border/inactive_border removed by hand. That edit was a
-- no-op and has NOT been migrated -- hyprland.lua requires hyprland.colors
-- (matugen-generated) *after* hyprland.general, so those values are already
-- overridden by the wallpaper-derived palette regardless.

hl.config({
    input = {
        touchpad = {
            scroll_factor = 0.4
        }
    }
})
