// ─────────────────────────────────────────────────────────────────────────────
// KOMOREBI — ClockWidget.qml
// Minimal clock for the collapsed island state.
// Wabi-Sabi aesthetic: minimal information, generous spacing, muted palette.
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick

Item {
    id: root

    implicitWidth:  timeLabel.implicitWidth + Theme.sp4 * 2
    implicitHeight: Theme.islandDefaultHeight

    // ── Live time ─────────────────────────────────────────────────────────────
    property string _time: Qt.formatTime(new Date(), "HH:mm")
    property string _date: Qt.formatDate(new Date(), "ddd d MMM")

    Timer {
        interval: 1000
        repeat:   true
        running:  true
        onTriggered: {
            root._time = Qt.formatTime(new Date(), "HH:mm")
            root._date = Qt.formatDate(new Date(), "ddd d MMM")
        }
    }

    // ── Layout ────────────────────────────────────────────────────────────────
    Row {
        anchors.centerIn: parent
        spacing: Theme.sp3

        // Seconds dot — subtle pulse animation
        Rectangle {
            id: pulseOrb
            width:  6;  height: 6
            radius: 3
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.primary

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.2; duration: 800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
            }
        }

        // Time
        Text {
            id: timeLabel
            text: root._time
            font.family:      Theme.fontFamily
            font.pixelSize:   Theme.titleSmall
            font.weight:      Font.Medium
            font.letterSpacing: 1.5
            color: Theme.onSurface
        }

        // Separator
        Text {
            text: "·"
            font.family:    Theme.fontFamily
            font.pixelSize: Theme.labelMedium
            color: Theme.outline
            anchors.verticalCenter: parent.verticalCenter
        }

        // Date
        Text {
            id: dateLabel
            text: root._date
            font.family:    Theme.fontFamilyUI
            font.pixelSize: Theme.labelMedium
            color: Theme.outline
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
