// ─────────────────────────────────────────────────────────────────────────────
// KOMOREBI — HoverDock.qml
// Flush-bottom floating dock with:
//   • Inverse Corner Radius (Gooey Notch): Flares outward at bottom-left and
//     bottom-right into the screen bezel via cubic bezier splines.
//   • 2px invisible trigger zone along the bottom bezel.
//   • Gamified Kinetic Interaction:
//       - Tracks exact mouseX coordinate upon entry.
//       - Phase 1 (Wave/Rapid Fill): High-speed color wave expands from mouseX,
//         strictly clipped inside the flush-bottom notch geometry.
//       - Phase 2 (Materialization): UI content (workspace dots, app icons)
//         snaps from 0% to 100% opacity via SequentialAnimation.
//       - On cursor exit: Snaps shut with aggressive cyberpunk collapse curve.
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import KOMOREBI.Theme 1.0

Item {
    id: root

    required property var screen

    // ── Geometry Constants ────────────────────────────────────────────────────
    readonly property real dockBodyWidth: 540
    readonly property real dockHeight:    64
    readonly property real gR:            Theme.islandGooeyRadius // 20px concave flare
    readonly property real cR:            Theme.radiusLarge       // 16px convex top radius

    // Total width including both inverse corner ears
    readonly property real totalWidth:    dockBodyWidth + (gR * 2)

    implicitWidth:  totalWidth
    implicitHeight: animHeight

    // ── State Machine ─────────────────────────────────────────────────────────
    property bool revealed: false

    // Animated height: 2px when idle/collapsed (trigger line), 64px when revealed
    property real animHeight: 2

    // ── Coordinate Tracking for Wave Origin ───────────────────────────────────
    // When the mouse hits the bottom trigger zone, exact mouseX is captured.
    // waveOriginX serves as the epicenter of the radial kinetic wave.
    property real waveOriginX:  totalWidth / 2
    property real waveProgress: 0.0  // 0.0 (unexpanded) -> 1.0 (fully covering dock)
    property real waveOpacity:  0.0  // Wave fill opacity during Phase 1

    // Maximum radius needed for the wave to cover the farthest corner of the dock
    readonly property real maxWaveRadius: Math.sqrt(
        Math.max(waveOriginX, totalWidth - waveOriginX) * Math.max(waveOriginX, totalWidth - waveOriginX) +
        dockHeight * dockHeight
    ) * 1.15
    readonly property real currentWaveRadius: waveProgress * maxWaveRadius

    // ── Cyberpunk Snappy Motion for Dock Expansion/Collapse ───────────────────
    Behavior on animHeight {
        NumberAnimation {
            duration: root.revealed ? Theme.durationExpand : Theme.durationCollapse
            easing.type: Easing.BezierSpline
            // Snappy entrance (0.22, 1.0, 0.36, 1.0) vs swift collapse (0.55, 0.0, 1.0, 0.45)
            easing.bezierCurve: root.revealed
                ? [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
                : [0.55, 0.0, 1.0, 0.45, 1.0, 1.0]
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TWO-PHASE SEQUENTIAL ANIMATION (REVEAL)
    // Phase 1: Rapid kinetic wave explosion from mouseX (durationFast: 90ms)
    // Phase 2: Instant UI content materialization + wave settling
    // ─────────────────────────────────────────────────────────────────────────
    SequentialAnimation {
        id: revealSequence

        // Reset states before firing
        ScriptAction {
            script: {
                contentContainer.opacity = 0.0
                root.waveProgress = 0.0
                root.waveOpacity = 0.95
            }
        }

        // ── PHASE 1: The Wave / Rapid Fill ───────────────────────────────────
        // Solid color block rapidly blasts outward from the captured mouseX
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "waveProgress"
                from: 0.0
                to: 1.0
                duration: Theme.durationFast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
            }
            NumberAnimation {
                target: root
                property: "waveOpacity"
                from: 0.95
                to: 0.75
                duration: Theme.durationFast
            }
        }

        // ── Micro-Pause (fraction of a millisecond settling barrier) ──────────
        PauseAnimation {
            duration: 16 // Exactly 1 display frame
        }

        // ── PHASE 2: Materialization ─────────────────────────────────────────
        // UI content snaps from 0% to 100% opacity instantly
        ParallelAnimation {
            NumberAnimation {
                target: contentContainer
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: Theme.durationFast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
            }
            // Wave gracefully dissolves into the dark Wabi-Sabi ink surface
            NumberAnimation {
                target: root
                property: "waveOpacity"
                to: 0.0
                duration: Theme.durationFast * 1.4
            }
        }
    }

    // ── COLLAPSE SEQUENCE (Cursor Exit) ──────────────────────────────────────
    SequentialAnimation {
        id: collapseSequence

        ParallelAnimation {
            // UI content rapidly dissolves
            NumberAnimation {
                target: contentContainer
                property: "opacity"
                to: 0.0
                duration: Theme.durationFast
            }
            // Wave opacity resets
            NumberAnimation {
                target: root
                property: "waveOpacity"
                to: 0.0
                duration: Theme.durationFast
            }
        }

        ScriptAction {
            script: {
                root.revealed = false
                root.animHeight = 2
                root.waveProgress = 0.0
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // INVERSE CORNER (GOOEY) MASKING LOGIC & RENDER CONTAINER
    //
    // Geometry Specification (Flush-Bottom Notch):
    //
    //               (gR+cR, 0) ═════════════════ (gR+W-cR, 0)
    //              ╭─────────────────────────────────────────╮
    //     (gR, cR) │               DOCK BODY                 │ (gR+W, cR)
    //              │                                         │
    //   (gR, H-gR) │                                         │ (gR+W, H-gR)
    //             ╭┘                                         └╮
    //            ╱                                             ╲
    //   (0, H)  ═════════════════════════════════════════════════  (W+2gR, H)
    //   ═══════════════════════════════════════════════════════════════════════
    //                           SCREEN BOTTOM BEZEL
    //
    // The concave ears sweep from the vertical body walls (x=gR and x=gR+W)
    // outward horizontally along the screen bezel (y=H).
    // Tangents are strictly horizontal (dy=0) at y=H and strictly vertical
    // (dx=0) at the body walls, creating a seamless C1 continuous spline.
    // ─────────────────────────────────────────────────────────────────────────

    // Vector Shape Definition for the Notch (Used for visual stroke and geometry reference)
    Shape {
        id: dockVectorShape
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4
        visible: root.animHeight > 10

        ShapePath {
            id: notchPath
            strokeColor: Qt.rgba(Theme.outlineVariant.r, Theme.outlineVariant.g, Theme.outlineVariant.b, 0.4)
            strokeWidth: 1
            fillColor:   "transparent" // Fill is handled by the clipped Canvas

            // Start at bottom-left ear flush on the bezel
            startX: 0
            startY: root.dockHeight

            // 1. Bottom-Left Inverse (Concave) Ear: (0, H) -> (gR, H - gR)
            PathCubic {
                x:  root.gR
                y:  root.dockHeight - root.gR
                control1X: root.gR * 0.55228
                control1Y: root.dockHeight
                control2X: root.gR
                control2Y: root.dockHeight - (root.gR * 0.44772)
            }

            // 2. Left vertical wall straight up to top-left convex corner
            PathLine {
                x: root.gR
                y: root.cR
            }

            // 3. Top-Left Convex Corner: (gR, cR) -> (gR + cR, 0)
            PathCubic {
                x:  root.gR + root.cR
                y:  0
                control1X: root.gR
                control1Y: root.cR * 0.44772
                control2X: root.gR + (root.cR * 0.55228)
                control2Y: 0
            }

            // 4. Top horizontal edge
            PathLine {
                x: root.gR + root.dockBodyWidth - root.cR
                y: 0
            }

            // 5. Top-Right Convex Corner: (gR + W - cR, 0) -> (gR + W, cR)
            PathCubic {
                x:  root.gR + root.dockBodyWidth
                y:  root.cR
                control1X: root.gR + root.dockBodyWidth - (root.cR * 0.44772)
                control1Y: 0
                control2X: root.gR + root.dockBodyWidth
                control2Y: root.cR * 0.44772
            }

            // 6. Right vertical wall straight down to bottom-right ear
            PathLine {
                x: root.gR + root.dockBodyWidth
                y: root.dockHeight - root.gR
            }

            // 7. Bottom-Right Inverse (Concave) Ear: (gR + W, H - gR) -> (W + 2gR, H)
            PathCubic {
                x:  root.totalWidth
                y:  root.dockHeight
                control1X: root.gR + root.dockBodyWidth
                control1Y: root.dockHeight - (root.gR * 0.44772)
                control2X: root.totalWidth - (root.gR * 0.55228)
                control2Y: root.dockHeight
            }

            // 8. Bottom edge along screen bezel back to (0, H)
            PathLine {
                x: 0
                y: root.dockHeight
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HARDWARE-ACCELERATED CLIPPING CANVAS
    // Uses ctx.clip() on the mathematical notch path to guarantee the expanding
    // kinetic wave NEVER leaks outside the flush-bottom notch geometry.
    // ─────────────────────────────────────────────────────────────────────────
    Canvas {
        id: dockClippedSurface
        anchors.fill: parent
        antialiasing: true
        visible: root.animHeight > 4

        // Redraw canvas whenever geometry or wave parameters update
        Connections {
            target: root
            function onWaveProgressChanged() { dockClippedSurface.requestPaint() }
            function onWaveOpacityChanged()  { dockClippedSurface.requestPaint() }
            function onAnimHeightChanged()   { dockClippedSurface.requestPaint() }
        }
        Connections {
            target: Theme
            function onPrimaryChanged() { dockClippedSurface.requestPaint() }
            function onSurfaceChanged() { dockClippedSurface.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d")
            var w = root.totalWidth
            var h = root.animHeight
            var g = root.gR
            var c = root.cR
            var bw = root.dockBodyWidth

            ctx.clearRect(0, 0, w, h)
            ctx.save()

            // ── Step 1: Trace the complete flush-bottom notch path ───────────
            ctx.beginPath()

            // Bottom-left ear start
            ctx.moveTo(0, h)

            // Concave bottom-left arc curving up to body
            ctx.bezierCurveTo(
                g * 0.55228, h,
                g, h - (g * 0.44772),
                g, Math.max(0, h - g)
            )

            // Left vertical wall
            ctx.lineTo(g, c)

            // Convex top-left corner
            ctx.bezierCurveTo(
                g, c * 0.44772,
                g + (c * 0.55228), 0,
                g + c, 0
            )

            // Top straight edge
            ctx.lineTo(g + bw - c, 0)

            // Convex top-right corner
            ctx.bezierCurveTo(
                g + bw - (c * 0.44772), 0,
                g + bw, c * 0.44772,
                g + bw, c
            )

            // Right vertical wall
            ctx.lineTo(g + bw, Math.max(0, h - g))

            // Concave bottom-right arc curving down to bezel
            ctx.bezierCurveTo(
                g + bw, h - (g * 0.44772),
                w - (g * 0.55228), h,
                w, h
            )

            // Bottom edge along screen bezel
            ctx.lineTo(0, h)
            ctx.closePath()

            // ── Step 2: Base Wabi-Sabi ink surface fill ───────────────────────
            ctx.fillStyle = Qt.rgba(
                Theme.surface.r,
                Theme.surface.g,
                Theme.surface.b,
                Theme.surfaceAlpha
            )
            ctx.fill()

            // ── Step 3: STRICT NOTCH CLIPPING ─────────────────────────────────
            // Any subsequent drawing is strictly constrained within the notch
            ctx.clip()

            // ── Step 4: Kinetic Wave Render (Phase 1 Rapid Fill) ──────────────
            if (root.waveProgress > 0.001 && root.waveOpacity > 0.001) {
                var rad = root.currentWaveRadius

                ctx.beginPath()
                ctx.arc(root.waveOriginX, h, rad, 0, Math.PI * 2)

                // High-speed cyber neon wave fill
                ctx.fillStyle = Qt.rgba(
                    Theme.primary.r,
                    Theme.primary.g,
                    Theme.primary.b,
                    root.waveOpacity
                )
                ctx.fill()

                // Secondary radial highlight ring at the wave crest
                ctx.beginPath()
                ctx.arc(root.waveOriginX, h, Math.max(0, rad - 2), 0, Math.PI * 2)
                ctx.strokeStyle = Qt.rgba(1.0, 1.0, 1.0, root.waveOpacity * 0.6)
                ctx.lineWidth = 3
                ctx.stroke()
            }

            ctx.restore()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // UI CONTENT LAYER (Phase 2 Materialization)
    // Snaps from 0% to 100% opacity once the wave fully covers the dock.
    // ─────────────────────────────────────────────────────────────────────────
    Item {
        id: contentContainer
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width:  root.dockBodyWidth
        height: root.dockHeight
        opacity: 0.0
        visible: root.animHeight > 30

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin:  Theme.sp4
            anchors.rightMargin: Theme.sp4
            spacing: Theme.sp3

            // ── Section 1: Minimalist Workspace Indicator ─────────────────────
            Row {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: 5
                    delegate: Rectangle {
                        width: index === 0 ? 16 : 6
                        height: 6
                        radius: 3
                        color: index === 0 ? Theme.primary : Theme.outlineVariant

                        Behavior on width {
                            NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutBack }
                        }
                        Behavior on color {
                            ColorAnimation { duration: Theme.durationFast }
                        }
                    }
                }
            }

            // Divider rule
            Rectangle {
                Layout.preferredWidth:  1
                Layout.preferredHeight: 24
                color:   Theme.outlineVariant
                opacity: 0.35
            }

            // ── Section 2: Pinned & Active App Icons ──────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp2

                // App 1: Terminal
                DockAppIcon {
                    icon: "󰞷"
                    name: "Terminal"
                    accentColor: Theme.primary
                    command: "kitty || alacritty"
                }

                // App 2: Code Editor
                DockAppIcon {
                    icon: "󰨞"
                    name: "Editor"
                    accentColor: Theme.secondary
                    command: "code || nvim"
                }

                // App 3: Web Browser
                DockAppIcon {
                    icon: "󰈹"
                    name: "Browser"
                    accentColor: Theme.primary
                    command: "firefox || zen-browser"
                }

                // App 4: File Manager
                DockAppIcon {
                    icon: "󰉋"
                    name: "Files"
                    accentColor: Theme.secondary
                    command: "thunar || dolphin"
                }

                // App 5: Music / Media
                DockAppIcon {
                    icon: "󰝚"
                    name: "Music"
                    accentColor: Theme.primary
                    command: "spotify || amberol"
                }

                Item { Layout.fillWidth: true }
            }

            // Divider rule
            Rectangle {
                Layout.preferredWidth:  1
                Layout.preferredHeight: 24
                color:   Theme.outlineVariant
                opacity: 0.35
            }

            // ── Section 3: Komorebi App Drawer Orb ────────────────────────────
            Rectangle {
                width:  36
                height: 36
                radius: Theme.radiusMedium
                color:  launcherMouse.containsMouse
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                    : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.4)
                border.color: launcherMouse.containsMouse ? Theme.primary : Theme.outlineVariant
                border.width: 1

                scale: launcherMouse.containsMouse ? 1.08 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutBack }
                }

                Text {
                    anchors.centerIn: parent
                    text: "󱗼"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 17
                    color: Theme.primary
                }

                MouseArea {
                    id: launcherMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        launcherProc.running = true
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MOUSE INTERACTION & TRIGGER MECHANICS
    // ─────────────────────────────────────────────────────────────────────────

    // 1. Invisible 2px trigger zone at the absolute bottom screen edge
    // When dock is collapsed (animHeight == 2), this captures entry and records mouseX.
    MouseArea {
        id: bottomTriggerZone
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        height: 2
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        onPositionChanged: function(mouse) {
            if (!root.revealed) {
                // Capture exact mouseX coordinate for the wave expansion epicenter
                root.waveOriginX = Math.max(0, Math.min(mouse.x, root.totalWidth))
                root.revealed = true
                root.animHeight = root.dockHeight
                collapseSequence.stop()
                revealSequence.restart()
            }
        }
    }

    // 2. Full dock hover area: Keeps the dock alive while cursor stays inside
    MouseArea {
        id: fullDockHoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: root.revealed

        onExited: {
            // When cursor leaves the dock area, gracefully snap back down
            revealSequence.stop()
            collapseSequence.restart()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // INLINE COMPONENT: DockAppIcon
    // Material 3 Icon Button with cyberpunk scale pop and command trigger.
    // ─────────────────────────────────────────────────────────────────────────
    component DockAppIcon: Item {
        id: appItem

        required property string icon
        required property string name
        required property color  accentColor
        required property string command

        implicitWidth:  42
        implicitHeight: 42

        property bool isHovered: false

        Rectangle {
            id: iconCard
            anchors.fill: parent
            radius: Theme.radiusMedium
            color: appItem.isHovered
                ? Qt.rgba(appItem.accentColor.r, appItem.accentColor.g, appItem.accentColor.b, 0.16)
                : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
            border.color: appItem.isHovered ? appItem.accentColor : Theme.outlineVariant
            border.width: 1

            // Cyberpunk micro-scale bounce
            scale: appItem.isHovered ? 1.14 : 1.0
            Behavior on scale {
                NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutBack }
            }
            Behavior on color {
                ColorAnimation { duration: Theme.durationFast }
            }
            Behavior on border.color {
                ColorAnimation { duration: Theme.durationFast }
            }

            Text {
                anchors.centerIn: parent
                text: appItem.icon
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 18
                color: appItem.isHovered ? appItem.accentColor : Theme.onSurface
                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }

            // Bottom active indicator dot
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 3
                width: 4; height: 4; radius: 2
                color: appItem.accentColor
                opacity: appItem.isHovered ? 1.0 : 0.4
            }
        }

        // App Launch Trigger
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onEntered: appItem.isHovered = true
            onExited:  appItem.isHovered = false

            onClicked: {
                appProc.command = ["bash", "-c", appItem.command]
                appProc.running = true
            }
        }

        Process {
            id: appProc
            command: ["true"]
        }
    }

    // ── External Launchers ────────────────────────────────────────────────────
    Process {
        id: launcherProc
        command: ["bash", "-c", "rofi -show drun || wofi --show drun || tofi-drun"]
    }
}
