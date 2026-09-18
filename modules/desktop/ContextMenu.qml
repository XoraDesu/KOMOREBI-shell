// ─────────────────────────────────────────────────────────────────────────────
// KOMOREBI — ContextMenu.qml
// Floating desktop context menu (PixelOS inspired, Wabi-Sabi + Material 3)
// Snaps into view at cursor coordinates with aggressive cyberpunk bezier easing.
// Contains:
//   1. Wallpaper Carousel & Live Palette Preview
//   2. Desktop Widget Toggles (Material 3 Switches)
//   3. Shell Configuration & Quick Actions
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import KOMOREBI.Theme 1.0

Item {
    id: root

    required property var screen

    // Widget states exposed to parent overlay
    property bool focusTimerActive: false
    property bool zenClockActive:   false
    property bool systemGlanceActive: false

    signal widgetToggled(string widgetId, bool active)
    signal wallpaperChanged(string path)

    // Visibility and geometry state
    property bool isOpen: false

    width:  370
    height: menuColumn.implicitHeight + (Theme.sp4 * 2)

    visible: opacity > 0.005

    // Transform origin near top-left of popup
    transformOrigin: Item.TopLeft
    scale: isOpen ? 1.0 : 0.86
    opacity: isOpen ? 1.0 : 0.0

    // ── Cyberpunk Snappy Bezier Animations ────────────────────────────────────
    Behavior on scale {
        NumberAnimation {
            duration: root.isOpen ? Theme.durationSnap : Theme.durationCollapse
            easing.type: Easing.BezierSpline
            // Fast in (0.22, 1.0) mechanical stop — cyberpunk physics
            easing.bezierCurve: root.isOpen
                ? [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
                : [0.55, 0.0, 1.0, 0.45, 1.0, 1.0]
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: root.isOpen ? Theme.durationSnap : Theme.durationFast
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
        }
    }

    // ── Coordinate Positioning & Screen Clamping ──────────────────────────────
    function showAt(clickX, clickY) {
        var pad = Theme.sp3
        var screenW = (root.screen && root.screen.width > 0) ? root.screen.width : 1920
        var screenH = (root.screen && root.screen.height > 0) ? root.screen.height : 1080

        var maxX = screenW - root.width - pad
        var maxY = screenH - root.height - pad

        root.x = Math.max(pad, Math.min(clickX, maxX))
        root.y = Math.max(pad, Math.min(clickY, maxY))
        root.isOpen = true
    }

    function dismiss() {
        root.isOpen = false
    }

    // ── Soft Drop Shadow Glow ─────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: Theme.radiusXLarge
        color: Qt.rgba(0, 0, 0, 0.45)
        z: -1
    }

    // ── M3 Floating Container ─────────────────────────────────────────────────
    Rectangle {
        id: panelBg
        anchors.fill: parent
        radius: Theme.radiusLarge
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.94)
        border.color: Qt.rgba(Theme.outlineVariant.r, Theme.outlineVariant.g, Theme.outlineVariant.b, 0.5)
        border.width: 1

        // Consume clicks inside menu background so they don't dismiss the popup
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) { mouse.accepted = true }
        }

        ColumnLayout {
            id: menuColumn
            anchors.fill: parent
            anchors.margins: Theme.sp4
            spacing: Theme.sp3

            // ── Section 0: Header ─────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "侘寂"
                    font.family: "Noto Serif CJK JP"
                    font.pixelSize: Theme.titleSmall
                    color: Theme.primary
                }

                Text {
                    text: "DESKTOP & AMBIENCE"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.labelSmall
                    font.letterSpacing: 2.2
                    font.weight: Font.SemiBold
                    color: Theme.outline
                }

                Item { Layout.fillWidth: true }

                // Close pill
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.4)
                    border.color: Theme.outlineVariant
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: Theme.outline
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismiss()
                    }
                }
            }

            // ── Section 1: Wallpaper Carousel ─────────────────────────────────
            WallpaperCarousel {
                id: carousel
                Layout.fillWidth: true
                onWallpaperSelected: function(path) {
                    root.wallpaperChanged(path)
                }
            }

            // Separator line
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.outlineVariant
                opacity: 0.35
            }

            // ── Section 2: Widgets Toggle ─────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.sp2

                Text {
                    text: "DESKTOP WIDGETS"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.labelSmall
                    font.letterSpacing: 2.0
                    font.weight: Font.SemiBold
                    color: Theme.outline
                }

                // Row 1: Focus Timer (Pomodoro)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp3

                    Rectangle {
                        width: 30; height: 30; radius: Theme.radiusSmall
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                        border.color: root.focusTimerActive ? Theme.primary : Theme.outlineVariant
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "󱎫"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: root.focusTimerActive ? Theme.primary : Theme.outline
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Focus Timer"
                            font.family: Theme.fontFamilyUI
                            font.pixelSize: Theme.bodySmall
                            font.weight: Font.Medium
                            color: Theme.onSurface
                        }
                        Text {
                            text: "Pomodoro countdown on desktop"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.labelSmall - 1
                            color: Theme.outline
                        }
                    }

                    MaterialSwitch {
                        checked: root.focusTimerActive
                        onToggled: function(val) {
                            root.focusTimerActive = val
                            root.widgetToggled("focusTimer", val)
                        }
                    }
                }

                // Row 2: Zen Clock
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp3

                    Rectangle {
                        width: 30; height: 30; radius: Theme.radiusSmall
                        color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                        border.color: root.zenClockActive ? Theme.secondary : Theme.outlineVariant
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "󰥔"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: root.zenClockActive ? Theme.secondary : Theme.outline
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Desktop Zen Clock"
                            font.family: Theme.fontFamilyUI
                            font.pixelSize: Theme.bodySmall
                            font.weight: Font.Medium
                            color: Theme.onSurface
                        }
                        Text {
                            text: "Japanese kanji calendar & time"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.labelSmall - 1
                            color: Theme.outline
                        }
                    }

                    MaterialSwitch {
                        checked: root.zenClockActive
                        onToggled: function(val) {
                            root.zenClockActive = val
                            root.widgetToggled("zenClock", val)
                        }
                    }
                }
            }

            // Separator line
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.outlineVariant
                opacity: 0.35
            }

            // ── Section 3: Shell Settings & Actions ───────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.sp2

                Text {
                    text: "SYSTEM PREFERENCES"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.labelSmall
                    font.letterSpacing: 2.0
                    font.weight: Font.SemiBold
                    color: Theme.outline
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp2

                    // Button: Open Config
                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        radius: Theme.radiusMedium
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.45)
                        border.color: Theme.outlineVariant
                        border.width: 1

                        property bool hovered: false

                        scale: hovered ? 1.02 : 1.0
                        Behavior on scale {
                            NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutBack }
                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Theme.sp2

                            Text {
                                text: "󰒓"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                color: Theme.primary
                            }

                            Text {
                                text: "CONFIG"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.labelSmall
                                font.weight: Font.Medium
                                font.letterSpacing: 1.2
                                color: Theme.onSurface
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.hovered = true
                            onExited:  parent.hovered = false
                            onClicked: {
                                configProc.running = true
                                root.dismiss()
                            }
                        }
                    }

                    // Button: Reload Shell
                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        radius: Theme.radiusMedium
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.45)
                        border.color: Theme.outlineVariant
                        border.width: 1

                        property bool hovered: false

                        scale: hovered ? 1.02 : 1.0
                        Behavior on scale {
                            NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutBack }
                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Theme.sp2

                            Text {
                                text: "󰑓"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                color: Theme.secondary
                            }

                            Text {
                                text: "RELOAD"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.labelSmall
                                font.weight: Font.Medium
                                font.letterSpacing: 1.2
                                color: Theme.onSurface
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.hovered = true
                            onExited:  parent.hovered = false
                            onClicked: {
                                reloadProc.running = true
                                root.dismiss()
                            }
                        }
                    }
                }
            }
        }
    }

    // ── External Processes ────────────────────────────────────────────────────
    Process {
        id: configProc
        command: ["bash", "-c", "xdg-open ~/.config/komorebi || xdg-open . || kitty -e nvim ~/.config/komorebi/quickshell.conf"]
    }

    Process {
        id: reloadProc
        command: ["bash", "-c", "hyprctl reload || killall -SIGUSR1 quickshell || pkill -HUP quickshell"]
    }
}
