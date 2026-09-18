// ─────────────────────────────────────────────────────────────────────────────
// KOMOREBI — TopBar.qml
// Flush-top Dynamic Island with:
//   • Inverse (concave/gooey) corners at the top-left and top-right edges
//     where the panel meets the screen bezel — achieved via QtQuick.Shapes
//   • Convex M3 radii on bottom-left and bottom-right corners
//   • Cyberpunk snappy bezier hover expansion
//   • Material You colour bindings
//
// Geometry reference (collapsed, default state):
//
//   SCREEN EDGE ══════════════════════════════════════════════════════
//        ╲            ┌────────────────────────────┐             ╱
//         ╲___________│       ISLAND BODY          │___________╱
//                     └──────────────────────────────────────────
//                             convex bottom corners ↑
//         ↑ concave "gooey" inward curve anchored to top bezel
//
// The gooey effect is drawn as two quarter-circle arcs curving AWAY
// from the island body toward the screen edge, implemented with
// ShapePath cubic bezier control points.
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

// TopBar is planted inside a PanelWindow in shell.qml
Item {
    id: topBar

    required property var screen

    // ── Layout anchor: flush to the very top of the screen ───────────────────
    // The parent PanelWindow configures anchors; we size ourselves here.
    width:  islandRoot.width  + (Theme.islandGooeyRadius * 2)
    height: islandRoot.height + Theme.islandGooeyRadius

    // ── State machine ─────────────────────────────────────────────────────────
    property bool expanded: false

    // Animated geometry targets — these drive the Shape and the content
    property real animWidth:  Theme.islandDefaultWidth
    property real animHeight: Theme.islandDefaultHeight

    // ── Cyberpunk snappy animations ───────────────────────────────────────────
    Behavior on animWidth {
        NumberAnimation {
            duration: topBar.expanded ? Theme.durationExpand : Theme.durationCollapse
            easing.type: Easing.BezierSpline
            // Fast entrance (0.22,1) mechanical stop — cyberpunk feel
            easing.bezierCurve: topBar.expanded
                ? [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
                : [0.55, 0.0, 1.0, 0.45, 1.0, 1.0]
        }
    }
    Behavior on animHeight {
        NumberAnimation {
            duration: topBar.expanded ? Theme.durationExpand : Theme.durationCollapse
            easing.type: Easing.BezierSpline
            easing.bezierCurve: topBar.expanded
                ? [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
                : [0.55, 0.0, 1.0, 0.45, 1.0, 1.0]
        }
    }

    // ── Reusable geometry constants ───────────────────────────────────────────
    readonly property real gR: Theme.islandGooeyRadius    // concave corner radius
    readonly property real bR: Theme.islandBottomRadius   // convex bottom radius

    // Convenience: island left/right edge positions in topBar coordinates
    readonly property real islandLeft:  gR
    readonly property real islandRight: gR + animWidth

    // ── Root island rectangle (clipped content lives here) ───────────────────
    Item {
        id: islandRoot

        // Centred horizontally; anchored to absolute top via gR offset
        x:      parent.gR
        y:      parent.gR   // leave room above for the concave "ear" geometry
        width:  topBar.animWidth
        height: topBar.animHeight

        // ── Full-island Shape: body + bottom rounded corners ─────────────────
        // We draw the island body as a single Shape so we can clip content to it.
        Shape {
            id: islandShape
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4    // MSAA

            ShapePath {
                id: bodyPath
                fillColor:   Qt.rgba(
                    Theme.surface.r,
                    Theme.surface.g,
                    Theme.surface.b,
                    Theme.surfaceAlpha
                )
                strokeColor: Theme.outlineVariant
                strokeWidth: 1

                // Animated fill colour transitions with palette changes
                Behavior on fillColor {
                    ColorAnimation { duration: 400 }
                }

                // ── Path: clockwise from top-left corner ──────────────────────
                // Top-left  → straight across top → top-right
                // → convex arc bottom-right
                // → straight bottom → convex arc bottom-left
                // → back to top-left
                startX: 0;  startY: 0      // top-left (flat, no radius here)

                // Top edge — straight
                PathLine { x: islandRoot.width; y: 0 }

                // Bottom-right convex corner
                PathArc {
                    x: islandRoot.width;              y: islandRoot.height
                    radiusX: topBar.bR;               radiusY: topBar.bR
                    direction: PathArc.Clockwise
                }

                // Actually let's do it properly with PathQuad for rounded bottom corners
                // Replace above with explicit corner segments:
            }
        }

        // ── Island body — drawn as Canvas for full custom path control ────────
        // Using Canvas here because ShapePath rounded-corner-only-on-some-sides
        // is tedious; Canvas lets us draw exactly what we need.
        Canvas {
            id: bodyCanvas
            anchors.fill: parent
            antialiasing: true

            // Redraw when geometry or colours change
            onWidthChanged:  requestPaint()
            onHeightChanged: requestPaint()

            Connections {
                target: Theme
                function onSurfaceChanged()        { bodyCanvas.requestPaint() }
                function onOutlineVariantChanged() { bodyCanvas.requestPaint() }
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.save()

                var r = topBar.bR   // bottom corner radius
                var w = width
                var h = height

                ctx.beginPath()
                // Start top-left (no radius — flush to gooey shape above)
                ctx.moveTo(0, 0)
                // Top edge
                ctx.lineTo(w, 0)
                // Right edge down to bottom-right arc start
                ctx.lineTo(w, h - r)
                // Bottom-right convex arc
                ctx.arcTo(w, h, w - r, h, r)
                // Bottom edge
                ctx.lineTo(r, h)
                // Bottom-left convex arc
                ctx.arcTo(0, h, 0, h - r, r)
                // Left edge back to top
                ctx.lineTo(0, 0)
                ctx.closePath()

                // Glass fill
                ctx.fillStyle = Qt.rgba(
                    Theme.surface.r,
                    Theme.surface.g,
                    Theme.surface.b,
                    Theme.surfaceAlpha
                )
                ctx.fill()

                // Subtle 1px outline
                ctx.strokeStyle = Qt.rgba(
                    Theme.outlineVariant.r,
                    Theme.outlineVariant.g,
                    Theme.outlineVariant.b,
                    0.6
                )
                ctx.lineWidth = 1
                ctx.stroke()

                ctx.restore()
            }
        }

        // ── Content layer (clipped to island body) ────────────────────────────
        Item {
            anchors.fill: parent
            clip: true     // hard-clip content to island bounds

            // ── COLLAPSED CONTENT: minimal clock widget ───────────────────────
            ClockWidget {
                id: clockWidget
                anchors.centerIn: parent
                opacity: topBar.expanded ? 0.0 : 1.0
                Behavior on opacity {
                    NumberAnimation { duration: 80 }
                }
            }

            // ── EXPANDED CONTENT: modular dashboard ───────────────────────────
            IslandDashboard {
                id: dashboard
                anchors.fill: parent
                anchors.margins: Theme.sp4
                opacity: topBar.expanded ? 1.0 : 0.0
                scale:   topBar.expanded ? 1.0 : 0.95
                Behavior on opacity {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
            }
        }

        // ── Hover / click interaction ─────────────────────────────────────────
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton

            onEntered: {
                topBar.animWidth  = Theme.islandExpandedWidth
                topBar.animHeight = Theme.islandExpandedHeight
                topBar.expanded   = true
            }
            onExited: {
                topBar.animWidth  = Theme.islandDefaultWidth
                topBar.animHeight = Theme.islandDefaultHeight
                topBar.expanded   = false
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // INVERSE CORNER (GOOEY) GEOMETRY
    // Two concave "ears" that sit at the top-left and top-right of the island,
    // connecting it flush to the screen top edge.
    //
    // Each ear is a small Canvas that draws a quarter-circle curving INWARD
    // (concave), creating the fluid notch / gooey effect.
    //
    // Coordinate system for LEFT ear (gR × gR box):
    //
    //   (0,0)──────────(gR,0)
    //     │       SCREEN     │
    //     │   (above island) │
    //   (0,gR)         (gR,gR)──── island body starts here
    //
    // We fill the triangular region OUTSIDE the arc with the island fill colour,
    // making the island appear to smoothly curve INTO the screen bezel.
    // ─────────────────────────────────────────────────────────────────────────

    // LEFT inverse corner ear
    Canvas {
        id: gooeyLeft
        width:  topBar.gR
        height: topBar.gR
        x: topBar.islandLeft - topBar.gR    // left edge of island minus ear width
        y: 0                                // flush to top
        antialiasing: true

        onWidthChanged:  requestPaint()
        onHeightChanged: requestPaint()

        Connections {
            target: Theme
            function onSurfaceChanged() { gooeyLeft.requestPaint(); gooeyRight.requestPaint() }
        }

        onPaint: _paintLeftEar(getContext("2d"))
    }

    // RIGHT inverse corner ear
    Canvas {
        id: gooeyRight
        width:  topBar.gR
        height: topBar.gR
        x: topBar.islandRight               // right edge of island
        y: 0
        antialiasing: true

        onWidthChanged:  requestPaint()
        onHeightChanged: requestPaint()

        onPaint: _paintRightEar(getContext("2d"))
    }

    // ── Gooey ear paint functions ─────────────────────────────────────────────
    function _paintLeftEar(ctx) {
        ctx.clearRect(0, 0, gR, gR)
        ctx.save()

        // The concave arc path for the left ear:
        // We sweep from (gR, 0) — top-right of ear, at screen edge —
        // around through the concave quarter circle to (0, gR) — bottom-left.
        // The filled region is the "pie slice" that makes the island appear to
        // merge with the bezel.
        ctx.beginPath()
        ctx.moveTo(gR, 0)               // top-right: where screen edge meets island top
        ctx.arcTo(gR, gR, 0, gR, gR)   // concave arc: pivot at island corner (gR,gR)
        ctx.lineTo(0, 0)                // back along screen top edge
        ctx.closePath()

        // Fill with island surface colour (same as body) → seamless merge
        ctx.fillStyle = Qt.rgba(
            Theme.surface.r,
            Theme.surface.g,
            Theme.surface.b,
            Theme.surfaceAlpha
        )
        ctx.fill()

        // Match the island outline on the curved edge
        ctx.beginPath()
        ctx.moveTo(gR, 0)
        ctx.arcTo(gR, gR, 0, gR, gR)
        ctx.strokeStyle = Qt.rgba(
            Theme.outlineVariant.r,
            Theme.outlineVariant.g,
            Theme.outlineVariant.b,
            0.6
        )
        ctx.lineWidth = 1
        ctx.stroke()

        ctx.restore()
    }

    function _paintRightEar(ctx) {
        ctx.clearRect(0, 0, gR, gR)
        ctx.save()

        // Mirror of left ear:
        // From (0, 0) → arc to (gR, gR) → back to (gR, 0)
        ctx.beginPath()
        ctx.moveTo(0, 0)
        ctx.arcTo(0, gR, gR, gR, gR)
        ctx.lineTo(gR, 0)
        ctx.closePath()

        ctx.fillStyle = Qt.rgba(
            Theme.surface.r,
            Theme.surface.g,
            Theme.surface.b,
            Theme.surfaceAlpha
        )
        ctx.fill()

        ctx.beginPath()
        ctx.moveTo(0, 0)
        ctx.arcTo(0, gR, gR, gR, gR)
        ctx.strokeStyle = Qt.rgba(
            Theme.outlineVariant.r,
            Theme.outlineVariant.g,
            Theme.outlineVariant.b,
            0.6
        )
        ctx.lineWidth = 1
        ctx.stroke()

        ctx.restore()
    }

    // ── Animated gooey ear repositioning on expand/collapse ──────────────────
    // The ears follow the island edges as it animates
    Binding { target: gooeyLeft;  property: "x"; value: topBar.islandLeft - topBar.gR }
    Binding { target: gooeyRight; property: "x"; value: topBar.islandRight }
}
