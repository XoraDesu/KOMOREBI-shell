// ─────────────────────────────────────────────────────────────────────────────
// KOMOREBI — StatusPill.qml
// Reusable status chip: icon + live value from a shell command.
// Designed to be stacked in the expanded island dashboard.
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import KOMOREBI.Theme 1.0

Rectangle {
    id: pill

    // ── API ───────────────────────────────────────────────────────────────────
    required property string icon    // Nerd Font glyph
    required property string label   // Short label (e.g. "Vol")
    required property string source  // Shell command to poll

    // ── Geometry ──────────────────────────────────────────────────────────────
    implicitWidth:  pillRow.implicitWidth + Theme.sp3 * 2
    implicitHeight: 28
    radius:         Theme.radiusFull
    color:          Qt.rgba(Theme.primaryContainer.r,
                            Theme.primaryContainer.g,
                            Theme.primaryContainer.b, 0.5)
    border.color:   Theme.outlineVariant
    border.width:   1

    // ── Poll interval ─────────────────────────────────────────────────────────
    property string _value: "…"

    Timer {
        interval: 2000
        repeat:   true
        running:  true
        triggeredOnStart: true
        onTriggered: poller.running = true
    }

    Process {
        id: poller
        command: ["bash", "-c", pill.source]
        stdout: StdoutCollector {
            id: pollerOut
        }
        onExited: pill._value = pollerOut.text.trim() || "–"
    }

    // ── Content ───────────────────────────────────────────────────────────────
    RowLayout {
        id: pillRow
        anchors.centerIn: parent
        spacing: Theme.sp1

        Text {
            text:           pill.icon
            font.family:    "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color:          Theme.primary
        }
        Text {
            text:           pill._value
            font.family:    Theme.fontFamilyUI
            font.pixelSize: Theme.labelSmall
            font.weight:    Font.Medium
            color:          Theme.onPrimaryContainer
        }
    }

    // ── Hover micro-animation ─────────────────────────────────────────────────
    property bool _hovered: false
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: pill._hovered = true
        onExited:  pill._hovered = false
    }
    scale: _hovered ? 1.05 : 1.0
    Behavior on scale {
        NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutBack }
    }
}
