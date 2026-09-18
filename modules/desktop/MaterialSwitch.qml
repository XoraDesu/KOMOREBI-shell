// ─────────────────────────────────────────────────────────────────────────────
// KOMOREBI — MaterialSwitch.qml
// Material 3 Switch Component:
//   • Track: 52 × 32 dp pill container
//   • Thumb: 16 dp (off) → 24 dp (on) with active checkmark glyph
//   • Cyberpunk snappy bezier easing (durationSnap: 180ms)
//   • Dynamic colors bound to Theme.primary and Theme.surfaceVariant
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import KOMOREBI.Theme 1.0

Item {
    id: root

    property bool   checked: false
    property color  accentColor: Theme.primary
    property color  trackColorOff: Qt.rgba(Theme.outlineVariant.r, Theme.outlineVariant.g, Theme.outlineVariant.b, 0.35)
    property bool   interactive: true

    signal toggled(bool isChecked)

    implicitWidth:  52
    implicitHeight: 32

    // ── Track Container ───────────────────────────────────────────────────────
    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        
        // M3 fill: Primary when on, Muted outlineVariant when off
        color: root.checked
            ? root.accentColor
            : root.trackColorOff

        border.color: root.checked
            ? root.accentColor
            : Theme.outline
        border.width: root.checked ? 0 : 1

        Behavior on color {
            ColorAnimation {
                duration: Theme.durationSnap
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: Theme.durationSnap
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
            }
        }

        // ── Thumb ─────────────────────────────────────────────────────────────
        Rectangle {
            id: thumb

            // Dimensions: 16dp unselected -> 24dp selected (M3 specification)
            readonly property real targetSize: root.checked ? 24 : 16
            width:  targetSize
            height: targetSize
            radius: targetSize / 2

            // Vertical centering
            anchors.verticalCenter: parent.verticalCenter

            // Horizontal position: 4px padding from edges
            x: root.checked
                ? (track.width - width - 4)
                : (4 + (24 - 16) / 2) // aligned with resting thumb track

            // Color: onPrimary when selected, outline when unselected
            color: root.checked ? Theme.onPrimary : Theme.outline

            Behavior on x {
                NumberAnimation {
                    duration: Theme.durationSnap
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: Theme.durationSnap
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: Theme.durationSnap
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Theme.durationSnap
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
                }
            }

            // Small checkmark inside thumb when checked (Material 3 detail)
            Text {
                anchors.centerIn: parent
                text: "✓"
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.Bold
                color: Theme.primary
                opacity: root.checked ? 1.0 : 0.0
                scale:   root.checked ? 1.0 : 0.5

                Behavior on opacity {
                    NumberAnimation { duration: Theme.durationFast }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durationFast
                        easing.type: Easing.OutBack
                    }
                }
            }
        }
    }

    // ── Mouse interaction ─────────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        onClicked: {
            root.checked = !root.checked
            root.toggled(root.checked)
        }
    }
}
