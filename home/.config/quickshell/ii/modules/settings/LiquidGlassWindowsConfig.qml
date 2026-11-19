import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentSection {
    id: root
    icon: "window"
    title: Translation.tr("Application windows")
    Layout.fillWidth: true
    spacing: 6

    readonly property var windows: Config.options.appearance.liquidGlass.windows

    // Coherent application-window looks. None of these touch `enable`, the
    // shell's glass settings, or widget/layer glass.
    readonly property var windowPresets: [
        {
            id: "balanced",
            name: Translation.tr("Balanced"),
            icon: "balance",
            description: Translation.tr("Default readable glass: moderate blur, a soft tint and no extra frost."),
            values: {
                activeOpacity: 0.90, inactiveOpacity: 0.90, fullscreenOpacity: 0.90,
                blurStrength: 2.5, blurIterations: 3, noiseStrength: 0.02,
                refractionStrength: 0.6, refractionFlow: 0, refractionSpread: 1, chromaticAberration: 0.15,
                fresnelStrength: 0.6, fresnelTint: 0, fresnelColor: "#FFFFFF00",
                specularStrength: 0.8, specularAngle: 315,
                bevelStrength: 0, bevelColor: "#FFFFFF00", bevelShadow: 0,
                glassOpacity: 1, edgeThickness: 0.06, edgeThicknessPx: 0, edgeHeight: 0, fresnelReflection: 0,
                tintColor: "#10182066", lensDistortion: 0.5, selfSample: 0, xray: true,
                focusLight: 0, focusLightColor: "#FFFFFF00",
                frost: 0, frostBlur: 3,
                brightness: 0.78, contrast: 0.95, saturation: 0.85, vibrancy: 0.1,
                adaptiveDim: 0.3, adaptiveBoost: 0
            }
        },
        {
            id: "frosted",
            name: Translation.tr("Frosted"),
            icon: "ac_unit",
            description: Translation.tr("Stronger blur, grain and tint, with extra frost where other windows sit behind the glass."),
            values: {
                activeOpacity: 0.92, inactiveOpacity: 0.92, fullscreenOpacity: 0.90,
                blurStrength: 4.5, blurIterations: 4, noiseStrength: 0.12,
                refractionStrength: 0.6, refractionFlow: 0, refractionSpread: 1, chromaticAberration: 0.15,
                fresnelStrength: 0.65, fresnelTint: 0, fresnelColor: "#FFFFFF00",
                specularStrength: 0.8, specularAngle: 315,
                bevelStrength: 0, bevelColor: "#FFFFFF00", bevelShadow: 0,
                glassOpacity: 1, edgeThickness: 0.06, edgeThicknessPx: 0, edgeHeight: 0, fresnelReflection: 0,
                tintColor: "#10182080", lensDistortion: 0.5, selfSample: 0, xray: false,
                focusLight: 0, focusLightColor: "#FFFFFF00",
                frost: 0.8, frostBlur: 2.5,
                brightness: 0.84, contrast: 0.96, saturation: 0.82, vibrancy: 0.1,
                adaptiveDim: 0.35, adaptiveBoost: 0
            }
        },
        {
            id: "clear",
            name: Translation.tr("Clear"),
            icon: "lens_blur",
            description: Translation.tr("Light blur and tint with a stronger lens edge, so the content behind stays visible."),
            values: {
                activeOpacity: 0.90, inactiveOpacity: 0.90, fullscreenOpacity: 0.90,
                blurStrength: 0.8, blurIterations: 2, noiseStrength: 0,
                refractionStrength: 0.8, refractionFlow: 0.25, refractionSpread: 0.8, chromaticAberration: 0.2,
                fresnelStrength: 0.75, fresnelTint: 0, fresnelColor: "#FFFFFF00",
                specularStrength: 0.85, specularAngle: 315,
                bevelStrength: 0, bevelColor: "#FFFFFF00", bevelShadow: 0,
                glassOpacity: 1, edgeThickness: 0.08, edgeThicknessPx: 0, edgeHeight: 0, fresnelReflection: 0,
                tintColor: "#10182033", lensDistortion: 0.45, selfSample: 0, xray: false,
                focusLight: 0, focusLightColor: "#FFFFFF00",
                frost: 0, frostBlur: 3,
                brightness: 0.88, contrast: 0.98, saturation: 0.95, vibrancy: 0.08,
                adaptiveDim: 0.2, adaptiveBoost: 0
            }
        }
    ]

    readonly property var windowState: ({
        activeOpacity: windows.activeOpacity,
        inactiveOpacity: windows.inactiveOpacity,
        fullscreenOpacity: windows.fullscreenOpacity,
        blurStrength: windows.blurStrength,
        blurIterations: windows.blurIterations,
        noiseStrength: windows.noiseStrength,
        refractionStrength: windows.refractionStrength,
        refractionFlow: windows.refractionFlow,
        refractionSpread: windows.refractionSpread,
        chromaticAberration: windows.chromaticAberration,
        fresnelStrength: windows.fresnelStrength,
        fresnelTint: windows.fresnelTint,
        fresnelColor: windows.fresnelColor,
        specularStrength: windows.specularStrength,
        specularAngle: windows.specularAngle,
        bevelStrength: windows.bevelStrength,
        bevelColor: windows.bevelColor,
        bevelShadow: windows.bevelShadow,
        glassOpacity: windows.glassOpacity,
        edgeThickness: windows.edgeThickness,
        edgeThicknessPx: windows.edgeThicknessPx,
        edgeHeight: windows.edgeHeight,
        fresnelReflection: windows.fresnelReflection,
        tintColor: windows.tintColor,
        lensDistortion: windows.lensDistortion,
        selfSample: windows.selfSample,
        xray: windows.xray,
        focusLight: windows.focusLight,
        focusLightColor: windows.focusLightColor,
        frost: windows.frost,
        frostBlur: windows.frostBlur,
        brightness: windows.brightness,
        contrast: windows.contrast,
        saturation: windows.saturation,
        vibrancy: windows.vibrancy,
        adaptiveDim: windows.adaptiveDim,
        adaptiveBoost: windows.adaptiveBoost
    })

    readonly property string activePreset: {
        for (let i = 0; i < windowPresets.length; ++i) {
            if (presetMatches(windowPresets[i].values))
                return windowPresets[i].id;
        }
        return "";
    }

    readonly property string activePresetName: {
        for (let i = 0; i < windowPresets.length; ++i) {
            if (windowPresets[i].id === activePreset)
                return windowPresets[i].name;
        }
        return "";
    }

    function presetMatches(values) {
        for (const key in values) {
            const expected = values[key];
            const actual = root.windowState[key];
            if (typeof expected === "number") {
                if (typeof actual !== "number" || Math.abs(actual - expected) > 0.0001)
                    return false;
            } else if (String(actual).toUpperCase() !== String(expected).toUpperCase()) {
                return false;
            }
        }
        return true;
    }

    function applyWindowPreset(values) {
        if (!Config.ready)
            return;
        for (const key in values)
            root.windows[key] = values[key];
    }

    // Writes only after the shell config has loaded, so the controls' initial
    // values never overwrite what is already saved on disk.
    component WindowSlider: ConfigSlider {
        property var target
        property string key
        textWidth: 190

        onValueChanged: {
            if (Config.ready && target)
                target[key] = value;
        }
    }

    component WindowValueSlider: WindowSlider {
        usePercentTooltip: false
    }

    component WindowSwitch: ConfigSwitch {
        property var target
        property string key

        onCheckedChanged: {
            if (Config.ready && target)
                target[key] = checked;
        }
    }

    component ColorField: ColumnLayout {
        id: colorField

        property string label
        property string value
        property string key
        property var target
        property bool invalid: false

        Layout.fillWidth: true
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            StyledText {
                Layout.preferredWidth: 190
                text: colorField.label
                color: Appearance.colors.colOnSecondaryContainer
            }

            MaterialTextField {
                id: colorInput
                Layout.fillWidth: true
                placeholderText: "#RRGGBB or #RRGGBBAA"
                Accessible.name: colorField.label
                text: colorField.value

                onEditingFinished: {
                    const trimmed = text.trim();
                    if (/^#?[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(trimmed)) {
                        let hex = trimmed.startsWith("#") ? trimmed.slice(1) : trimmed;
                        if (hex.length === 6)
                            hex += "FF";
                        if (Config.ready && colorField.target)
                            colorField.target[colorField.key] = "#" + hex.toUpperCase();
                        colorField.invalid = false;
                    } else {
                        colorField.invalid = true;
                    }
                }

                onTextChanged: colorField.invalid = false
            }
        }

        StyledText {
            visible: colorField.invalid
            text: Translation.tr("Enter a colour as #RRGGBB or #RRGGBBAA")
            color: Appearance.m3colors.m3error
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
    }

    WindowSwitch {
        buttonIcon: "window"
        text: Translation.tr("Window glass")
        target: root.windows
        key: "enable"
        checked: root.windows.enable
        StyledToolTip {
            text: Translation.tr("Enable glass on application windows without changing the shell's glass")
        }
    }

    ContentSubsection {
        visible: root.windows.enable
        title: Translation.tr("Window presets")
        tooltip: Translation.tr("Ready-made looks for application windows only. Shell glass, the bar, the dock and widgets keep their own settings.")

        ConfigSelectionArray {
            currentValue: root.activePreset
            onSelected: newValue => {
                for (let i = 0; i < root.windowPresets.length; ++i) {
                    if (root.windowPresets[i].id === newValue) {
                        root.applyWindowPreset(root.windowPresets[i].values);
                        break;
                    }
                }
            }
            options: [
                {
                    displayName: Translation.tr("Balanced"),
                    icon: "balance",
                    value: "balanced"
                },
                {
                    displayName: Translation.tr("Frosted"),
                    icon: "ac_unit",
                    value: "frosted"
                },
                {
                    displayName: Translation.tr("Clear"),
                    icon: "lens_blur",
                    value: "clear"
                }
            ]
        }

        StyledText {
            Layout.fillWidth: true
            text: root.activePreset !== ""
                ? Translation.tr("Preset: %1 (application windows only)").arg(root.activePresetName)
                : Translation.tr("Custom window settings")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
    }

    ContentSubsection {
        visible: root.windows.enable
        title: Translation.tr("Window opacity")
        tooltip: Translation.tr("Window opacity lets the desktop show through; glass opacity controls the effect drawn by the compositor. Window opacity is limited to 20% minimum so windows cannot be hidden completely")

        WindowSlider {
            text: Translation.tr("Focused window")
            buttonIcon: "filter_center_focus"
            from: 0.2
            to: 1
            stopIndicatorValues: [0.9]
            target: root.windows
            key: "activeOpacity"
            value: root.windows.activeOpacity
        }

        WindowSlider {
            text: Translation.tr("Unfocused window")
            buttonIcon: "filter_none"
            from: 0.2
            to: 1
            stopIndicatorValues: [0.9]
            target: root.windows
            key: "inactiveOpacity"
            value: root.windows.inactiveOpacity
        }

        WindowSlider {
            text: Translation.tr("Fullscreen window")
            buttonIcon: "fullscreen"
            from: 0.2
            to: 1
            stopIndicatorValues: [0.9]
            target: root.windows
            key: "fullscreenOpacity"
            value: root.windows.fullscreenOpacity
        }

        WindowSlider {
            text: Translation.tr("Glass opacity")
            buttonIcon: "opacity"
            from: 0
            to: 1
            stopIndicatorValues: [1]
            target: root.windows
            key: "glassOpacity"
            value: root.windows.glassOpacity
        }
    }

    ContentSubsection {
        visible: root.windows.enable
        title: Translation.tr("Window blur & frost")
        tooltip: Translation.tr("Blur softens the backdrop; frost adds more blur only where other windows are behind the glass")

        WindowValueSlider {
            text: Translation.tr("Blur strength")
            buttonIcon: "blur_on"
            from: 0
            to: 8
            stopIndicatorValues: [2, 4]
            target: root.windows
            key: "blurStrength"
            value: root.windows.blurStrength
        }

        ContentSubsection {
            title: Translation.tr("Blur passes")
            ConfigSelectionArray {
                currentValue: root.windows.blurIterations
                onSelected: newValue => {
                    if (Config.ready)
                        root.windows.blurIterations = newValue;
                }
                options: [
                    { displayName: "1", icon: "filter_1", value: 1 },
                    { displayName: "2", icon: "filter_2", value: 2 },
                    { displayName: "3", icon: "filter_3", value: 3 },
                    { displayName: "4", icon: "filter_4", value: 4 },
                    { displayName: "5", icon: "filter_5", value: 5 }
                ]
            }
        }

        WindowSlider {
            text: Translation.tr("Frosted grain")
            buttonIcon: "grain"
            from: 0
            to: 1
            stopIndicatorValues: [0.12]
            target: root.windows
            key: "noiseStrength"
            value: root.windows.noiseStrength
        }

        WindowSlider {
            text: Translation.tr("Frost over windows")
            buttonIcon: "ac_unit"
            from: 0
            to: 1
            target: root.windows
            key: "frost"
            value: root.windows.frost
        }

        WindowValueSlider {
            text: Translation.tr("Frost blur")
            buttonIcon: "blur_linear"
            from: 0
            to: 10
            stopIndicatorValues: [3]
            target: root.windows
            key: "frostBlur"
            value: root.windows.frostBlur
        }
    }

    ContentSubsection {
        visible: root.windows.enable
        title: Translation.tr("Window colour & tone")
        tooltip: Translation.tr("Tint and tone-map the blurred backdrop to keep window content readable")

        ColorField {
            label: Translation.tr("Tint colour")
            value: root.windows.tintColor
            target: root.windows
            key: "tintColor"
        }

        WindowValueSlider {
            text: Translation.tr("Brightness")
            buttonIcon: "brightness_6"
            from: 0
            to: 2
            stopIndicatorValues: [1]
            target: root.windows
            key: "brightness"
            value: root.windows.brightness
        }

        WindowValueSlider {
            text: Translation.tr("Contrast")
            buttonIcon: "contrast"
            from: 0
            to: 2
            stopIndicatorValues: [1]
            target: root.windows
            key: "contrast"
            value: root.windows.contrast
        }

        WindowSlider {
            text: Translation.tr("Saturation")
            buttonIcon: "palette"
            from: 0
            to: 1
            stopIndicatorValues: [0.85]
            target: root.windows
            key: "saturation"
            value: root.windows.saturation
        }

        WindowSlider {
            text: Translation.tr("Vibrancy")
            buttonIcon: "colorize"
            from: 0
            to: 1
            target: root.windows
            key: "vibrancy"
            value: root.windows.vibrancy
        }

        WindowSlider {
            text: Translation.tr("Dim bright backdrops")
            buttonIcon: "dark_mode"
            from: 0
            to: 1
            target: root.windows
            key: "adaptiveDim"
            value: root.windows.adaptiveDim
        }

        WindowSlider {
            text: Translation.tr("Lift dark backdrops")
            buttonIcon: "light_mode"
            from: 0
            to: 1
            target: root.windows
            key: "adaptiveBoost"
            value: root.windows.adaptiveBoost
        }
    }

    ContentSubsection {
        visible: root.windows.enable
        title: Translation.tr("Window refraction & lens")
        tooltip: Translation.tr("Bend the backdrop at the glass edge and magnify the centre")

        WindowValueSlider {
            text: Translation.tr("Refraction")
            buttonIcon: "water_drop"
            from: 0
            to: 8
            stopIndicatorValues: [0.6, 1]
            target: root.windows
            key: "refractionStrength"
            value: root.windows.refractionStrength
        }

        WindowSlider {
            text: Translation.tr("Refraction direction")
            buttonIcon: "open_with"
            from: 0
            to: 1
            stopIndicatorValues: [0.5]
            target: root.windows
            key: "refractionFlow"
            value: root.windows.refractionFlow
        }

        WindowSlider {
            text: Translation.tr("Refraction depth")
            buttonIcon: "filter_tilt_shift"
            from: 0
            to: 1
            target: root.windows
            key: "refractionSpread"
            value: root.windows.refractionSpread
        }

        WindowSlider {
            text: Translation.tr("Chromatic aberration")
            buttonIcon: "gradient"
            from: 0
            to: 1
            target: root.windows
            key: "chromaticAberration"
            value: root.windows.chromaticAberration
        }

        WindowSlider {
            text: Translation.tr("Lens distortion")
            buttonIcon: "lens"
            from: 0
            to: 1
            target: root.windows
            key: "lensDistortion"
            value: root.windows.lensDistortion
        }
    }

    ContentSubsection {
        visible: root.windows.enable
        title: Translation.tr("Window edges")
        tooltip: Translation.tr("Width of the bending edge, or a crisp lens edge with its own reflection")

        WindowSlider {
            text: Translation.tr("Edge width (relative)")
            buttonIcon: "border_inner"
            from: 0
            to: 0.15
            usePercentTooltip: false
            target: root.windows
            key: "edgeThickness"
            value: root.windows.edgeThickness
        }

        WindowValueSlider {
            text: Translation.tr("Edge width (pixels)")
            buttonIcon: "straighten"
            from: 0
            to: 48
            stopIndicatorValues: [0]
            target: root.windows
            key: "edgeThicknessPx"
            value: root.windows.edgeThicknessPx
        }

        WindowValueSlider {
            text: Translation.tr("Lens edge height")
            buttonIcon: "height"
            from: 0
            to: 60
            stopIndicatorValues: [0]
            target: root.windows
            key: "edgeHeight"
            value: root.windows.edgeHeight
        }

        WindowSlider {
            text: Translation.tr("Lens edge reflection")
            buttonIcon: "flip"
            from: 0
            to: 1
            target: root.windows
            key: "fresnelReflection"
            value: root.windows.fresnelReflection
        }
    }

    ContentSubsection {
        visible: root.windows.enable
        title: Translation.tr("Window rim light")
        tooltip: Translation.tr("Highlights that make the glass edge catch light")

        WindowSlider {
            text: Translation.tr("Edge glow")
            buttonIcon: "lightbulb"
            from: 0
            to: 1
            target: root.windows
            key: "fresnelStrength"
            value: root.windows.fresnelStrength
        }

        WindowSlider {
            text: Translation.tr("Edge glow tint")
            buttonIcon: "color_lens"
            from: 0
            to: 1
            target: root.windows
            key: "fresnelTint"
            value: root.windows.fresnelTint
        }

        ColorField {
            label: Translation.tr("Edge glow colour")
            value: root.windows.fresnelColor
            target: root.windows
            key: "fresnelColor"
        }

        WindowSlider {
            text: Translation.tr("Specular highlight")
            buttonIcon: "flare"
            from: 0
            to: 1
            target: root.windows
            key: "specularStrength"
            value: root.windows.specularStrength
        }

        WindowValueSlider {
            text: Translation.tr("Specular angle")
            buttonIcon: "rotate_right"
            from: 0
            to: 360
            stopIndicatorValues: [0, 90, 180, 270]
            target: root.windows
            key: "specularAngle"
            value: root.windows.specularAngle
        }
    }

    ContentSubsection {
        visible: root.windows.enable
        title: Translation.tr("Window bevel")
        tooltip: Translation.tr("The thin lit line along the glass edge")

        WindowSlider {
            text: Translation.tr("Bevel line")
            buttonIcon: "line_weight"
            from: 0
            to: 1
            target: root.windows
            key: "bevelStrength"
            value: root.windows.bevelStrength
        }

        ColorField {
            label: Translation.tr("Bevel colour")
            value: root.windows.bevelColor
            target: root.windows
            key: "bevelColor"
        }

        WindowSlider {
            text: Translation.tr("Bevel shadow")
            buttonIcon: "brightness_3"
            from: 0
            to: 1
            target: root.windows
            key: "bevelShadow"
            value: root.windows.bevelShadow
        }
    }

    ContentSubsection {
        visible: root.windows.enable
        title: Translation.tr("Window focus light")
        tooltip: Translation.tr("Light along the glass edge of the active window")

        WindowSlider {
            text: Translation.tr("Focus light")
            buttonIcon: "highlight_alt"
            from: 0
            to: 1
            target: root.windows
            key: "focusLight"
            value: root.windows.focusLight
        }

        ColorField {
            label: Translation.tr("Focus light colour")
            value: root.windows.focusLightColor
            target: root.windows
            key: "focusLightColor"
        }
    }

    ContentSubsection {
        visible: root.windows.enable
        title: Translation.tr("Window advanced")
        tooltip: Translation.tr("Sampling and rendering options. They cost GPU time, so leave them off unless needed")

        WindowSlider {
            text: Translation.tr("Include own content")
            buttonIcon: "content_copy"
            from: 0
            to: 1
            target: root.windows
            key: "selfSample"
            value: root.windows.selfSample
        }

        WindowSwitch {
            buttonIcon: "panorama"
            text: Translation.tr("X-ray")
            target: root.windows
            key: "xray"
            checked: root.windows.xray
            StyledToolTip {
                text: Translation.tr("Show only the wallpaper through the glass, never the windows behind it")
            }
        }
    }
}
