pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Hands the Liquid Glass settings to the compositor's glass plugin: right away
 * through hyprctl eval, and for every later Hyprland start or config reload
 * through a small Lua file that hypr/custom/liquidglass.lua reads.
 *
 * The shell's own glass (bar, dock, panels) keeps its `enable` switch and layer
 * presets. Application windows have their own switch, glass preset and window
 * opacity, all under `appearance.liquidGlass.windows`. The plugin's global
 * `enabled` only controls window glass; `layers.enabled` is kept separate so
 * turning window glass off never turns the shell's glass off.
 */
Singleton {
    id: root

    readonly property var settings: Config.options.appearance.liquidGlass
    readonly property var win: root.settings.windows ?? root.windowsDefaults

    readonly property bool gameMode: Appearance.gameMode
    // "Shell glass" is the layer switch; application windows have their own
    // switch and never depend on it. Only game mode turns both off.
    readonly property bool layersEnabled: (root.settings.enable ?? false) && !root.gameMode
    readonly property bool windowsEnabled: (root.win.enable ?? true) && !root.gameMode

    readonly property int pressGlow: ({ "off": 0, "subtle": 1, "bright": 2 })[root.settings.pressGlow] ?? 1
    readonly property int highlightDirection: ({ "none": 0, "top": 1, "diagonal": 2 })[root.settings.highlights] ?? 1
    // The glass follows the colour scheme: smoked in dark mode, milky in light
    readonly property string theme: Appearance.m3colors.darkmode ? "dark" : "light"
    readonly property string statePath: FileUtils.trimFileProtocol(`${Directories.state}/user/generated/liquidglass.lua`)

    // Contract defaults for appearance.liquidGlass.windows, used when the
    // config file predates a key. bevelSize/bevelTint/bevelAngle are absent:
    // this plugin fork declares no shader uniform for them, so they do nothing.
    readonly property var windowsDefaults: ({
        "enable": true,
        "activeOpacity": 0.90,
        "inactiveOpacity": 0.90,
        "fullscreenOpacity": 0.90,
        "blurStrength": 2.5,
        "blurIterations": 3,
        "noiseStrength": 0.02,
        "refractionStrength": 0.6,
        "refractionFlow": 0,
        "refractionSpread": 1,
        "chromaticAberration": 0.15,
        "fresnelStrength": 0.6,
        "fresnelTint": 0,
        "fresnelColor": "#FFFFFF00",
        "specularStrength": 0.8,
        "specularAngle": 315,
        "bevelStrength": 0,
        "bevelColor": "#FFFFFF00",
        "bevelShadow": 0,
        "glassOpacity": 1,
        "edgeThickness": 0.06,
        "edgeThicknessPx": 0,
        "edgeHeight": 0,
        "fresnelReflection": 0,
        "tintColor": "#10182066",
        "lensDistortion": 0.5,
        "selfSample": 0,
        "xray": true,
        "focusLight": 0,
        "focusLightColor": "#FFFFFF00",
        "frost": 0,
        "frostBlur": 3,
        "brightness": 0.78,
        "contrast": 0.95,
        "saturation": 0.85,
        "vibrancy": 0.1,
        "adaptiveDim": 0.3,
        "adaptiveBoost": 0
    })

    readonly property string windowsTable: `
        blur_strength = ${root.number(root.win.blurStrength, 2.5)},
        blur_iterations = ${root.integer(root.win.blurIterations, 3)},
        noise_strength = ${root.number(root.win.noiseStrength, 0.02)},
        refraction_strength = ${root.number(root.win.refractionStrength, 0.6)},
        refraction_flow = ${root.number(root.win.refractionFlow, 0)},
        refraction_spread = ${root.number(root.win.refractionSpread, 1)},
        chromatic_aberration = ${root.number(root.win.chromaticAberration, 0.15)},
        fresnel_strength = ${root.number(root.win.fresnelStrength, 0.6)},
        fresnel_tint = ${root.number(root.win.fresnelTint, 0)},
        fresnel_color = ${root.color(root.win.fresnelColor, "#FFFFFF00")},
        specular_strength = ${root.number(root.win.specularStrength, 0.8)},
        specular_angle = ${root.number(root.win.specularAngle, 315)},
        bevel_strength = ${root.number(root.win.bevelStrength, 0)},
        bevel_color = ${root.color(root.win.bevelColor, "#FFFFFF00")},
        bevel_shadow = ${root.number(root.win.bevelShadow, 0)},
        glass_opacity = ${root.number(root.win.glassOpacity, 1)},
        edge_thickness = ${root.number(root.win.edgeThickness, 0.06)},
        edge_thickness_px = ${root.number(root.win.edgeThicknessPx, 0)},
        edge_height = ${root.number(root.win.edgeHeight, 0)},
        fresnel_reflection = ${root.number(root.win.fresnelReflection, 0)},
        tint_color = ${root.color(root.win.tintColor, "#10182066")},
        lens_distortion = ${root.number(root.win.lensDistortion, 0.5)},
        self_sample = ${root.number(root.win.selfSample, 0)},
        xray = ${root.flag(root.win.xray, true)},
        focus_light = ${root.number(root.win.focusLight, 0)},
        focus_light_color = ${root.color(root.win.focusLightColor, "#FFFFFF00")},
        frost = ${root.number(root.win.frost, 0)},
        frost_blur = ${root.number(root.win.frostBlur, 3)},
        brightness = ${root.number(root.win.brightness, 0.78)},
        contrast = ${root.number(root.win.contrast, 0.95)},
        saturation = ${root.number(root.win.saturation, 0.85)},
        vibrancy = ${root.number(root.win.vibrancy, 0.1)},
        adaptive_dim = ${root.number(root.win.adaptiveDim, 0.3)},
        adaptive_boost = ${root.number(root.win.adaptiveBoost, 0)}
    `

    readonly property string payload: `{
    enabled = ${root.windowsEnabled},
    layers_enabled = ${root.layersEnabled},
    game_mode = ${root.gameMode},
    default_theme = "${root.theme}",
    active_opacity = ${root.gameMode ? "1.0000" : root.unit(root.win.activeOpacity, 0.90)},
    inactive_opacity = ${root.gameMode ? "1.0000" : root.unit(root.win.inactiveOpacity, 0.90)},
    fullscreen_opacity = ${root.gameMode ? "1.0000" : root.unit(root.win.fullscreenOpacity, 0.90)},
    tinted = ${root.unit(root.settings.mode === "tinted" ? root.settings.tintAmount : 0, 0)},
    edge_highlight = ${root.number(root.settings.edgeHighlight, 1.0)},
    lens = ${root.number(root.settings.refraction, 1.0)},
    press_glow = ${root.pressGlow},
    press_spill = ${root.unit(root.settings.glowSpread ? 0.5 : 0, 0.5)},
    highlight_direction = ${root.highlightDirection},
    dark_edge = ${root.unit(root.settings.darkEdge ? 1 : 0, 1)},
    near_reflection = ${root.unit(root.settings.nearReflection ? 0.5 : 0, 0.5)},
    windows = {${root.windowsTable}
    },
}`

    readonly property string stateText: `-- written by the shell (Settings > Glass); read by hypr/custom/liquidglass.lua\nreturn ${root.payload}\n`

    function load() {
        applyTimer.restart();
    }

    onPayloadChanged: applyTimer.restart()

    function apply() {
        // blockWrites keeps the compositor's copy and the live payload in
        // lockstep: setText() returns once the file matches this payload.
        stateFile.setText(root.stateText);
        const code = `local settings = ${root.payload}
local apply = _G.nothingLiquidGlassApply
if type(apply) == "function" then
    apply(settings)
elseif type(HOME) == "string" then
    dofile(HOME .. "/.config/hypr/custom/liquidglass.lua")
end`;
        if (runtimeApply.running) {
            root.pending = true;
            return;
        }
        root.pending = false;
        runtimeApply.command = ["hyprctl", "eval", code];
        runtimeApply.running = true;
    }

    property bool pending: false

    Timer { // a slider drag sends one update, not dozens
        id: applyTimer
        interval: 120
        onTriggered: root.apply()
    }

    Process {
        id: runtimeApply
        onExited: (exitCode, exitStatus) => {
            if (root.pending) {
                root.pending = false;
                root.apply();
            }
        }
    }

    function number(value, fallback) {
        let n = Number(value);
        if (!Number.isFinite(n))
            n = Number(fallback);
        return String(n);
    }

    function unit(value, fallback) {
        let n = Number(value);
        if (!Number.isFinite(n))
            n = Number(fallback);
        return String(Math.max(0, Math.min(1, n)));
    }

    function integer(value, fallback) {
        let n = Number(value);
        if (!Number.isFinite(n))
            n = Number(fallback);
        return String(Math.round(n));
    }

    function flag(value, fallback) {
        const v = value === undefined || value === null ? fallback : value;
        return v ? "1" : "0";
    }

    function color(value, fallback) {
        const normalize = raw => {
            let hex = String(raw ?? "").trim().replace(/^#/, "");
            if (hex.length === 6)
                hex += "FF";
            return /^[0-9a-fA-F]{8}$/.test(hex) ? hex : null;
        };
        const hex = normalize(value) ?? normalize(fallback) ?? "FFFFFFFF";
        return "0x" + hex.toLowerCase();
    }

    FileView {
        id: stateFile
        path: root.statePath
        blockWrites: true
        atomicWrites: true
        printErrors: false // it does not exist until the first apply()
    }
}