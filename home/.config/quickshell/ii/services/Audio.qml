pragma Singleton
pragma ComponentBehavior: Bound
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

/**
 * A nice wrapper for default Pipewire audio sink and source.
 */
Singleton {
    id: root

    // Misc props
    property bool ready: Pipewire.defaultAudioSink?.ready ?? false
    property PwNode sink: Pipewire.defaultAudioSink
    property PwNode source: Pipewire.defaultAudioSource
    readonly property real hardMaxValue: 2.00 // People keep joking about setting volume to 5172% so...
    property string audioTheme: Config.options.sounds.theme
    property real value: sink?.audio.volume ?? 0

    // Real hardware output routing (speaker vs connected Bluetooth
    // headset), independent of the PipeWire default sink above, which
    // stays pinned to easyeffects_sink -- see audio-output-switch.sh and
    // lib/audio-output-routing.sh for why a separate mechanism is needed.
    property string outputRoute: "speaker" // "speaker" | "headphones", mirrors ~/.config/audio-output-switch/route
    readonly property bool bluetoothOutputConnected: root.outputDevices.some(node => (node.name ?? "").startsWith("bluez_output."))

    function switchOutputToSpeaker() {
        Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/audio-output-switch.sh speaker"]);
    }

    function switchOutputToHeadphones() {
        Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/audio-output-switch.sh headphones"]);
    }

    function toggleOutputRoute() {
        Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/audio-output-switch.sh toggle"]);
    }

    function setOutputAuto() {
        Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/audio-output-switch.sh auto"]);
    }

    FileView {
        id: outputRouteFileView
        path: Qt.resolvedUrl(Directories.audioOutputRoutePath)
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const t = outputRouteFileView.text().trim();
            if (t === "speaker" || t === "headphones") root.outputRoute = t;
        }
    }
    
    function friendlyDeviceName(node) {
        return (node.nickname || node.description || Translation.tr("Unknown"));
    }
    function appNodeDisplayName(node) {
        return (node.properties["application.name"] || node.description || node.name)
    }

    // Lists
    function correctType(node, isSink) {
        return (node.isSink === isSink) && node.audio
    }
    function appNodes(isSink) {
        return Pipewire.nodes.values.filter((node) => { // Should be list<PwNode> but it breaks ScriptModel
            return root.correctType(node, isSink) && node.isStream
        })
    }
    function devices(isSink) {
        return Pipewire.nodes.values.filter(node => {
            return root.correctType(node, isSink) && !node.isStream
        })
    }
    readonly property list<var> outputAppNodes: root.appNodes(true)
    readonly property list<var> inputAppNodes: root.appNodes(false)
    readonly property list<var> outputDevices: root.devices(true)
    readonly property list<var> inputDevices: root.devices(false)

    // Signals
    signal sinkProtectionTriggered(string reason);

    // Controls
    //
    // NOTE: easyeffects_sink's own PipeWire volume/mute is COSMETIC.
    // EasyEffects reads audio for its DSP chain from easyeffects_sink's
    // *monitor* port, which is pre-fader by PipeWire convention, so
    // changing this virtual sink's volume never reaches the real
    // speakers/headphones. pushRealVolume/pushRealMute mirror the change
    // to whichever real hardware sink is actually active (see
    // ~/.local/bin/ee-volume.sh and ~/.config/wireplumber/
    // wireplumber.conf.d/51-bluetooth-audio-priority.conf).
    function pushRealVolume(vol) {
        Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/ee-volume.sh set " + Math.round(vol * 100) + "%"]);
    }

    function pushRealMute(muted) {
        Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/ee-volume.sh mute-set " + (muted ? 1 : 0)]);
    }

    // toggleMute/incrementVolume/decrementVolume deliberately do NOT
    // touch Audio.sink.audio.* directly. ee-volume.sh computes the new
    // value from the REAL sink's current value and writes the identical
    // result to both sinks (see its "SINGLE SOURCE OF TRUTH" comment) --
    // the slider/OSD update reactively once PipeWire reports the new
    // easyeffects_sink volume. Computing/writing the cosmetic value here
    // too would let it step independently of the real sink again and
    // silently drift out of sync (this happened once already).
    function toggleMute() {
        Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/ee-volume.sh mute-toggle"]);
    }

    function toggleMicMute() {
        Audio.source.audio.muted = !Audio.source.audio.muted
    }

    function incrementVolume() {
        Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/ee-volume.sh up 2%"]);
    }

    function decrementVolume() {
        Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/ee-volume.sh down 2%"]);
    }

    function setDefaultSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }

    // Internals
    PwObjectTracker {
        objects: [sink, source]
    }

    Connections { // Protection against sudden volume changes
        target: sink?.audio ?? null
        property bool lastReady: false
        property real lastVolume: 0
        function onVolumeChanged() {
            if (!Config.options.audio.protection.enable) return;
            const newVolume = sink.audio.volume;
            // when resuming from suspend, we should not write volume to avoid pipewire volume reset issues
            if (isNaN(newVolume) || newVolume === undefined || newVolume === null) {
                lastReady = false;
                lastVolume = 0;
                return;
            }
            if (!lastReady) {
                lastVolume = newVolume;
                lastReady = true;
                return;
            }
            const maxAllowedIncrease = Config.options.audio.protection.maxAllowedIncrease / 100; 
            const maxAllowed = Config.options.audio.protection.maxAllowed / 100;

            if (newVolume - lastVolume > maxAllowedIncrease) {
                sink.audio.volume = lastVolume;
                root.sinkProtectionTriggered(Translation.tr("Illegal increment"));
            } else if (newVolume > maxAllowed || newVolume > root.hardMaxValue) {
                root.sinkProtectionTriggered(Translation.tr("Exceeded max allowed"));
                sink.audio.volume = Math.min(lastVolume, maxAllowed);
            }
            lastVolume = sink.audio.volume;
        }
    }

    function playSystemSound(soundName) {
        const ogaPath = `/usr/share/sounds/${root.audioTheme}/stereo/${soundName}.oga`;
        const oggPath = `/usr/share/sounds/${root.audioTheme}/stereo/${soundName}.ogg`;

        // Try playing .oga first
        let command = [
            "ffplay",
            "-nodisp",
            "-autoexit",
            ogaPath
        ];
        Quickshell.execDetached(command);

        // Also try playing .ogg (ffplay will just fail silently if file doesn't exist)
        command = [
            "ffplay",
            "-nodisp",
            "-autoexit",
            oggPath
        ];
        Quickshell.execDetached(command);
    }
}
