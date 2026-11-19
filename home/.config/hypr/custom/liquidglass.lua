-- Nothing Liquid glass, adapted from shlok-shinde/dots-hyprland c1c73060.
-- Build the pinned plugin against the installed Hyprland before enabling it.
local plugin = HOME .. "/.local/lib/nothing-liquid/hyprglass.so"
if is_file_exists(plugin) then
    hl.plugin.load(plugin)
end

local function shellSettings()
    local path = (os.getenv("XDG_STATE_HOME") or (HOME .. "/.local/state"))
        .. "/quickshell/user/generated/liquidglass.lua"
    if not is_file_exists(path) then return {} end
    local ok, settings = pcall(dofile, path)
    return (ok and type(settings) == "table") and settings or {}
end

local function unit(value, fallback)
    if type(value) ~= "number" or value ~= value then return fallback end
    return math.max(0, math.min(1, value))
end

-- The shell writes `enabled` for window glass, `layers_enabled` for the bar,
-- dock and panels, and `windows` for the window preset. The two plugin
-- switches stay separate: turning window glass off never turns layer glass
-- off. Game mode is the exception, and it also puts every window back to
-- fully opaque so a game is never dimmed by the desktop.
local function apply(settings)
    local game = settings.game_mode == true
    local windowsEnabled = settings.enabled ~= false and not game
    local layersEnabled = settings.layers_enabled ~= false and not game
    local windows = type(settings.windows) == "table" and settings.windows or {}

    local hg = hl.plugin.hyprglass
    if hg then
        -- Set every visual option in the preset itself. Preset values are
        -- resolved before the inherited preset's theme variants, so this
        -- overrides the tahoe defaults in both dark and light mode.
        local preset = { inherits = "tahoe" }
        for key, value in pairs(windows) do
            if key ~= "inherits" then
                preset[key] = value
            end
        end
        hg.preset("readable_windows", preset)

        hg.config({
            default_theme = settings.default_theme or "dark",
            default_preset = "readable_windows",
            enabled = windowsEnabled,
            layers = { enabled = layersEnabled },
            tinted = unit(settings.tinted, 0),
            edge_highlight = tonumber(settings.edge_highlight) or 1,
            lens = tonumber(settings.lens) or 1,
            press_glow = tonumber(settings.press_glow) or 1,
            press_spill = unit(settings.press_spill, 0.5),
            highlight_direction = tonumber(settings.highlight_direction) or 1,
            dark_edge = unit(settings.dark_edge, 1),
            near_reflection = unit(settings.near_reflection, 0.5),
        })
    end

    -- Opacity applies to every application window. Fullscreen has its own
    -- setting instead of being forced opaque, and game mode forces all three
    -- back to 1.
    hl.config({
        decoration = {
            active_opacity = game and 1.0 or unit(settings.active_opacity, 0.90),
            inactive_opacity = game and 1.0 or unit(settings.inactive_opacity, 0.90),
            fullscreen_opacity = game and 1.0 or unit(settings.fullscreen_opacity, 0.90),
            shadow = {
                enabled = true,
                range = 46,
                offset = { 0, 14 },
                render_power = 3,
                color = "rgba(00000073)",
                color_inactive = "rgba(00000040)",
            },
        },
    })
end

-- The shell re-applies through this function after it rewrites its state
-- file, so a slider drag never re-registers the static layer rules below.
_G.nothingLiquidGlassApply = apply
apply(shellSettings())

if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass
    -- Layer presets remain unchanged; they are not part of the window preset.
    for _, ns in ipairs({ "quickshell:bar", "quickshell:verticalBar", "quickshell:dock", "quickshell:session" }) do
        hg.layer(ns, { mask_threshold = 0.04, preset = "tahoe_clear" })
    end
    for _, ns in ipairs({
        "quickshell:overview", "quickshell:cheatsheet", "quickshell:wallpaperSelector",
        "quickshell:sidebarLeft", "quickshell:sidebarRight",
        "quickshell:notificationPopup", "quickshell:onScreenDisplay",
        "quickshell:mediaControls", "quickshell:osk", "quickshell:popup", "quickshell:trayMenu",
    }) do
        hg.layer(ns, { mask_threshold = 0.04, preset = "tahoe" })
    end
end

-- Do not refract or blur the wallpaper as a full-screen glass panel.
hl.layer_rule({ match = { namespace = "quickshell:background" }, blur = false })
