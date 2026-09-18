// ─────────────────────────────────────────────────────────────────────────────
// KOMOREBI — WallpaperCarousel.qml
// Horizontally scrollable wallpaper thumbnail picker (PixelOS / Wabi-Sabi style)
//   • Horizontally scrollable ListView with animated active selection
//   • Fallback procedural ink-wash art for missing files
//   • Dynamic filesystem wallpaper scanner via Process
//   • Emits wallpaperSelected(path) and invokes MaterialYouService.setWallpaper()
//   • Live Material You palette preview strip
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import KOMOREBI.Theme 1.0
import KOMOREBI.Services 1.0

Item {
    id: root

    property string selectedPath: MaterialYouService.currentWallpaper
    signal wallpaperSelected(string path)

    implicitWidth:  340
    implicitHeight: 146

    // ── Local Wallpaper Model ─────────────────────────────────────────────────
    // Seeded with curated aesthetic defaults; appended with scanned files
    ListModel {
        id: wallModel

        ListElement {
            name: "Arashi"
            kanji: "嵐"
            subtitle: "Storm Ink"
            path: "/usr/share/backgrounds/komorebi/arashi.jpg"
            fallbackBg: "#161D22"
            fallbackAccent: "#8FAAB8"
        }
        ListElement {
            name: "Hikari"
            kanji: "光"
            subtitle: "Morning Ray"
            path: "/usr/share/backgrounds/komorebi/hikari.jpg"
            fallbackBg: "#221E18"
            fallbackAccent: "#D4B483"
        }
        ListElement {
            name: "Yoru"
            kanji: "夜"
            subtitle: "Tokyo Night"
            path: "/usr/share/backgrounds/komorebi/yoru.jpg"
            fallbackBg: "#12141F"
            fallbackAccent: "#7E8AA2"
        }
        ListElement {
            name: "Ame"
            kanji: "雨"
            subtitle: "Neon Rain"
            path: "/usr/share/backgrounds/komorebi/ame.jpg"
            fallbackBg: "#151F1C"
            fallbackAccent: "#7DA694"
        }
        ListElement {
            name: "Take"
            kanji: "竹"
            subtitle: "Zen Bamboo"
            path: "/usr/share/backgrounds/komorebi/take.jpg"
            fallbackBg: "#1B221B"
            fallbackAccent: "#9EAF8D"
        }
    }

    // ── Dynamic Filesystem Scanner ────────────────────────────────────────────
    // Scans standard user wallpaper folders and adds valid images to the carousel
    Process {
        id: scannerProc
        command: [
            "bash", "-c",
            "find ~/Pictures/Wallpapers ~/.config/komorebi/wallpapers /usr/share/backgrounds " +
            "-maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | head -15"
        ]
        stdout: SplitParser {
            onRead: function(line) {
                var p = line.trim()
                if (!p) return

                // Check for duplicates
                for (var i = 0; i < wallModel.count; ++i) {
                    if (wallModel.get(i).path === p) return
                }

                // Extract filename without extension for title
                var fileName = p.substring(p.lastIndexOf('/') + 1)
                var cleanName = fileName.replace(/\.[^/.]+$/, "")

                wallModel.insert(0, {
                    name: cleanName.charAt(0).toUpperCase() + cleanName.slice(1),
                    kanji: "景",
                    subtitle: "Custom Wall",
                    path: p,
                    fallbackBg: "#14171A",
                    fallbackAccent: "#A0B0B8"
                })
            }
        }
    }

    Component.onCompleted: {
        scannerProc.running = true
    }

    // ── Layout ────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.sp2

        // Section header
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "WALLPAPERS & PALETTE"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.labelSmall
                font.letterSpacing: 2.0
                font.weight: Font.SemiBold
                color: Theme.outline
            }

            Item { Layout.fillWidth: true }

            Text {
                text: wallModel.count + " CURATED"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.labelSmall - 1
                color: Theme.outline
                opacity: 0.7
            }
        }

        // ── Horizontally scrollable thumbnail carousel ────────────────────────
        ListView {
            id: carouselList
            Layout.fillWidth: true
            Layout.preferredHeight: 82
            orientation: ListView.Horizontal
            spacing: Theme.sp2
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            model: wallModel

            delegate: Item {
                id: card
                width: 108
                height: 80

                readonly property bool isSelected: (root.selectedPath === model.path) ||
                                                   (root.selectedPath.indexOf(model.name.toLowerCase()) !== -1)
                property bool isHovered: false

                // Card container
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusMedium
                    clip: true
                    color: model.fallbackBg

                    // Cyberpunk snappy border animation
                    border.color: card.isSelected ? Theme.primary : (card.isHovered ? Theme.outline : Theme.outlineVariant)
                    border.width: card.isSelected ? 2 : 1

                    Behavior on border.color {
                        ColorAnimation { duration: Theme.durationFast }
                    }

                    // Card scale feedback
                    scale: card.isSelected ? 1.03 : (card.isHovered ? 1.01 : 1.0)
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.durationFast
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
                        }
                    }

                    // Image thumbnail
                    Image {
                        id: thumbImg
                        anchors.fill: parent
                        source: model.path
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        opacity: status === Image.Ready ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation { duration: 200 }
                        }
                    }

                    // Procedural Fallback Graphics (when image file is not on disk)
                    Item {
                        anchors.fill: parent
                        visible: thumbImg.status !== Image.Ready

                        // Wabi-Sabi calligraphy watermark
                        Text {
                            anchors.centerIn: parent
                            text: model.kanji
                            font.family: "Noto Serif CJK JP"
                            font.pixelSize: 38
                            color: model.fallbackAccent
                            opacity: 0.15
                        }
                    }

                    // Bottom gradient scrim with title
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 28
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.78) }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.sp2
                            anchors.rightMargin: Theme.sp2
                            anchors.bottomMargin: 2
                            spacing: 4

                            Text {
                                text: model.name
                                font.family: Theme.fontFamilyUI
                                font.pixelSize: Theme.labelSmall
                                font.weight: Font.Medium
                                color: card.isSelected ? Theme.primary : "#FFFFFF"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // Active Selection Badge (PixelOS pill checkmark)
                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 4
                        width: 18
                        height: 18
                        radius: 9
                        color: Theme.primary
                        visible: card.isSelected

                        Text {
                            anchors.centerIn: parent
                            text: "󰄲"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: Theme.onPrimary
                        }
                    }

                    // Mouse Interaction
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: card.isHovered = true
                        onExited:  card.isHovered = false

                        onClicked: {
                            root.selectedPath = model.path
                            root.wallpaperSelected(model.path)

                            // Pipeline execution: swww + matugen color extraction
                            MaterialYouService.setWallpaper(model.path)
                        }
                    }
                }
            }
        }

        // ── Live Material You Palette Feedback Bar ────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 28
            radius: Theme.radiusSmall
            color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.35)
            border.color: Theme.outlineVariant
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.sp2
                anchors.rightMargin: Theme.sp2
                spacing: Theme.sp2

                Text {
                    text: "PALETTE"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.labelSmall - 1
                    font.letterSpacing: 1.5
                    color: Theme.outline
                }

                // Extracted color swatches
                Row {
                    spacing: 4
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        width: 12; height: 12; radius: 6
                        color: Theme.primary
                        border.color: Theme.outlineVariant; border.width: 1
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                    Rectangle {
                        width: 12; height: 12; radius: 6
                        color: Theme.secondary
                        border.color: Theme.outlineVariant; border.width: 1
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                    Rectangle {
                        width: 12; height: 12; radius: 6
                        color: Theme.surfaceVariant
                        border.color: Theme.outlineVariant; border.width: 1
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                    Rectangle {
                        width: 12; height: 12; radius: 6
                        color: Theme.outline
                        border.color: Theme.outlineVariant; border.width: 1
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "" + Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.labelSmall - 1
                    font.weight: Font.Medium
                    color: Theme.primary
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
            }
        }
    }
}
