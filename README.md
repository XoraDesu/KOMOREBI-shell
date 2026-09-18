# KOMOREBI 侘寂

> **A minimalist, highly modular QuickShell desktop environment for Hyprland.**  
> *Wabi-Sabi aesthetic restraint · Cyberpunk mechanical motion · Dynamic Material You theming.*

---

## Philosophy & Core Design Principles

| Principle | Architectural Implementation |
|:---|:---|
| **侘寂 (Wabi-Sabi)** | Imperfect, natural simplicity. Dark ink translucent surfaces (`#12171A`), generous breathing space, and zero visual clutter. |
| **Cyberpunk Motion** | Aggressive, snappy cubic bezier transitions (`0.22, 1.0, 0.36, 1.0`). Fast entrance, mechanical stop, and zero sluggish animations. |
| **Material 3 / Material You** | Live wallpaper color extraction via `matugen` producing a dynamic dark scheme palette, propagating instantaneously to all QML bindings. |
| **Illogical Impulse Architecture** | Modular service singletons, typed design tokens, per-screen `Variants`, and dedicated desktop/dock/bar layers. |

---

## File & Module Architecture

```
d:\Linux\KOMOREBI\ (deployed to ~/.config/quickshell)
│
├── shell.qml                        ← Root ShellRoot entry point (orchestrates per-screen Variants)
├── quickshell.conf                  ← QML import paths & runtime engine configuration
├── install.sh / installer.sh        ← Automated installer (symlink/copy modes, dependency checker)
├── uninstall.sh / uninstaller.sh    ← Safe uninstaller (process terminator, backup restorer, Hyprland cleaner)
├── README.md                        ← Architectural documentation & design system reference
│
├── theme/                           ← [KOMOREBI.Theme] Design tokens singleton
│   ├── Theme.qml                    ← Typed color roles, typography, radii, spacing, and bezier curves
│   └── qmldir                       ← Singleton module registration
│
├── services/                        ← [KOMOREBI.Services] Core background daemon singletons
│   ├── MaterialYouService.qml       ← swww wallpaper watcher + matugen dark scheme extractor + palette emitter
│   └── qmldir
│
├── modules/
│   ├── bar/                         ← [KOMOREBI.Bar] Top-edge Dynamic Island
│   │   ├── TopBar.qml               ★ Flush-top island with inverse corner (concave) gooey ears
│   │   ├── ClockWidget.qml          ← Collapsed island state (minimal clock + breathing pulse orb)
│   │   ├── IslandDashboard.qml      ← Expanded dashboard with segmented tab bar & slide stack
│   │   ├── SystemMonitor.qml        ← AMD Ryzen CPU delta, Nvidia RTX 3050 GPU, and RAM monitor
│   │   ├── MediaPlayer.qml          ← MPRIS controller (track metadata, scrub bar, mechanical controls)
│   │   ├── ControlCenter.qml        ← Volume & brightness mechanical sliders, Wi-Fi & DnD toggles
│   │   ├── StatusPill.qml           ← Reusable hardware status chip
│   │   ├── WorkspaceWidget.qml      ← Hyprland workspace dots with active indicator & IPC click
│   │   └── qmldir
│   │
│   ├── desktop/                     ← [KOMOREBI.Desktop] Desktop layer & theme engine
│   │   ├── DesktopOverlay.qml       ★ Transparent WlrLayer.Bottom background layer sitting above swww
│   │   ├── ContextMenu.qml          ← Right-click floating menu snapping to cursor coordinates
│   │   ├── WallpaperCarousel.qml    ← Horizontal thumbnail picker, folder scanner, live palette swatches
│   │   ├── MaterialSwitch.qml       ← Material 3 switch specification (52×32 track, 16→24px thumb)
│   │   ├── FocusTimerWidget.qml     ← Desktop-level Wabi-Sabi Pomodoro / Focus Timer HUD
│   │   ├── ZenClockWidget.qml       ← Desktop-level clock with Japanese kanji calendar date
│   │   └── qmldir
│   │
│   ├── dock/                        ← [KOMOREBI.Dock] Bottom kinetic dock
│   │   ├── HoverDock.qml            ★ Flush-bottom notch with inverse corner ears & 2-phase wave reveal
│   │   └── qmldir
│   │
│   └── launcher/                    ← [KOMOREBI.Launcher] Fullscreen focused app drawer
│       ├── AppLauncher.qml          ★ Stock Android & ChromeOS inspired drawer with Alphabet Fast Scroller
│       └── qmldir
│
└── config/
    └── hyprland.conf.komorebi       ← Reference snippet for Hyprland autostart, keybinds, and layer rules
```

