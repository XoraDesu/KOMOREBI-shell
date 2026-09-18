// ─────────────────────────────────────────────────────────────────────────────
// KOMOREBI — FocusTimerWidget.qml
// Desktop-level Wabi-Sabi Pomodoro / Focus Timer HUD
// Toggled via the ContextMenu widget switches.
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Layouts
import KOMOREBI.Theme 1.0

Item {
    id: root

    property int  workDuration:   25 * 60   // 25 minutes in seconds
    property int  breakDuration:   5 * 60   // 5 minutes in seconds
    property int  remainingTime:  workDuration
    property bool isRunning:      false
    property bool isBreak:        false

    implicitWidth:  210
    implicitHeight: 116

    Timer {
        id: countdownTimer
        interval: 1000
        repeat:   true
        running:  root.isRunning
        onTriggered: {
            if (root.remainingTime > 0) {
                root.remainingTime -= 1
            } else {
                root.isBreak = !root.isBreak
                root.remainingTime = root.isBreak ? root.breakDuration : root.workDuration
            }
        }
    }

    function _formatTime(sec) {
        var m = Math.floor(sec / 60)
        var s = sec % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    // ── Glassmorphic Card Container ───────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLarge
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, Theme.surfaceAlpha)
        border.color: Qt.rgba(Theme.outlineVariant.r, Theme.outlineVariant.g, Theme.outlineVariant.b, 0.4)
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.sp3
            spacing: Theme.sp1

            // Header: Category and State
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: root.isBreak ? "休息  BREAK" : "集中  FOCUS"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.labelSmall
                    font.letterSpacing: 2.0
                    font.weight: Font.Medium
                    color: root.isBreak ? Theme.secondary : Theme.primary
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: root.isRunning ? Theme.primary : Theme.outline
                    opacity: root.isRunning ? 1.0 : 0.4
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }
            }

            // Big Clock Display
            Text {
                text: root._formatTime(root.remainingTime)
                font.family: Theme.fontFamily
                font.pixelSize: 32
                font.weight: Font.SemiBold
                color: Theme.onSurface
                Layout.alignment: Qt.AlignHCenter
            }

            // Control Actions
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: -2
                spacing: Theme.sp2

                // Start / Pause Pill
                Rectangle {
                    Layout.fillWidth: true
                    height: 26
                    radius: Theme.radiusSmall
                    color: root.isRunning
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                        : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
                    border.color: root.isRunning ? Theme.primary : Theme.outlineVariant
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: root.isRunning ? "󰏤" : "󰐊"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: root.isRunning ? Theme.primary : Theme.onSurface
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.isRunning ? "PAUSE" : "START"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.labelSmall - 1
                            font.weight: Font.Medium
                            font.letterSpacing: 1.0
                            color: root.isRunning ? Theme.primary : Theme.onSurface
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.isRunning = !root.isRunning
                    }
                }

                // Reset Button
                Rectangle {
                    width: 26
                    height: 26
                    radius: Theme.radiusSmall
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.4)
                    border.color: Theme.outlineVariant
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰑐"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.outline
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.isRunning = false
                            root.remainingTime = root.isBreak ? root.breakDuration : root.workDuration
                        }
                    }
                }
            }
        }
    }
}
