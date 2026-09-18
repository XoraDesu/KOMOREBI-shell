// ─────────────────────────────────────────────────────────────────────────────
// KOMOREBI — IslandDashboard.qml
// Main container for the expanded Dynamic Island.
//
// Responsibilities:
//   1. Segmented tab bar (System · Media · Controls)
//   2. Slide + fade tab transitions using cyberpunk beziers
//   3. StackLayout housing the three sub-modules
//   4. Proper opacity/scale fade-in choreography synced with TopBar expansion
//
// This component is instantiated by TopBar.qml inside the clipped content
// layer. It receives no explicit size props — it fills its parent via
//   anchors.fill: parent
//   anchors.margins: Theme.sp4
// which TopBar already sets.
//
// Tab switching animation strategy:
//   New tab slides in from the direction of travel (left→right or right→left)
//   while the old tab slides out. Both use the durationSnap bezier.
//   A staggered opacity Behavior on each panel creates a gentle overlap dissolve
//   that feels mechanical without being abrupt.
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic    // StackLayout
import KOMOREBI.Theme 1.0

Item {
    id: root

    // ── Tab state ─────────────────────────────────────────────────────────────
    property int  currentTab:  0          // 0=System, 1=Media, 2=Controls
    property int  previousTab: 0          // used to determine slide direction

    readonly property var tabDefs: [
        { id: "sys",   label: "SYS",    icon: "" },
        { id: "media", label: "MEDIA",  icon: "󰝚" },
        { id: "ctrl",  label: "CTRL",   icon: "󰒓" }
    ]

    // ── Root layout ───────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.sp3

        // ── Segmented tab bar ─────────────────────────────────────────────────
        // A row of three pill-like tabs with an animated selection indicator.
        Item {
            Layout.fillWidth: true
            implicitHeight:   24

            // Selection indicator — slides under the active tab
            Rectangle {
                id: tabIndicator
                y:      0
                height: parent.height
                radius: Theme.radiusFull
                color:  Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                border.color: Theme.primary
                border.width: 1

                // Width and x are driven by the active tab delegate
                // We use Binding so the animation is always correct even when
                // the island is still expanding.
                Behavior on x {
                    NumberAnimation {
                        duration:    Theme.durationSnap
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
                    }
                }
                Behavior on width {
                    NumberAnimation {
                        duration:    Theme.durationSnap
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
                    }
                }
            }

            // Tab label row
            Row {
                id: tabRow
                anchors.fill: parent
                spacing: 0

                Repeater {
                    id: tabRepeater
                    model: root.tabDefs

                    delegate: Item {
                        required property var  modelData
                        required property int  index

                        // Equally divide available width
                        width:  tabRow.width / root.tabDefs.length
                        height: tabRow.height

                        readonly property bool active: root.currentTab === index

                        // Update the indicator geometry when this tab is active
                        onActiveChanged: {
                            if (active) {
                                tabIndicator.x     = x
                                tabIndicator.width = width
                            }
                        }
                        Component.onCompleted: {
                            if (active) {
                                tabIndicator.x     = x
                                tabIndicator.width = width
                            }
                        }

                        // Tab label + icon
                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.sp1

                            Text {
                                text:           modelData.icon
                                font.family:    "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color:          parent.parent.active ? Theme.primary : Theme.outline
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                            }

                            Text {
                                text:           modelData.label
                                font.family:    Theme.fontFamily
                                font.pixelSize: Theme.labelSmall
                                font.letterSpacing: 1.5
                                font.weight:    Font.Medium
                                color:          parent.parent.active ? Theme.primary : Theme.outline
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (root.currentTab !== index) {
                                    root.previousTab = root.currentTab
                                    root.currentTab  = index
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Hairline divider ──────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height:  1
            color:   Theme.outlineVariant
            opacity: 0.3
        }

        // ── Panel stack ───────────────────────────────────────────────────────
        // Each panel slides in/out based on currentTab vs previousTab.
        // All three panels are always in the tree (no Loader overhead),
        // but inactive panels are invisible and pointer-events-disabled.
        Item {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            clip: true   // constrain slide animation to the island bounds

            // Slide direction: +1 = new tab is to the right, -1 = to the left
            readonly property int slideDir: root.currentTab > root.previousTab ? 1 : -1

            Repeater {
                model: [
                    { component: systemMonitor },
                    { component: mediaPlayer   },
                    { component: controlCenter  }
                ]

                delegate: Item {
                    id: panelWrapper
                    required property var modelData
                    required property int index

                    anchors.top:    parent.top
                    anchors.bottom: parent.bottom
                    width:          parent.width

                    readonly property bool active: root.currentTab === index

                    // Slide x offset
                    x: active ? 0
                              : (index > root.currentTab ? parent.width : -parent.width)

                    opacity: active ? 1.0 : 0.0
                    enabled: active

                    Behavior on x {
                        NumberAnimation {
                            duration:    Theme.durationSnap
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: active
                                ? [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]   // entering: snap in
                                : [0.55, 0.0, 1.0, 0.45, 1.0, 1.0]   // leaving:  slam out
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration:    Theme.durationFast
                            easing.type: Easing.Linear
                        }
                    }

                    // Load the correct module
                    Loader {
                        anchors.fill: parent
                        sourceComponent: {
                            if (index === 0) return sysComp
                            if (index === 1) return mediaComp
                            return ctrlComp
                        }
                    }
                }
            }
        }
    }

    // ── Module component declarations ─────────────────────────────────────────
    // Declared as Component so the Loader can reference them by ID.
    // All three are always compiled; only one is "active" at a time.

    Component {
        id: sysComp
        SystemMonitor {}
    }

    Component {
        id: mediaComp
        MediaPlayer {}
    }

    Component {
        id: ctrlComp
        ControlCenter {}
    }
}
