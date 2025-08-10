pragma Singleton

import qs.config
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import Quickshell.Io

Singleton {
    id: root

    Process {
        id: audioPortProcess
        command: ["pactl", "list", "sinks"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.includes("Active Port: analog-output-headphones")) {
                    isHeadphonesIcon = true;
                } else if (text.includes("Active Port: analog-output-lineout")) {
                    isHeadphonesIcon = false;
                }
            }
        }
    }

    function init() {
        audioPortProcess.running = true;
    }

    readonly property var nodes: Pipewire.nodes.values.reduce((acc, node) => {
        if (!node.isStream) {
            if (node.isSink)
                acc.sinks.push(node);
            else if (node.audio)
                acc.sources.push(node);
        }
        return acc;
    }, {
        sources: [],
        sinks: []
    })

    readonly property list<PwNode> sinks: nodes.sinks
    readonly property list<PwNode> sources: nodes.sources

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool muted: !!sink?.audio?.muted
    readonly property real volume: sink?.audio?.volume ?? 0

    function setVolume(newVolume: real): void {
        if (sink?.ready && sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1, newVolume));
        }
    }

    function incrementVolume(amount: real): void {
        setVolume(volume + (amount || Config.services.audioIncrement));
    }

    function decrementVolume(amount: real): void {
        setVolume(volume - (amount || Config.services.audioIncrement));
    }

    function setAudioSink(newSink: PwNode): void {
        Pipewire.preferredDefaultAudioSink = newSink;
    }

    function setAudioSource(newSource: PwNode): void {
        Pipewire.preferredDefaultAudioSource = newSource;
    }

    property bool isHeadphonesIcon: false

    function toggleAudioPort(): void {
        const speakers = "analog-output-lineout";
        const headphones = "analog-output-headphones";

        const newPort = root.isHeadphonesIcon ? speakers : headphones;
        root.isHeadphonesIcon = !root.isHeadphonesIcon;

        Quickshell.execDetached(["pactl", "set-sink-port", "@DEFAULT_SINK@", newPort]);
    }

    PwObjectTracker {
        objects: [...root.sinks, ...root.sources]
    }

    Component.onCompleted: init()
}