---

## Core Systems Deep-Dive

### 1. The Dynamic Island (`TopBar.qml` & `IslandDashboard.qml`)
- **Inverse Corner Geometry (Gooey Ears)**: Two small `Canvas` ears (`gooeyLeft`, `gooeyRight`) sit at `y: 0`, sweeping inward with `ctx.arcTo()` towards the island body corners. This makes the island appear to organically melt out of the screen bezel.
- **Segmented Modular Dashboard**: Hovering over the island expands its dimensions from `300×44` to `640×220` with `durationExpand` (240ms). Houses three switchable panels:
  - **Hardware Monitor**: Ryzen CPU delta via `/proc/stat`, Nvidia RTX 3050 metrics via `nvidia-smi`, and RAM via `/proc/meminfo`.
  - **Media Player**: Real-time MPRIS metadata extraction, scrub bar, and mechanical playback controls.
  - **Control Center**: Micro-sliders for volume and backlight with 1px mechanical indicators, plus pill toggles for Wi-Fi and Do-Not-Disturb.

### 2. Wallpaper & Theming Engine (`DesktopOverlay.qml`)
- **Layer-Shell Stacking**: Runs on `WlrLayer.Bottom`, positioned directly above the wallpaper daemon (`swww` on `WlrLayer.Background`) and underneath normal application windows.
- **Context Menu Interaction**: Captures right-clicks (and two-finger trackpad taps) on empty desktop areas, snapping into view at the cursor's exact coordinates with boundary clamping to prevent off-screen overflow.
- **Dynamic Theming Pipeline**:
  ```
  User Selects Wallpaper ──► MaterialYouService.setWallpaper(path)
                                    │
               ┌────────────────────┴────────────────────┐
               ▼                                         ▼
   swww img with wipe transition             matugen image <path> --json hex
               │                                         │
               ▼                                         ▼
   Screen background updates                 dark palette extracted to QtObject
                                                         │
                                                         ▼
                                             Live QML property rebindings
                                             (Theme.primary, Theme.surface...)
  ```
- **Desktop HUD Widgets**: Built-in Material 3 switches toggle the desktop **Focus Timer** (Pomodoro intervals) and **Zen Clock** (Japanese kanji date & clock).

### 3. HoverDock (`HoverDock.qml`)
- **Flush-Bottom Notch**: Mirrors the top island with inverse corner gooey ears flaring outward horizontally along the bottom bezel.
- **2px Invisible Trigger Zone**: Resting collapsed at a height of 2px along the bottom bezel, it captures the exact `mouseX` coordinate on contact.
- **Gamified Two-Phase Kinetic Reveal**:
  - **Phase 1 (The Wave)**: A high-speed primary color wave bursts outward from `mouseX` in `durationFast` (90ms) along `[0.22, 1.0, 0.36, 1.0, 1.0, 1.0]`. The wave is strictly clipped inside the notch spline via `Canvas.clip()`.
  - **Phase 2 (Materialization)**: After a 16ms settling frame, the workspace dots, M3 application icons, and launcher orb instantly snap to 100% opacity.
  - **Exit**: Moving the cursor away swiftly collapses the dock back to 2px with `durationCollapse` (160ms).

### 4. Fullscreen App Drawer (`AppLauncher.qml`)
- **Focused Backdrop**: Full-screen translucent dark ink overlay (`#12171A` at 92% opacity) with subtle radial focus glow, obscuring all background windows.
- **Stock Android & ChromeOS Styling**: Centered Material 3 search pill with immediate text focus, fuzzy matching, and keyboard navigation (`Escape` to close, `Enter` to launch).
- **A $\rightarrow$ Z Alphabetical Sorting**: Ingests system `.desktop` entries from Quickshell's native `DesktopEntries.applications` singleton and sorts them alphabetically.
- **Alphabet Fast Scroller**: Vertical touch/drag track on the far right edge mapping $Y$-coordinates to $A-Z$ buckets, popping up a large floating **Letter Indicator** and jumping the `GridView` instantaneously via `positionViewAtIndex()`.

---

## Motion Physics & Bezier Reference

All animations in KOMOREBI use aggressive cyberpunk bezier curves to ensure mechanical precision:

