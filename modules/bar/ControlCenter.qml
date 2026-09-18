// ─────────────────────────────────────────────────────────────────────────────
// KOMOREBI — ControlCenter.qml
// Minimalist control panel: volume, brightness, Wi-Fi toggle, DnD toggle.
//
// Design principle — Wabi-Sabi restraint:
//   One idea per row. No icons competing for attention. Generous whitespace.
//   The sliders are the hero element; toggles are secondary, pill-shaped.
//
// Slider anatomy:
//   icon  |  label  |  [══════════●──────────]  |  value
//   The "thumb" is a 1px-wide vertical line (mechanical, not a bubble).
//
// All interactions use cyberpunk durationFast / durationSnap beziers.
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    // ── State ─────────────────────────────────────────────────────────────────
    property int  volumePercent:     50
    property int  brightnessPercent: 70
    property bool wifiEnabled:       true
    property bool dndEnabled:        false

    // ── Poll current values once on show ─────────────────────────────────────
    Component.onCompleted: {
        volReadProc.running = true
        briReadProc.running = true
        wifiReadProc.running = true
    }

    Process {
        id: volReadProc
        command: ["bash", "-c",
            "pactl get-sink-volume @DEFAULT_SINK@ | grep -Po '\\d+(?=%)' | head -1"
        ]
        stdout: StdoutCollector { id: volOut }
        onExited: function(code) {
            if (code === 0) {
                var v = parseInt(volOut.text.trim())
                if (!isNaN(v)) root.volumePercent = Math.max(0, Math.min(100, v))
            }
        }
    }

    Process {
        id: briReadProc
        command: ["bash", "-c",
            "brightnessctl -m | awk -F, '{print $4}' | tr -d '%'"
        ]
        stdout: StdoutCollector { id: briOut }
        onExited: function(code) {
            if (code === 0) {
                var v = parseInt(briOut.text.trim())
                if (!isNaN(v)) root.brightnessPercent = Math.max(0, Math.min(100, v))
            }
        }
    }

    Process {
        id: wifiReadProc
        command: ["bash", "-c", "nmcli radio wifi"]
        stdout: StdoutCollector { id: wifiOut }
        onExited: function(code) {
            root.wifiEnabled = (wifiOut.text.trim() === "enabled")
        }
    }

    // ── Layout ────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.sp3

        // Header
        Text {
            text: "CONTROLS"
            font.family:      Theme.fontFamily
            font.pixelSize:   Theme.labelSmall
            font.letterSpacing: 3.0
            font.weight:      Font.Medium
            color:            Theme.outline
            Layout.topMargin: Theme.sp1
        }

        // ── Volume slider ─────────────────────────────────────────────────────
        ControlSlider {
            icon:       "󰕾"
            label:      "VOL"
            value:      root.volumePercent
            accent:     Theme.primary
            Layout.fillWidth: true
            onMoved: function(v) {
                root.volumePercent = v
                Process {
                    command: ["pactl", "set-sink-volume", "@DEFAULT_SINK@", v + "%"]
                    running: true
                }
            }
        }

        // ── Brightness slider ─────────────────────────────────────────────────
        ControlSlider {
            icon:       "󰃞"
            label:      "BRI"
            value:      root.brightnessPercent
            accent:     Theme.secondary
            Layout.fillWidth: true
            onMoved: function(v) {
                root.brightnessPercent = v
                Process {
                    command: ["brightnessctl", "set", v + "%"]
                    running: true
                }
            }
        }

        // ── Divider ───────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color:   Theme.outlineVariant
            opacity: 0.3
        }

        // ── Toggle row ────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp2

            ControlToggle {
                icon:     root.wifiEnabled ? "󰖩" : "󰖪"
                label:    "Wi-Fi"
                enabled_: root.wifiEnabled
                onToggled: function(on) {
                    root.wifiEnabled = on
                    Process {
                        command: ["nmcli", "radio", "wifi", on ? "on" : "off"]
                        running: true
                    }
                }
            }

            ControlToggle {
                icon:     root.dndEnabled ? "󰂛" : "󰂚"
                label:    "DnD"
                enabled_: root.dndEnabled
                onToggled: function(on) {
                    root.dndEnabled = on
                    // DnD backend hook — future: dunstctl / mako rule
                    Process {
                        command: ["bash", "-c",
                            on ? "dunstctl set-paused true" : "dunstctl set-paused false"
                        ]
                        running: true
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }

        Item { Layout.fillHeight: true }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ControlSlider — inline component
    // Mechanical thumb: a 1-px vertical rule, not a circle.
    // Dragging snaps the fill in real-time; release fires onMoved.
    // ─────────────────────────────────────────────────────────────────────────
    component ControlSlider: Item {
        id: slider

        required property string icon
        required property string label
        required property int    value     // 0–100 (external)
        required property color  accent

        signal moved(int value)

        implicitHeight: 24

        // Internal dragging state
        property bool   _dragging:   false
        property int    _liveValue:  slider.value
        onValueChanged: if (!_dragging) _liveValue = value

        RowLayout {
            anchors.fill: parent
            spacing: Theme.sp2

            // Icon
            Text {
                text:           slider.icon
                font.family:    "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color:          slider.accent
                Layout.preferredWidth: 18
            }

            // Label
            Text {
                text:           slider.label
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.labelSmall
                font.letterSpacing: 1.5
                color:          Theme.outline
                Layout.preferredWidth: 28
            }

            // Track
            Item {
                id: track
                Layout.fillWidth: true
                height: 4

                // Background
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusFull
                    color:  Theme.outlineVariant
                    opacity: 0.25
                }

                // Filled portion
                Rectangle {
                    id: fill
                    width:  track.width * (slider._liveValue / 100)
                    height: parent.height
                    radius: Theme.radiusFull
                    color:  slider.accent

                    Behavior on width {
                        enabled: !slider._dragging
                        NumberAnimation {
                            duration:    Theme.durationSnap
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
                        }
                    }
                }

                // Mechanical thumb — a 1px vertical line
                Rectangle {
                    id: thumb
                    x:      track.width * (slider._liveValue / 100) - 1
                    y:      -3
                    width:  2
                    height: track.height + 6
                    radius: 1
                    color:  slider.accent

                    Behavior on x {
                        enabled: !slider._dragging
                        NumberAnimation {
                            duration:    Theme.durationSnap
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
                        }
                    }
                }

                // Drag handler
                MouseArea {
                    anchors.fill: parent
                    preventStealing: true

                    function _clamp(v) { return Math.max(0, Math.min(100, v)) }
                    function _valueAt(mx) { return _clamp(Math.round(mx / track.width * 100)) }

                    onPressed:  function(m) { slider._dragging = true;  slider._liveValue = _valueAt(m.x) }
                    onReleased: function(m) {
                        slider._dragging = false
                        slider.moved(slider._liveValue)
                    }
                    onPositionChanged: function(m) {
                        if (slider._dragging) slider._liveValue = _valueAt(m.x)
                    }
                }
            }

            // Value text
            Text {
                text:           slider._liveValue + "%"
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.labelSmall
                font.weight:    Font.Medium
                color:          slider.accent
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ControlToggle — pill-shaped on/off toggle
    // ─────────────────────────────────────────────────────────────────────────
    component ControlToggle: Item {
        id: tog

        required property string icon
        required property string label
        required property bool   enabled_    // 'enabled' is reserved in QML

        signal toggled(bool on)

        implicitWidth:  90
        implicitHeight: 28

        property bool _hov: false

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusFull
            color: tog.enabled_
                   ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                   : Qt.rgba(Theme.outlineVariant.r, Theme.outlineVariant.g,
                              Theme.outlineVariant.b, 0.15)
            border.color: tog.enabled_ ? Theme.primary : Theme.outlineVariant
            border.width: 1

            Behavior on color        { ColorAnimation { duration: Theme.durationFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

            scale: tog._hov ? 1.03 : 1.0
            Behavior on scale {
                NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutBack }
            }

            Row {
                anchors.centerIn: parent
                spacing: Theme.sp1

                Text {
                    text:           tog.icon
                    font.family:    "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color:          tog.enabled_ ? Theme.primary : Theme.outline
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }
                Text {
                    text:           tog.label
                    font.family:    Theme.fontFamilyUI
                    font.pixelSize: Theme.labelSmall
                    font.weight:    Font.Medium
                    color:          tog.enabled_ ? Theme.onPrimaryContainer : Theme.outline
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: tog._hov = true
            onExited:  tog._hov = false
            onClicked: tog.toggled(!tog.enabled_)
        }
    }
}
