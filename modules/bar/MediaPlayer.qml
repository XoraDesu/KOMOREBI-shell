// ─────────────────────────────────────────────────────────────────────────────
// KOMOREBI — MediaPlayer.qml
// Wabi-Sabi media player panel for the expanded island.
//
// Layout (top → bottom):
//   ┌──────────────────────────────────────────────────────┐
//   │  MEDIA                                  ◀  ⏸  ▶    │  ← header + transport row
//   │  Track Title                                          │
//   │  Artist · Album                                       │
//   │  ──────────────────── progress ──────────────────── │
//   │  ┌────────────────────────────────────────────────┐  │
//   │  │                                                │  │
//   │  │              LYRICS AREA                       │  │  ← lyrics zone
//   │  │                                                │  │
//   │  └────────────────────────────────────────────────┘  │
//   └──────────────────────────────────────────────────────┘
//
// Data source: MPRIS2 via `playerctl` (standard on most Linux setups).
// Lyrics: placeholder scrollable area — synchronized lyric backend
//         to be implemented in a future session (e.g. klyrics / sptlrx).
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import KOMOREBI.Theme 1.0

Item {
    id: root

    // ── MPRIS state ───────────────────────────────────────────────────────────
    property string trackTitle:  "—"
    property string trackArtist: "—"
    property string trackAlbum:  ""
    property bool   isPlaying:   false
    property real   position:    0     // 0.0 – 1.0 normalised
    property real   duration:    0     // seconds (raw, for display)
    property string posStr:      "0:00"
    property string durStr:      "0:00"

    // Lyrics lines (future: populated by lyric engine)
    property var    lyrics:      []
    property int    currentLine: -1

    // ── Playerctl poll ────────────────────────────────────────────────────────
    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            metaProc.running   = true
            statusProc.running = true
            posProc.running    = true
        }
    }

    // Metadata (title · artist · album · length)
    Process {
        id: metaProc
        command: ["bash", "-c",
            "playerctl metadata --format '{{title}}\\n{{artist}}\\n{{album}}\\n{{mpris:length}}' 2>/dev/null"
        ]
        stdout: StdoutCollector { id: metaOut }
        onExited: function(code) {
            if (code !== 0) { root.trackTitle = "No player"; root.trackArtist = "—"; return }
            var lines = metaOut.text.split("\n")
            root.trackTitle  = lines[0] || "—"
            root.trackArtist = lines[1] || "—"
            root.trackAlbum  = lines[2] || ""
            var durUs = parseFloat(lines[3]) || 0
            root.duration = durUs / 1e6
            root.durStr   = _fmtSec(root.duration)
        }
    }

    // Playback status
    Process {
        id: statusProc
        command: ["playerctl", "status"]
        stdout: StdoutCollector { id: statusOut }
        onExited: function(code) {
            root.isPlaying = (statusOut.text.trim() === "Playing")
        }
    }

    // Position
    Process {
        id: posProc
        command: ["playerctl", "position"]
        stdout: StdoutCollector { id: posOut }
        onExited: function(code) {
            if (code !== 0) { root.position = 0; return }
            var sec = parseFloat(posOut.text.trim()) || 0
            root.position = root.duration > 0 ? Math.min(1, sec / root.duration) : 0
            root.posStr   = _fmtSec(sec)
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    function _fmtSec(s) {
        var m = Math.floor(s / 60)
        var r = Math.floor(s % 60)
        return m + ":" + (r < 10 ? "0" + r : r)
    }

    function _prev()   { Process { command: ["playerctl", "previous"]; running: true } }
    function _toggle() { Process { command: ["playerctl", "play-pause"]; running: true } }
    function _next()   { Process { command: ["playerctl", "next"];     running: true } }

    // ── Layout ────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.sp2

        // ── Header row: label + transport controls ────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp2

            Text {
                text: "MEDIA"
                font.family:      Theme.fontFamily
                font.pixelSize:   Theme.labelSmall
                font.letterSpacing: 3.0
                font.weight:      Font.Medium
                color:            Theme.outline
            }

            Item { Layout.fillWidth: true }

            // ── Transport buttons ─────────────────────────────────────────────
            Repeater {
                model: [
                    { glyph: "󰒮", action: root._prev   },
                    { glyph: root.isPlaying ? "󰏤" : "󰐊", action: root._toggle },
                    { glyph: "󰒭", action: root._next   }
                ]
                delegate: TransportButton {
                    required property var modelData
                    glyph:    modelData.glyph
                    onAction: modelData.action()
                }
            }
        }

        // ── Track info ────────────────────────────────────────────────────────
        Text {
            id: titleText
            text:           root.trackTitle
            font.family:    Theme.fontFamilyUI
            font.pixelSize: Theme.bodyMedium
            font.weight:    Font.Medium
            color:          Theme.onSurface
            elide:          Text.ElideRight
            Layout.fillWidth: true

            Behavior on text {
                // Flicker-dissolve on track change
                SequentialAnimation {
                    NumberAnimation { target: titleText; property: "opacity"; to: 0;   duration: Theme.durationFast }
                    PropertyAction  { }
                    NumberAnimation { target: titleText; property: "opacity"; to: 1.0; duration: Theme.durationSnap }
                }
            }
        }

        Text {
            text: root.trackArtist + (root.trackAlbum ? " · " + root.trackAlbum : "")
            font.family:    Theme.fontFamilyUI
            font.pixelSize: Theme.labelMedium
            color:          Theme.outline
            elide:          Text.ElideRight
            Layout.fillWidth: true
        }

        // ── Progress bar + timestamps ─────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.sp1

            // Scrub bar
            Item {
                Layout.fillWidth: true
                height: 3

                // Track
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusFull
                    color:  Theme.outlineVariant
                    opacity: 0.3
                }

                // Fill
                Rectangle {
                    width:  parent.width * root.position
                    height: parent.height
                    radius: Theme.radiusFull
                    color:  Theme.primary
                    Behavior on width {
                        NumberAnimation {
                            duration:    Theme.durationSnap
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
                        }
                    }
                }

                // Scrub interaction
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        var ratio = mouse.x / parent.width
                        var sec   = ratio * root.duration
                        Process {
                            command: ["playerctl", "position", sec.toFixed(1)]
                            running: true
                        }
                    }
                }
            }

            // Timestamps
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text:           root.posStr
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.labelSmall
                    color:          Theme.outline
                }
                Item { Layout.fillWidth: true }
                Text {
                    text:           root.durStr
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.labelSmall
                    color:          Theme.outline
                }
            }
        }

        // ── Lyrics placeholder ────────────────────────────────────────────────
        // Framed with a subtle outline; will be populated by lyric engine later.
        // Wabi-Sabi: the empty space IS the design — generous, intentional void.
        Rectangle {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            radius:      Theme.radiusMedium
            color:       Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                                 Theme.surfaceVariant.b, 0.25)
            border.color: Theme.outlineVariant
            border.width: 1
            clip: true

            // When lyrics are loaded: scrollable line list
            ListView {
                id: lyricList
                anchors.fill: parent
                anchors.margins: Theme.sp3
                model: root.lyrics.length > 0 ? root.lyrics : [""]
                clip: true

                delegate: Text {
                    required property var modelData
                    required property int index
                    width:          lyricList.width
                    text:           modelData
                    font.family:    Theme.fontFamilyUI
                    font.pixelSize: Theme.bodySmall
                    font.italic:    true
                    color:          index === root.currentLine
                                    ? Theme.onSurface
                                    : Theme.outline
                    opacity:        index === root.currentLine ? 1.0 : 0.45
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    topPadding: Theme.sp1
                    Behavior on opacity {
                        NumberAnimation { duration: Theme.durationSnap }
                    }
                    Behavior on color {
                        ColorAnimation { duration: Theme.durationSnap }
                    }
                }

                // Auto-scroll to current lyric line
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Center)
                currentIndex: root.currentLine >= 0 ? root.currentLine : 0
            }

            // Placeholder text when no lyrics
            Text {
                anchors.centerIn: parent
                visible: root.lyrics.length === 0
                text: "待つ\nwaiting for lyrics"
                font.family:    Theme.fontFamilyUI
                font.pixelSize: Theme.labelMedium
                font.italic:    true
                color:          Theme.outline
                opacity:        0.35
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.8
            }
        }
    }

    // ── TransportButton inline component ─────────────────────────────────────
    component TransportButton: Item {
        id: btn
        implicitWidth:  28
        implicitHeight: 28

        required property string glyph
        signal action()

        property bool _hov: false

        Rectangle {
            anchors.centerIn: parent
            width:  btn._hov ? 28 : 24
            height: width
            radius: Theme.radiusFull
            color:  btn._hov
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    : "transparent"
            Behavior on width  { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutBack } }
            Behavior on color  { ColorAnimation  { duration: Theme.durationFast } }
        }

        Text {
            anchors.centerIn: parent
            text:           btn.glyph
            font.family:    "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color:          btn._hov ? Theme.primary : Theme.onSurface
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: btn._hov = true
            onExited:  btn._hov = false
            onClicked: btn.action()
        }
    }
}
