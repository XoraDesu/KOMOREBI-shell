// ─────────────────────────────────────────────────────────────────────────────
// KOMOREBI — AppLauncher.qml
// Full-screen application drawer inspired by Stock Android and ChromeOS.
//
// Key Architectural Features:
//   • Fullscreen translucent overlay with heavy Wabi-Sabi ink blur
//   • Prominent Material 3 rounded search pill at top center (auto-focused)
//   • Central GridView displaying all installed applications sorted A -> Z
//   • Alphabet Fast Scroller along the right edge with a floating Letter Indicator
//   • Instantaneous O(1) index lookup and jump via positionViewAtIndex()
//   • Aggressive cyberpunk bezier curves (durationSnap: 180ms)
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import KOMOREBI.Theme 1.0

Item {
    id: root

    required property var screen

    // ── Visibility & Motion State ─────────────────────────────────────────────
    property bool isOpen: false

    anchors.fill: parent
    visible: opacity > 0.001

    // Scale and fade animation with aggressive cyberpunk bezier curve
    scale:   isOpen ? 1.0 : 0.94
    opacity: isOpen ? 1.0 : 0.0

    Behavior on scale {
        NumberAnimation {
            duration: root.isOpen ? Theme.durationSnap : Theme.durationCollapse
            easing.type: Easing.BezierSpline
            // Fast entrance (0.22, 1.0) mechanical stop
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

    onIsOpenChanged: {
        if (isOpen) {
            searchField.text = ""
            searchField.forceActiveFocus()
            loadApplications()
        }
    }

    function open() {
        root.isOpen = true
    }

    function close() {
        root.isOpen = false
        searchField.text = ""
    }

    function toggle() {
        if (root.isOpen) root.close()
        else root.open()
    }

    // ── Keyboard Shortcuts (Escape to dismiss) ────────────────────────────────
    Keys.onEscapePressed: root.close()

    // ── Fast Scroller Data Structure & Alphabet Mapping ───────────────────────
    readonly property var alphabet: [
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
        "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "#"
    ]

    property var letterIndexMap: ({})  // Maps letter ('A'-'Z', '#') -> Grid index
    property string activeLetter: ""   // Currently highlighted letter
    property bool isScrollerDragging: false
    property real indicatorY: 0        // Dynamic Y coordinate of floating letter indicator

    // Master dataset
    property var allApps: []

    // ── Model for the GridView ────────────────────────────────────────────────
    ListModel {
        id: displayModel
    }

    // ── Application Loader & Alphabetical Sorting Algorithm ───────────────────
    // 1. Queries DesktopEntries.applications.values from Quickshell
    // 2. Sorts entries alphabetically (A -> Z) using localeCompare
    // 3. Pre-computes letterIndexMap for instantaneous O(1) jump lookups
    function loadApplications() {
        var rawEntries = []

        if (typeof DesktopEntries !== "undefined" &&
            DesktopEntries.applications &&
            DesktopEntries.applications.values) {
            rawEntries = DesktopEntries.applications.values
        }

        var appList = []

        if (rawEntries && rawEntries.length > 0) {
            for (var i = 0; i < rawEntries.length; i++) {
                var entry = rawEntries[i]
                if (!entry.name) continue

                var cat = (entry.categories && entry.categories.length > 0)
                    ? entry.categories[0]
                    : "Application"

                appList.push({
                    name: entry.name,
                    icon: entry.icon || "",
                    comment: entry.comment || "",
                    category: cat,
                    entry: entry
                })
            }
        } else {
            // Curated fallback data ensuring full interactive demonstration
            appList = _getCuratedFallbackApps()
        }

        // Alphabetical sort (A -> Z)
        appList.sort(function(a, b) {
            return a.name.localeCompare(b.name, undefined, { sensitivity: "base" })
        })

        root.allApps = appList
        _rebuildIndexMap(appList)
        _applyFilter(searchField.text)
    }

    // Pre-computes the first index of each letter in the sorted dataset
    function _rebuildIndexMap(items) {
        var map = {}
        for (var i = 0; i < items.length; i++) {
            var firstChar = items[i].name.charAt(0).toUpperCase()
            if (firstChar < 'A' || firstChar > 'Z') {
                firstChar = '#'
            }
            if (map[firstChar] === undefined) {
                map[firstChar] = i
            }
        }
        root.letterIndexMap = map
    }

    // Applies search query filter to the display model
    function _applyFilter(query) {
        displayModel.clear()
        var q = query.trim().toLowerCase()

        var filtered = []
        for (var i = 0; i < root.allApps.length; i++) {
            var app = root.allApps[i]
            if (q.length === 0 ||
                app.name.toLowerCase().indexOf(q) !== -1 ||
                app.comment.toLowerCase().indexOf(q) !== -1 ||
                app.category.toLowerCase().indexOf(q) !== -1) {
                displayModel.append({
                    name: app.name,
                    icon: app.icon,
                    comment: app.comment,
                    category: app.category,
                    appIndex: i
                })
                filtered.push(app)
            }
        }

        // If query active, rebuild map for filtered set; else use root.allApps
        if (q.length > 0) {
            _rebuildIndexMap(filtered)
        } else {
            _rebuildIndexMap(root.allApps)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ALPHABET FAST SCROLLER: Y-COORDINATE TO A-Z INDEX MAPPING ALGORITHM
    //
    // Given:
    //   - scrollerTrack.height: Total vertical pixel height of the rail
    //   - mouseY: Raw touch/drag coordinate relative to the track
    //
    // Algorithm:
    //   1. Clamp mouseY into [0, scrollerTrack.height - 1]
    //   2. Compute normalized continuous ratio: t = clampedY / scrollerTrack.height
    //   3. Compute discrete bucket index: letterIndex = floor(t * alphabet.length)
    //   4. Lookup target letter: alphabet[letterIndex]
    //   5. Instant jump: positionViewAtIndex(letterIndexMap[targetLetter], Beginning)
    // ─────────────────────────────────────────────────────────────────────────
    function handleScrollerDrag(mouseY) {
        var clampedY = Math.max(0, Math.min(mouseY, scrollerTrack.height - 1))
        var ratio = clampedY / scrollerTrack.height
        var letterIdx = Math.min(root.alphabet.length - 1, Math.floor(ratio * root.alphabet.length))
        var targetLetter = root.alphabet[letterIdx]

        root.activeLetter = targetLetter
        root.indicatorY = scrollerTrack.y + clampedY

        root.jumpToLetter(targetLetter)
    }

    // Instantaneous O(1) jump to first application matching the letter
    function jumpToLetter(letter) {
        // Direct dictionary lookup
        if (root.letterIndexMap[letter] !== undefined) {
            var targetIdx = root.letterIndexMap[letter]
            if (targetIdx >= 0 && targetIdx < displayModel.count) {
                appGrid.positionViewAtIndex(targetIdx, GridView.Beginning)
            }
            return
        }

        // If no apps start with exact letter, scan forward to next available letter
        var startIdx = root.alphabet.indexOf(letter)
        for (var i = startIdx + 1; i < root.alphabet.length; i++) {
            var nextL = root.alphabet[i]
            if (root.letterIndexMap[nextL] !== undefined) {
                var nextIdx = root.letterIndexMap[nextL]
                if (nextIdx >= 0 && nextIdx < displayModel.count) {
                    appGrid.positionViewAtIndex(nextIdx, GridView.Beginning)
                }
                return
            }
        }

        // Backward scan fallback
        for (var j = startIdx - 1; j >= 0; j--) {
            var prevL = root.alphabet[j]
            if (root.letterIndexMap[prevL] !== undefined) {
                var prevIdx = root.letterIndexMap[prevL]
                if (prevIdx >= 0 && prevIdx < displayModel.count) {
                    appGrid.positionViewAtIndex(prevIdx, GridView.Beginning)
                }
                return
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // BACKGROUND OVERLAY (Wabi-Sabi Ink + Material 3 Dynamic Palette)
    // ─────────────────────────────────────────────────────────────────────────
    Rectangle {
        id: backgroundOverlay
        anchors.fill: parent
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.92)

        // Radial focal glow centered behind the app grid
        RadialGradientWrapper {
            anchors.fill: parent
            glowColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
        }

        // Click outside search and grid closes the launcher
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MAIN CONTENT CONTAINER
    // ─────────────────────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent

        // Header Category Kanji Watermark (Wabi-Sabi Breathing Room)
        Text {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: Theme.sp8
            text: "抽斗" // Drawer / Archive
            font.family: "Noto Serif CJK JP"
            font.pixelSize: 42
            font.weight: Font.Light
            color: Theme.outline
            opacity: 0.2
        }

        // ── SEARCH BAR (Stock Android / ChromeOS Material 3 Rounded Pill) ─────
        Rectangle {
            id: searchBar
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: Theme.sp8

            width:  Math.min(parent.width * 0.55, 620)
            height: 52
            radius: height / 2

            color: searchField.activeFocus
                ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.85)
                : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.55)

            border.color: searchField.activeFocus ? Theme.primary : Theme.outlineVariant
            border.width: searchField.activeFocus ? 2 : 1

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

            // Drop shadow glow
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: parent.radius + 3
                color: Qt.rgba(0, 0, 0, 0.25)
                z: -1
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin:  Theme.sp4
                anchors.rightMargin: Theme.sp4
                spacing: Theme.sp3

                // Search Magnifier Glyph
                Text {
                    text: "󰍉"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    color: searchField.activeFocus ? Theme.primary : Theme.outline
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                // Text Input
                TextInput {
                    id: searchField
                    Layout.fillWidth: true
                    font.family:    Theme.fontFamilyUI
                    font.pixelSize: Theme.bodyMedium
                    color:          Theme.onSurface
                    clip:           true
                    selectByMouse:  true

                    // Placeholder
                    Text {
                        anchors.fill: parent
                        text: "Search applications, commands, categories..."
                        font.family:    Theme.fontFamilyUI
                        font.pixelSize: Theme.bodyMedium
                        color:          Theme.outline
                        visible:        !searchField.text && !searchField.activeFocus
                        opacity:        0.7
                    }

                    onTextChanged: {
                        root._applyFilter(text)
                    }

                    onAccepted: {
                        // Launch first result on Enter
                        if (displayModel.count > 0) {
                            var firstApp = root.allApps[displayModel.get(0).appIndex]
                            root._launchApp(firstApp)
                        }
                    }
                }

                // Clear Query Button
                Rectangle {
                    width:  24
                    height: 24
                    radius: 12
                    color:  Qt.rgba(Theme.outlineVariant.r, Theme.outlineVariant.g, Theme.outlineVariant.b, 0.4)
                    visible: searchField.text.length > 0

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: Theme.onSurface
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchField.text = ""
                            searchField.forceActiveFocus()
                        }
                    }
                }
            }
        }

        // ── CENTRAL APP GRID (Alphabetically Sorted A -> Z) ───────────────────
        GridView {
            id: appGrid
            anchors.top: searchBar.bottom
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin:    Theme.sp6
            anchors.bottomMargin: Theme.sp6

            width: Math.min(parent.width - 160, 980)
            cellWidth:  140
            cellHeight: 124
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            model: displayModel

            delegate: Item {
                id: tile
                width:  appGrid.cellWidth
                height: appGrid.cellHeight

                property bool isHovered: false

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: Theme.radiusLarge
                    color: tile.isHovered
                        ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
                        : "transparent"
                    border.color: tile.isHovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) : "transparent"
                    border.width: 1

                    // Cyberpunk micro bounce on hover
                    scale: tile.isHovered ? 1.05 : 1.0
                    Behavior on scale {
                        NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutBack }
                    }
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Theme.sp2

                        // Icon Container with Clean Wabi-Sabi Masking
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width:  52
                            height: 52
                            radius: Theme.radiusMedium
                            color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.4)
                            border.color: tile.isHovered ? Theme.primary : Theme.outlineVariant
                            border.width: 1

                            // Icon Image resolver
                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 32
                                source: Quickshell.iconPath(model.icon)
                                visible: status === Image.Ready
                            }

                            // Fallback glyph when system icon cannot be found
                            Text {
                                anchors.centerIn: parent
                                text: root._getCategoryIcon(model.category)
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 22
                                color: tile.isHovered ? Theme.primary : Theme.onSurface
                            }
                        }

                        // Application Name
                        Text {
                            Layout.fillWidth: true
                            Layout.maximumWidth: appGrid.cellWidth - 16
                            text: model.name
                            font.family: Theme.fontFamilyUI
                            font.pixelSize: Theme.labelMedium
                            font.weight: Font.Medium
                            color: tile.isHovered ? Theme.primary : Theme.onSurface
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        // Category Subtitle
                        Text {
                            Layout.fillWidth: true
                            Layout.maximumWidth: appGrid.cellWidth - 20
                            text: model.category
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.labelSmall - 2
                            font.letterSpacing: 0.8
                            color: Theme.outline
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            opacity: 0.8
                        }
                    }

                    // Click to launch
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: tile.isHovered = true
                        onExited:  tile.isHovered = false

                        onClicked: {
                            var appObj = root.allApps[model.appIndex]
                            root._launchApp(appObj)
                        }
                    }
                }
            }
        }

        // ── ALPHABET FAST SCROLLER (Dedicated Right Edge Track) ───────────────
        Item {
            id: scrollerContainer
            anchors.right: parent.right
            anchors.rightMargin: Theme.sp3
            anchors.top: searchBar.bottom
            anchors.bottom: parent.bottom
            anchors.topMargin:    Theme.sp4
            anchors.bottomMargin: Theme.sp6
            width: 38

            // Vertical Track Background
            Rectangle {
                id: scrollerTrack
                anchors.centerIn: parent
                width:  28
                height: Math.min(parent.height - 40, root.alphabet.length * 20)
                radius: width / 2
                color:  root.isScrollerDragging
                    ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.7)
                    : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
                border.color: Theme.outlineVariant
                border.width: 1

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                Column {
                    anchors.centerIn: parent
                    spacing: 1

                    Repeater {
                        model: root.alphabet
                        delegate: Text {
                            text: modelData
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: root.activeLetter === modelData ? Font.Bold : Font.Normal
                            color: root.activeLetter === modelData ? Theme.primary : Theme.outline
                            anchors.horizontalCenter: parent.horizontalCenter

                            Behavior on color { ColorAnimation { duration: 60 } }
                        }
                    }
                }
            }

            // Drag / Touch Area mapping Y to A-Z Index
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onPressed: function(mouse) {
                    root.isScrollerDragging = true
                    root.handleScrollerDrag(mouse.y - scrollerTrack.y)
                }
                onPositionChanged: function(mouse) {
                    if (pressed) {
                        root.handleScrollerDrag(mouse.y - scrollerTrack.y)
                    }
                }
                onReleased: {
                    root.isScrollerDragging = false
                }
            }
        }

        // ── LARGE LETTER INDICATOR (Pops Up Beside Scroller on Drag) ──────────
        Rectangle {
            id: letterIndicator
            x: scrollerContainer.x - width - Theme.sp3
            y: Math.max(scrollerContainer.y, Math.min(root.indicatorY - (height / 2), scrollerContainer.y + scrollerContainer.height - height))
            width:  68
            height: 68
            radius: Theme.radiusLarge
            color:  Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.95)
            border.color: Theme.primary
            border.width: 2

            visible: root.isScrollerDragging && root.activeLetter.length > 0
            scale:   visible ? 1.0 : 0.6
            opacity: visible ? 1.0 : 0.0

            Behavior on scale {
                NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutBack }
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.durationFast }
            }

            // Pointer chevron facing the scroller rail
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: -5
                anchors.verticalCenter: parent.verticalCenter
                width:  10
                height: 10
                rotation: 45
                color: Theme.surface
                border.color: Theme.primary
                border.width: 2
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.activeLetter
                    font.family: Theme.fontFamily
                    font.pixelSize: 32
                    font.weight: Font.Bold
                    color: Theme.primary
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "SECTION"
                    font.family: Theme.fontFamily
                    font.pixelSize: 7
                    font.letterSpacing: 1.5
                    color: Theme.outline
                }
            }
        }
    }

    // ── Application Launch Execution ──────────────────────────────────────────
    function _launchApp(appObj) {
        if (!appObj) return

        if (appObj.entry && typeof appObj.entry.execute === "function") {
            appObj.entry.execute()
        } else {
            launchProc.command = ["bash", "-c", "gtk-launch " + appObj.name.toLowerCase() + " || " + appObj.name.toLowerCase() + " &"]
            launchProc.running = true
        }
        root.close()
    }

    Process {
        id: launchProc
        command: ["true"]
    }

    // Category icon resolver
    function _getCategoryIcon(cat) {
        var c = (cat || "").toLowerCase()
        if (c.indexOf("develop") !== -1 || c.indexOf("code") !== -1) return "󰨞"
        if (c.indexOf("web") !== -1 || c.indexOf("network") !== -1)  return "󰈹"
        if (c.indexOf("terminal") !== -1 || c.indexOf("system") !== -1) return "󰞷"
        if (c.indexOf("audio") !== -1 || c.indexOf("music") !== -1)   return "󰝚"
        if (c.indexOf("video") !== -1 || c.indexOf("media") !== -1)   return "󰕼"
        if (c.indexOf("graph") !== -1 || c.indexOf("art") !== -1)     return "󰽉"
        if (c.indexOf("game") !== -1)                                return "󰊴"
        if (c.indexOf("util") !== -1 || c.indexOf("setting") !== -1) return "󰒓"
        return "󰵆"
    }

    // ── Radial Gradient Component ─────────────────────────────────────────────
    component RadialGradientWrapper: Canvas {
        required property color glowColor
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var grad = ctx.createRadialGradient(width / 2, height * 0.4, 40, width / 2, height * 0.4, width * 0.6)
            grad.addColorStop(0.0, glowColor)
            grad.addColorStop(1.0, "transparent")
            ctx.fillStyle = grad
            ctx.fillRect(0, 0, width, height)
        }
    }

    // ── Curated Fallback Apps Dataset ──────────────────────────────────────────
    function _getCuratedFallbackApps() {
        return [
            { name: "Alacritty",       icon: "Alacritty",        comment: "GPU Accelerated Terminal", category: "System" },
            { name: "Amberol",         icon: "amberol",          comment: "Music Player",              category: "Audio" },
            { name: "Blender",         icon: "blender",          comment: "3D Creation Suite",         category: "Graphics" },
            { name: "Brave Browser",   icon: "brave-browser",    comment: "Secure Web Browser",        category: "Network" },
            { name: "Code OSS",        icon: "code",             comment: "Code Editor",               category: "Development" },
            { name: "Discord",         icon: "discord",          comment: "All-in-one Voice & Text",   category: "Network" },
            { name: "Dolphin",         icon: "system-file-manager", comment: "File Manager",           category: "System" },
            { name: "Firefox",         icon: "firefox",          comment: "Web Browser",               category: "Network" },
            { name: "GIMP",            icon: "gimp",             comment: "GNU Image Manipulation",    category: "Graphics" },
            { name: "Inkscape",        icon: "inkscape",         comment: "Vector Graphics Editor",    category: "Graphics" },
            { name: "Kitty",           icon: "kitty",            comment: "Fast Terminal Emulator",    category: "System" },
            { name: "Krita",           icon: "krita",            comment: "Digital Painting",          category: "Graphics" },
            { name: "MPV",             icon: "mpv",              comment: "Media Player",              category: "Video" },
            { name: "Neovim",          icon: "nvim",             comment: "Vim-fork text editor",      category: "Development" },
            { name: "OBS Studio",      icon: "obs",              comment: "Live Streaming & Recording",category: "Video" },
            { name: "Prism Launcher",  icon: "prismlauncher",    comment: "Minecraft Launcher",        category: "Game" },
            { name: "Qalculate!",      icon: "qalculate",        comment: "Ultimate Calculator",       category: "Utility" },
            { name: "Rofi",            icon: "rofi",             comment: "Window Switcher & Launcher",category: "System" },
            { name: "Spotify",         icon: "spotify",          comment: "Music Streaming Client",    category: "Audio" },
            { name: "Steam",           icon: "steam",            comment: "Digital Gaming Platform",   category: "Game" },
            { name: "Telegram",        icon: "telegram",         comment: "Fast Desktop Messaging",    category: "Network" },
            { name: "Thunar",          icon: "thunar",           comment: "Fast Lightweight Files",    category: "System" },
            { name: "VLC",             icon: "vlc",              comment: "Multimedia Player",         category: "Video" },
            { name: "Wireshark",       icon: "wireshark",        comment: "Network Protocol Analyzer", category: "Network" },
            { name: "Zen Browser",     icon: "zen-browser",      comment: "Minimalist Firefox Fork",   category: "Network" }
        ]
    }
}
