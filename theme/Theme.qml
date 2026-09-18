// ─────────────────────────────────────────────────────────────────────────────
// KOMOREBI — Theme.qml
// Design-token singleton: exposes typed constants consumed by all components.
// Bind to MaterialYouService.palette for live colour updates.
// ─────────────────────────────────────────────────────────────────────────────
pragma Singleton
import QtQuick
import KOMOREBI.Services 1.0

QtObject {
    // ── Colour aliases (re-exported from service) ─────────────────────────────
    readonly property color primary:            MaterialYouService.palette.primary
    readonly property color onPrimary:          MaterialYouService.palette.onPrimary
    readonly property color primaryContainer:   MaterialYouService.palette.primaryContainer
    readonly property color onPrimaryContainer: MaterialYouService.palette.onPrimaryContainer
    readonly property color secondary:          MaterialYouService.palette.secondary
    readonly property color surface:            MaterialYouService.palette.surface
    readonly property color onSurface:          MaterialYouService.palette.onSurface
    readonly property color surfaceVariant:     MaterialYouService.palette.surfaceVariant
    readonly property color outline:            MaterialYouService.palette.outline
    readonly property color outlineVariant:     MaterialYouService.palette.outlineVariant
    readonly property color error:              MaterialYouService.palette.error

    // ── Typography ────────────────────────────────────────────────────────────
    readonly property string fontFamily:   "JetBrains Mono"
    readonly property string fontFamilyUI: "Inter"

    readonly property int labelSmall:  10
    readonly property int labelMedium: 12
    readonly property int bodySmall:   13
    readonly property int bodyMedium:  14
    readonly property int titleSmall:  16
    readonly property int titleMedium: 18

    // ── Radius (M3 radii) ─────────────────────────────────────────────────────
    readonly property int radiusNone:   0
    readonly property int radiusXSmall: 4
    readonly property int radiusSmall:  8
    readonly property int radiusMedium: 12
    readonly property int radiusLarge:  16
    readonly property int radiusXLarge: 28
    readonly property int radiusFull:   999

    // ── Spacing ───────────────────────────────────────────────────────────────
    readonly property int sp0:  0
    readonly property int sp1:  4
    readonly property int sp2:  8
    readonly property int sp3:  12
    readonly property int sp4:  16
    readonly property int sp5:  20
    readonly property int sp6:  24
    readonly property int sp8:  32
    readonly property int sp10: 40
    readonly property int sp12: 48

    // ── Island geometry ───────────────────────────────────────────────────────
    // Concave "gooey notch" radius at top outer corners
    readonly property int islandGooeyRadius:   20
    readonly property int islandBottomRadius:  28   // convex bottom corners
    readonly property int islandDefaultHeight: 44
    readonly property int islandExpandedHeight:220
    readonly property int islandDefaultWidth:  300
    readonly property int islandExpandedWidth: 640

    // ── Motion — Cyberpunk snappy bezier ─────────────────────────────────────
    // CSS equivalent: cubic-bezier(0.22, 1, 0.36, 1) — fast in, mechanical stop
    readonly property int durationSnap:    180   // ms — standard interaction
    readonly property int durationFast:     90   // ms — micro-interactions
    readonly property int durationExpand:  240   // ms — island open
    readonly property int durationCollapse:160   // ms — island close

    // Easing types used with PropertyAnimation { easing.type: Easing.BezierSpline }
    // Control points for the snappy cyberpunk curve
    readonly property var easingSnap: ({
        type:      "BezierSpline",
        bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
    })
    readonly property var easingCollapse: ({
        type:      "BezierSpline",
        bezierCurve: [0.55, 0.0, 1.0, 0.45, 1.0, 1.0]
    })

    // ── Elevation / shadow ────────────────────────────────────────────────────
    readonly property real surfaceAlpha:        0.88   // island background opacity
    readonly property real glassBlur:           24.0   // backdrop blur radius (px)
    readonly property color shadowColor: Qt.rgba(0, 0, 0, 0.6)
}
