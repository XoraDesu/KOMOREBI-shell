// ─────────────────────────────────────────────────────────────────────────────
// KOMOREBI — WorkspaceWidget.qml
// Hyprland workspace dots for the expanded dashboard.
// Active workspace highlighted in primary colour; inactive as outline dots.
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import KOMOREBI.Theme 1.0

Row {
    id: root
    spacing: Theme.sp2

    // Maximum workspaces to display (expands dynamically)
    readonly property int maxWorkspaces: 9

    Repeater {
        model: root.maxWorkspaces

        delegate: Rectangle {
            required property int index
            readonly property int  wsNum: index + 1
            readonly property bool isActive: Hyprland.focusedWorkspace?.id === wsNum
            readonly property bool hasWindows: {
                // Find this delegate's workspace among Hyprland's known workspaces,
                // then check whether it has any toplevels (windows) open.
                var list = Hyprland.workspaces.values
                for (var i = 0; i < list.length; i++) {
                    if (list[i].id === wsNum) {
                        return list[i].toplevels.values.length > 0
                    }
                }
                return false
            }

            width:  isActive ? 18 : (hasWindows ? 8 : 6)
            height: 6
            radius: Theme.radiusFull
            color:  isActive ? Theme.primary : (hasWindows ? Theme.outline : Theme.outlineVariant)
            opacity: hasWindows || isActive ? 1.0 : 0.3

            Behavior on width {
                NumberAnimation { duration: Theme.durationSnap; easing.type: Easing.OutBack }
            }
            Behavior on color {
                ColorAnimation { duration: 200 }
            }

            // Click to switch workspace
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("workspace " + wsNum)
            }
        }
    }
}
