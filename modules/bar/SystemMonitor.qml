// ─────────────────────────────────────────────────────────────────────────────
// KOMOREBI — SystemMonitor.qml
// Minimalist CPU / GPU / RAM monitor panel.
//
// Visual language:
//   • Three rows — one per resource (CPU, GPU, RAM)
//   • Each row: icon glyph  |  label  |  ultra-thin animated bar  |  value%
//   • Bar fills with a gradient tinted from Theme.primary → Theme.secondary
//   • Bar animation uses cyberpunk bezier (durationSnap) so it "snaps" to the
//     new value rather than easing softly — mechanical, alive.
//   • Values polled every 1.5 s via shell commands appropriate for:
//       CPU  — Ryzen (reads /proc/stat delta, gives real %)
//       GPU  — NVIDIA RTX (nvidia-smi)
//       RAM  — /proc/meminfo
//
// Shell commands output a plain integer 0–100. Anything that fails gracefully
// falls back to "–" and leaves the bar at its last position.
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import KOMOREBI.Theme 1.0

Item {
    id: root

    // ── Internal state ────────────────────────────────────────────────────────
    property real cpuPercent: 0
    property real gpuPercent: 0
    property real ramPercent: 0

    // Previous /proc/stat values for delta calculation
    property var  _prevCpu: null

    // ── Poll timers ───────────────────────────────────────────────────────────
    Timer {
        interval: 1500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            cpuProc.running  = true
            gpuProc.running  = true
            ramProc.running  = true
        }
    }

    // CPU — /proc/stat delta method (accurate for Ryzen multi-core)
    Process {
        id: cpuProc
        command: ["bash", "-c",
            "awk '/^cpu / {idle=$5+$6; total=0; for(i=2;i<=NF;i++) total+=$i; print idle, total}' /proc/stat"
        ]
        stdout: StdoutCollector { id: cpuOut }
        onExited: function(code) {
            if (code !== 0) return
            var parts = cpuOut.text.trim().split(/\s+/)
            if (parts.length < 2) return
            var idle  = parseFloat(parts[0])
            var total = parseFloat(parts[1])
            if (root._prevCpu) {
                var dIdle  = idle  - root._prevCpu.idle
                var dTotal = total - root._prevCpu.total
                if (dTotal > 0)
                    root.cpuPercent = Math.max(0, Math.min(100, (1 - dIdle / dTotal) * 100))
            }
            root._prevCpu = { idle: idle, total: total }
        }
    }

    // GPU — NVIDIA RTX 3050 via nvidia-smi
    Process {
        id: gpuProc
        command: ["bash", "-c",
            "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1"
        ]
        stdout: StdoutCollector { id: gpuOut }
        onExited: function(code) {
            if (code !== 0) return
            var v = parseFloat(gpuOut.text.trim())
            if (!isNaN(v)) root.gpuPercent = Math.max(0, Math.min(100, v))
        }
    }

    // RAM — /proc/meminfo
    Process {
        id: ramProc
        command: ["bash", "-c",
            "awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf \"%.0f\", (t-a)/t*100}' /proc/meminfo"
        ]
        stdout: StdoutCollector { id: ramOut }
        onExited: function(code) {
            if (code !== 0) return
            var v = parseFloat(ramOut.text.trim())
            if (!isNaN(v)) root.ramPercent = Math.max(0, Math.min(100, v))
        }
    }

    // ── Layout ────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.sp3

        // ── Header label ───────────────────────────────────────────────────────
        Text {
            text: "SYSTEM"
            font.family:      Theme.fontFamily
            font.pixelSize:   Theme.labelSmall
            font.letterSpacing: 3.0
            font.weight:      Font.Medium
            color:            Theme.outline
            Layout.topMargin: Theme.sp1
        }

        // ── CPU Row ────────────────────────────────────────────────────────────
        ResourceRow {
            icon:    ""      // Nerd Font: CPU
            label:   "RYZEN"
            value:   root.cpuPercent
            accent:  Theme.primary
            Layout.fillWidth: true
        }

        // ── GPU Row ────────────────────────────────────────────────────────────
        ResourceRow {
            icon:    "󰍛"      // Nerd Font: GPU / chip
            label:   "RTX"
            value:   root.gpuPercent
            accent:  Theme.secondary
            Layout.fillWidth: true
        }

        // ── RAM Row ────────────────────────────────────────────────────────────
        ResourceRow {
            icon:    "󰘚"      // Nerd Font: memory
            label:   "RAM"
            value:   root.ramPercent
            accent:  Theme.tertiary
            Layout.fillWidth: true
        }

        Item { Layout.fillHeight: true }   // push rows to top
    }

    // ── ResourceRow — inline component (defined once, instantiated three times) ──
    component ResourceRow: Item {
        id: row

        required property string icon
        required property string label
        required property real   value    // 0–100
        required property color  accent

        implicitHeight: 28

        // Animated value — cyberpunk snap bezier
        property real animValue: value
        Behavior on animValue {
            NumberAnimation {
                duration:    Theme.durationSnap
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
            }
        }
        onValueChanged: animValue = value

        RowLayout {
            anchors.fill: parent
            spacing: Theme.sp2

            // Icon
            Text {
                text:           row.icon
                font.family:    "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color:          row.accent
                Layout.preferredWidth: 18
            }

            // Label
            Text {
                text:           row.label
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.labelSmall
                font.letterSpacing: 1.5
                color:          Theme.outline
                Layout.preferredWidth: 36
            }

            // Track (background bar)
            Item {
                Layout.fillWidth: true
                height: 3

                // Track background
                Rectangle {
                    anchors.fill: parent
                    radius:       Theme.radiusFull
                    color:        Theme.outlineVariant
                    opacity:      0.3
                }

                // Fill bar
                Rectangle {
                    width:  parent.width * (row.animValue / 100)
                    height: parent.height
                    radius: Theme.radiusFull
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: row.accent }
                        GradientStop { position: 1.0; color: Qt.lighter(row.accent, 1.3) }
                    }
                    Behavior on width {
                        NumberAnimation {
                            duration:    Theme.durationSnap
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
                        }
                    }
                }
            }

            // Value text
            Text {
                text:           Math.round(row.animValue) + "%"
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.labelSmall
                font.weight:    Font.Medium
                color:          row.accent
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
