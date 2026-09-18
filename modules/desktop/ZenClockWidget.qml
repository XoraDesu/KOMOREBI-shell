// ─────────────────────────────────────────────────────────────────────────────
// KOMOREBI — ZenClockWidget.qml
// Minimalist Wabi-Sabi Desktop Clock with Japanese Calendar Date
// Toggled via ContextMenu widget switches.
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Layouts
import KOMOREBI.Theme 1.0

Item {
    id: root

    property string timeStr: "00:00"
    property string dateStr: ""
    property string kanjiDay: ""

    implicitWidth:  240
    implicitHeight: 90

    Timer {
        interval: 1000
        running:  true
        repeat:   true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            var hh = String(now.getHours()).padStart(2, "0")
            var mm = String(now.getMinutes()).padStart(2, "0")
            root.timeStr = hh + ":" + mm

            var months = ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"]
            var days = ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"]
            root.dateStr = (now.getFullYear()) + "年 " + months[now.getMonth()] + " " + now.getDate() + "日"
            root.kanjiDay = days[now.getDay()]
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLarge
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, Theme.surfaceAlpha)
        border.color: Qt.rgba(Theme.outlineVariant.r, Theme.outlineVariant.g, Theme.outlineVariant.b, 0.4)
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.sp3
            spacing: 2

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: root.timeStr
                    font.family: Theme.fontFamily
                    font.pixelSize: 34
                    font.weight: Font.SemiBold
                    color: Theme.onSurface
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.kanjiDay
                    font.family: "Noto Serif CJK JP"
                    font.pixelSize: Theme.labelMedium
                    font.weight: Font.Medium
                    color: Theme.primary
                }
            }

            Text {
                text: root.dateStr
                font.family: Theme.fontFamily
                font.pixelSize: Theme.labelSmall
                font.letterSpacing: 1.0
                color: Theme.outline
            }
        }
    }
}
