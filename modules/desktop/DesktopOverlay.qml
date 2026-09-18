// ─────────────────────────────────────────────────────────────────────────────
// KOMOREBI — DesktopOverlay.qml
// Transparent desktop background layer sitting directly above swww wallpaper.
// Captures right-click events (and two-finger trackpad taps) on empty desktop
// to spawn the floating ContextMenu at exact mouse coordinates.
// ─────────────────────────────────────────────────────────────────────────────
import Quickshell
import Quickshell.Wayland
import QtQuick
import KOMOREBI.Theme 1.0

PanelWindow {
    id: root

    required property var screen

    // ── Layer Configuration ───────────────────────────────────────────────────
    // WlrLayer.Bottom sits directly above swww wallpaper (WlrLayer.Background)
    // and underneath normal toplevel application windows.
    WlrLayershell.layer: WlrLayer.Bottom

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    // ── Desktop Widget Visibility States ──────────────────────────────────────
    property bool showFocusTimer: false
    property bool showZenClock:   false

    // ── Transparent Desktop Hit-Box ───────────────────────────────────────────
    // Listens for right-clicks across the whole empty desktop space.
    // Also handles outside-click dismissal of the context menu.
    MouseArea {
        id: desktopHitbox
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: false

        onPressed: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                // Captures exact cursor position (mouseX, mouseY) and snaps menu into view
                contextMenu.showAt(mouse.x, mouse.y)
            } else if (mouse.button === Qt.LeftButton) {
                // Clicking empty space outside the context menu dismisses it
                if (contextMenu.isOpen) {
                    contextMenu.dismiss()
                }
            }
        }
    }

    // ── Desktop-Level Widgets Layer ───────────────────────────────────────────
    // Placed on the desktop, toggled via ContextMenu M3 switches.

    // 1. Focus Timer HUD (Bottom-right breathing space)
    FocusTimerWidget {
        id: focusWidget
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.sp8

        visible: opacity > 0.001
        opacity: root.showFocusTimer ? 1.0 : 0.0
        scale:   root.showFocusTimer ? 1.0 : 0.9

        Behavior on opacity {
            NumberAnimation { duration: Theme.durationSnap }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.durationSnap
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
            }
        }
    }

    // 2. Zen Clock Widget (Center-left calm placement)
    ZenClockWidget {
        id: zenClockWidget
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Theme.sp8

        visible: opacity > 0.001
        opacity: root.showZenClock ? 1.0 : 0.0
        scale:   root.showZenClock ? 1.0 : 0.9

        Behavior on opacity {
            NumberAnimation { duration: Theme.durationSnap }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.durationSnap
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
            }
        }
    }

    // ── Floating PixelOS-style Context Menu ───────────────────────────────────
    // Positioned dynamically by showAt(mouseX, mouseY) with screen edge clamping
    ContextMenu {
        id: contextMenu
        screen: root.screen
        z: 100

        focusTimerActive: root.showFocusTimer
        zenClockActive:   root.showZenClock

        onWidgetToggled: function(widgetId, active) {
            if (widgetId === "focusTimer") {
                root.showFocusTimer = active
            } else if (widgetId === "zenClock") {
                root.showZenClock = active
            }
        }
    }
}
