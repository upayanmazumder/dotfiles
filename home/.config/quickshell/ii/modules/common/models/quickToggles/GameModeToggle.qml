import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common.models.hyprland
import qs.services

QuickToggleModel {
    id: root
    name: Translation.tr("Game mode")
    toggled: !confOpt.value
    icon: "sports_esports"

    mainAction: () => {
        if (!root.toggled) {
            HyprlandConfig.setMany({
                "animations:enabled": false,
                "decoration:shadow:enabled": false,
                "decoration:blur:enabled": false,
                "general:gaps_in": 0,
                "general:gaps_out": 0,
                "general:border_size": 1,
                "decoration:rounding": 0,
                "general:allow_tearing": true
            });
        } else {
            HyprlandConfig.resetMany([ //
                "animations:enabled", //
                "decoration:shadow:enabled", //
                "decoration:blur:enabled", //
                "general:gaps_in", //
                "general:gaps_out", //
                "general:border_size", //
                "decoration:rounding", //
                "general:allow_tearing", //
            ]);
        }
    }

    HyprlandConfigOption {
        id: confOpt
        key: "animations:enabled"
        // The compositor restores shadows during reload. Apply this after the read.
        onFetchingChanged: {
            if (!fetching && value === false)
                Quickshell.execDetached(["hyprctl", "eval", "hl.config({decoration={shadow={enabled=false}}})"]);
        }
    }

    tooltipText: Translation.tr("Game mode")
}