| Easing Token | Bezier Control Points | Duration | Typical Use |
|:---|:---|:---|:---|
| `Theme.durationSnap` | `[0.22, 1.0, 0.36, 1.0, 1.0, 1.0]` | `180 ms` | Context menu open, AppLauncher reveal, widget toggles |
| `Theme.durationFast` | `[0.22, 1.0, 0.36, 1.0, 1.0, 1.0]` | `90 ms` | Kinetic wave blast, hover feedback, micro-interactions |
| `Theme.durationExpand`| `[0.22, 1.0, 0.36, 1.0, 1.0, 1.0]` | `240 ms` | TopBar Dynamic Island expansion, HoverDock height rise |
| `Theme.durationCollapse`| `[0.55, 0.0, 1.0, 0.45, 1.0, 1.0]` | `160 ms` | Island collapse, dock hide, popup exit |
| Hover Micro-Bounce | `Easing.OutBack` | `90 ms` | Tile and icon hover scale pop (1.0 $\rightarrow$ 1.12) |

---

## Dependencies

### Core Engines (Required)
- [`quickshell`](https://quickshell.outfoxxed.me) (QtQuick/QML shell engine)
- `Hyprland` (Wayland compositor)
- `matugen` (`cargo install matugen`) — Material You palette generator
- `swww` (Wayland animated wallpaper daemon)

### Audio, Hardware & Peripherals (Recommended)
- `pipewire-pulse` / `pactl` (Volume slider & status)
- `brightnessctl` (Backlight slider & status)
- `playerctl` (Media player MPRIS controller)
- `networkmanager` / `nmcli` (Wi-Fi toggle)
- `nvidia-smi` (Nvidia GPU telemetry)

### Recommended Typography
- **JetBrains Mono Nerd Font** (Clock, system stats, glyphs, and fast scroller)
- **Inter** (UI labels, application titles, and subtitles)
- **Noto Serif CJK JP** (Japanese kanji accents & Wabi-Sabi calligraphy)

---

## Installation

### Automated Installation
Run the installer script (both `install.sh` and `installer.sh` are supported):

```bash
git clone https://github.com/yourname/komorebi.git ~/.local/src/komorebi
cd ~/.local/src/komorebi
chmod +x install.sh uninstall.sh
./install.sh
```

**Copy Mode** (for NixOS or immutable filesystems):
```bash
./install.sh --copy
```

The installer will:
1. Audit all critical and optional system dependencies.
2. Verify font cache availability.
3. Safely archive any pre-existing `~/.config/quickshell` directory to a timestamped backup.
4. Symlink (or copy) KOMOREBI to `~/.config/quickshell`.
5. Initialize wallpaper folders (`~/.config/komorebi/wallpapers` and `~/Pictures/Wallpapers`).
6. Append necessary autostarts, layer rules, and the `SUPER + Space` AppLauncher shortcut to `hyprland.conf`.

---

## Uninstallation

Run the safe uninstallation script:

```bash
cd ~/.local/src/komorebi
./uninstall.sh
```

The uninstaller will:
1. Prompt for confirmation.
2. Gracefully terminate running `quickshell` instances.
3. Remove `~/.config/quickshell` (unlinking symlink or deleting directory).
4. Discover and prompt to restore your latest `quickshell.bak.*` backup.
5. Clean out KOMOREBI autostarts, layer rules, and keybindings from `hyprland.conf`.

---

## Keybindings & Interaction Cheat Sheet

| Action | Trigger | Description |
|:---|:---|:---|
| **Toggle App Drawer** | `SUPER + Space` *(or `SUPER + D`)* | Opens the full-screen blurred ChromeOS/Android app drawer |
| **Close App Drawer** | `Escape` or click backdrop | Smoothly collapses the application launcher |
| **Fast Alphabet Scroll**| Drag along right edge | Pops up Letter Indicator and jumps GridView instantaneously |
| **Wallpaper Context Menu**| Right-click empty desktop | Snaps floating context menu to cursor coordinates |
| **TopBar Dashboard** | Hover top-center bezel | Expands dynamic island into Hardware Monitor, Media Player & Controls |
| **HoverDock** | Move mouse to bottom 2px bezel | Triggers kinetic wave fill and reveals pinned apps & workspaces |
| **Manual Shell Reload** | `hyprctl reload` or Context Menu | Reloads QuickShell without restarting the Wayland compositor |

---

*侘寂 (Wabi-Sabi) — Find beauty in imperfection, simplicity, and natural flow.*
