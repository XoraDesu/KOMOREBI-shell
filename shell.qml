// KOMOREBI Shell — Root Entry Point
// QuickShell scans this file at startup via `quickshell -c shell.qml`
// ─────────────────────────────────────────────────────────────────────────────
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import KOMOREBI.Desktop 1.0
import KOMOREBI.Dock 1.0
import KOMOREBI.Launcher 1.0

ShellRoot {
    // ── Global singletons (loaded once, available everywhere via IDs) ─────────

    // ── Desktop overlay & context menu (sits above swww on WlrLayer.Bottom) ──
    Variants {
        model: Quickshell.screens

        DesktopOverlay {
            property var modelData
            screen: modelData
        }
    }

    // ── TopBar dynamic island ────────────────────────────────────────────────
    Variants {
        // Instantiate per-screen components for every connected monitor
        model: Quickshell.screens

        PanelWindow {
            property var modelData

            // Forward the screen reference into each top-bar instance
            readonly property var screen: modelData

            // The singular, always-present top-bar island
            TopBar {
                screen: parent.screen
            }
        }
    }

    // ── Bottom HoverDock (flush-bottom notch with inverse corners) ────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            property var modelData
            readonly property var screen: modelData

            anchors {
                bottom: true
            }

            WlrLayershell.layer: WlrLayer.Top

            HoverDock {
                screen: parent.screen
            }
        }
    }

    // ── Fullscreen AppLauncher (Stock Android & ChromeOS inspired) ────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: launcherWindow
            property var modelData
            readonly property var screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            WlrLayershell.layer: WlrLayer.Overlay
            color: "transparent"

            AppLauncher {
                id: launcher
                screen: parent.screen

                // Global Shortcut hook (Super + Space or Super + D)
                GlobalShortcut {
                    name: "appLauncher"
                    onPressed: launcher.toggle()
                }
            }
        }
    }

    // ── Background colour service — kept alive for the whole session ──────────
    MaterialYouService {}
}

