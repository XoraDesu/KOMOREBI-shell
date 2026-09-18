// ─────────────────────────────────────────────────────────────────────────────
// KOMOREBI — MaterialYouService.qml
// Global singleton: runs `matugen` on wallpaper change, emits updated palette.
// Lives in services/ and is instantiated once from shell.qml.
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import Quickshell
import Quickshell.Io

// Exposed as a global object so any QML file can write:
//   MaterialYouService.palette.primary
pragma Singleton
Item {
    id: root

    // ── Public palette API ────────────────────────────────────────────────────
    // All colours are Qt colour strings (e.g. "#A8C5DA").
    // Components bind to these properties; they update automatically.
    readonly property QtObject palette: QtObject {
        // Core M3 roles — seeded with Wabi-Sabi defaults until matugen fires
        property color primary:           "#8FAAB8"   // Muted steel-blue
        property color onPrimary:         "#1A2730"
        property color primaryContainer:  "#243340"
        property color onPrimaryContainer:"#C4DDE8"
        property color secondary:         "#9AAFA5"
        property color onSecondary:       "#1E2D27"
        property color tertiary:          "#B5A89A"
        property color onTertiary:        "#2F261E"
        property color surface:           "#12171A"   // Near-black ink
        property color onSurface:         "#D8E4E9"
        property color surfaceVariant:    "#1E282D"
        property color outline:           "#3D5059"
        property color outlineVariant:    "#283540"
        property color inverseSurface:    "#D8E4E9"
        property color shadow:            "#000000"
        property color scrim:             "#000000"
        property color error:             "#CF6679"
        property color onError:           "#1E0009"
    }

    // ── Public state & signals ───────────────────────────────────────────────
    readonly property string currentWallpaper: root._wallpaperPath
    readonly property bool ready: root._ready
    signal wallpaperChanged(string path)

    // ── Internal state ────────────────────────────────────────────────────────
    property string _wallpaperPath: ""
    property bool   _ready: false

    // ── Wallpaper watcher ─────────────────────────────────────────────────────
    // Reads swww's current image via `swww query`
    // Change this to `hyprctl hyprpaper listactive` if you use hyprpaper.
    Timer {
        id: pollTimer
        interval: 3000       // Poll every 3 s — lightweight
        repeat:   true
        running:  true
        onTriggered: wallpaperQuery.running = true
    }

    Process {
        id: wallpaperQuery
        command: ["swww", "query"]
        stdout: SplitParser {
            onRead: function(line) {
                // swww output: "MONITOR: image: /path/to/wall.jpg"
                var m = line.match(/image:\s*(.+)$/)
                if (m && m[1] !== root._wallpaperPath) {
                    root._wallpaperPath = m[1].trim()
                    matugenProc.running = true
                }
            }
        }
    }

    // ── swww setter process ──────────────────────────────────────────────────
    Process {
        id: swwwSetProc
        command: ["swww", "img", root._wallpaperPath, "--transition-type", "wipe", "--transition-angle", "30", "--transition-step", "90", "--transition-fps", "60"]
    }

    // ── Public API to update wallpaper and trigger Material You extraction ────
    function setWallpaper(imagePath) {
        if (!imagePath || imagePath.length === 0) return
        root._wallpaperPath = imagePath

        // 1. Trigger swww with smooth transition
        swwwSetProc.command = [
            "swww", "img", imagePath,
            "--transition-type", "wipe",
            "--transition-angle", "30",
            "--transition-step", "90",
            "--transition-fps", "60"
        ]
        swwwSetProc.running = true

        // 2. Trigger matugen dark scheme color extraction
        matugenProc.command = ["matugen", "image", imagePath, "--json", "hex"]
        matugenProc.running = true

        // 3. Persist current selection to config directory
        saveWallpaperProc.command = [
            "bash", "-c",
            "mkdir -p ~/.config/komorebi && echo '" + imagePath + "' > ~/.config/komorebi/current_wallpaper"
        ]
        saveWallpaperProc.running = true

        root.wallpaperChanged(imagePath)
    }

    Process {
        id: saveWallpaperProc
        command: ["true"]
    }

    // ── matugen invocation ────────────────────────────────────────────────────
    // matugen image <path> --json hex  → outputs JSON colour map to stdout
    Process {
        id: matugenProc
        command: ["matugen", "image", root._wallpaperPath, "--json", "hex"]
        stdout: StdoutCollector {
            id: matugenOut
        }
        onExited: function(code) {
            if (code === 0) root._applyJson(matugenOut.text)
        }
    }

    // ── JSON → palette mapper ─────────────────────────────────────────────────
    function _applyJson(json) {
        try {
            var obj = JSON.parse(json)
            var c   = obj["colors"]["dark"]   // Always use dark scheme

            var p = root.palette
            p.primary            = c["primary"]            ?? p.primary
            p.onPrimary          = c["on_primary"]         ?? p.onPrimary
            p.primaryContainer   = c["primary_container"]  ?? p.primaryContainer
            p.onPrimaryContainer = c["on_primary_container"]?? p.onPrimaryContainer
            p.secondary          = c["secondary"]          ?? p.secondary
            p.onSecondary        = c["on_secondary"]        ?? p.onSecondary
            p.tertiary           = c["tertiary"]           ?? p.tertiary
            p.onTertiary         = c["on_tertiary"]        ?? p.onTertiary
            p.surface            = c["surface"]            ?? p.surface
            p.onSurface          = c["on_surface"]         ?? p.onSurface
            p.surfaceVariant     = c["surface_variant"]    ?? p.surfaceVariant
            p.outline            = c["outline"]            ?? p.outline
            p.outlineVariant     = c["outline_variant"]    ?? p.outlineVariant
            p.error              = c["error"]              ?? p.error
            p.onError            = c["on_error"]           ?? p.onError

            root._ready = true
        } catch(e) {
            console.warn("[KOMOREBI] matugen JSON parse error:", e)
        }
    }
}
