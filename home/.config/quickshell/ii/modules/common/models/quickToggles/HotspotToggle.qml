import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions

QuickToggleModel {
    id: root
    readonly property string script: FileUtils.trimFileProtocol(Directories.home) + "/Scripts/bin/hotspot"
    property bool needsRestart: false

    name: Translation.tr("Hotspot")
    icon: "wifi_tethering"
    statusText: actionProcess.running ? Translation.tr("Please wait") : needsRestart ? Translation.tr("Restart required") : toggled ? Translation.tr("On") : Translation.tr("Off")
    tooltipText: needsRestart ? Translation.tr("Restart hotspot") : Translation.tr("Hotspot")
    available: !actionProcess.running
    mainAction: () => {
        if (!actionProcess.running)
            actionProcess.exec([root.script, root.needsRestart ? "restart" : root.toggled ? "stop" : "--daemon"])
    }

    function refresh() {
        if (!statusProcess.running && !actionProcess.running)
            statusProcess.running = true
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: statusProcess
        command: [root.script, "status"]
        onExited: (exitCode, exitStatus) => {
            root.needsRestart = exitCode === 2
            root.toggled = exitCode === 0 || root.needsRestart
        }
    }

    Process {
        id: actionProcess
        onExited: (exitCode, exitStatus) => {
            root.refresh()
            if (exitCode !== 0)
                Quickshell.execDetached(["notify-send", Translation.tr("Hotspot"), Translation.tr("Could not change hotspot. Check authentication and create_ap.")])
        }
    }
}
