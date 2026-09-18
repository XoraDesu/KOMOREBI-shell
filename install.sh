#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# KOMOREBI — install.sh / installer.sh
# Installs the KOMOREBI QuickShell desktop environment for Hyprland.
#
# Usage:
#   chmod +x install.sh && ./install.sh [--copy]
#
# Flags:
#   --copy   Copy files instead of symlinking (recommended for immutable filesystems / NixOS)
#   --help   Show usage information
#
# What it does:
#   1. Audits core runtime & audio/hardware dependencies
#   2. Verifies required typography (JetBrainsMono Nerd Font, Inter, Noto Serif CJK)
#   3. Safely backs up existing ~/.config/quickshell configuration
#   4. Deploys KOMOREBI via symlink (or recursive copy)
#   5. Initializes wallpaper and user cache directories
#   6. Configures Hyprland autostart & global shortcut keybindings
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Terminal ANSI Colors ──────────────────────────────────────────────────────
RESET="\033[0m"
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
MAGENTA="\033[35m"
DIM="\033[2m"

# ── ASCII Art Banner ──────────────────────────────────────────────────────────
echo -e ""
echo -e "${CYAN}${BOLD}  ██╗  ██╗ ██████╗ ███╗   ███╗ ██████╗ ██████╗ ███████╗██████╗ ██╗${RESET}"
echo -e "${CYAN}${BOLD}  ██║ ██╔╝██╔═══██╗████╗ ████║██╔═══██╗██╔══██╗██╔════╝██╔══██╗██║${RESET}"
echo -e "${CYAN}${BOLD}  █████╔╝ ██║   ██║██╔████╔██║██║   ██║██████╔╝█████╗  ██████╔╝██║${RESET}"
echo -e "${CYAN}${BOLD}  ██╔═██╗ ██║   ██║██║╚██╔╝██║██║   ██║██╔══██╗██╔══╝  ██╔══██╗██║${RESET}"
echo -e "${CYAN}${BOLD}  ██║  ██╗╚██████╔╝██║ ╚═╝ ██║╚██████╔╝██║  ██║███████╗██████╔╝██║${RESET}"
echo -e "${CYAN}${BOLD}  ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═════╝ ╚═╝${RESET}"
echo -e ""
echo -e "${DIM}  侘寂 (Wabi-Sabi) · Cyberpunk Motion · Dynamic Material You Shell for Hyprland${RESET}"
echo -e ""

# ── Argument Parsing ──────────────────────────────────────────────────────────
USE_COPY=false
for arg in "$@"; do
    case $arg in
        --copy)  USE_COPY=true ;;
        --help)
            echo "Usage: $0 [--copy]"
            echo "  --copy  Copy files instead of creating a symlink in ~/.config/quickshell"
            exit 0
            ;;
        *) echo -e "${RED}Unknown flag: $arg${RESET}"; exit 1 ;;
    esac
done

# ── Output Helpers ────────────────────────────────────────────────────────────
ok()   { echo -e "  ${GREEN}✓${RESET}  $*"; }
warn() { echo -e "  ${YELLOW}⚠${RESET}  $*"; }
err()  { echo -e "  ${RED}✗${RESET}  $*"; }
info() { echo -e "  ${CYAN}→${RESET}  $*"; }
step() { echo -e "\n${BOLD}── $* ${RESET}"; }

# ── Path Resolution ───────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUICKSHELL_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
BACKUP_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell.bak.$(date +%Y%m%d_%H%M%S)"
KOMOREBI_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/komorebi"
WALLPAPERS_DIR="${KOMOREBI_CONFIG_DIR}/wallpapers"
USER_WALLPAPERS="${HOME}/Pictures/Wallpapers"
FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
HYPR_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"

# ── 1. Dependency Audit ───────────────────────────────────────────────────────
step "1/6 Auditing system dependencies"

CRITICAL_DEPS=()
OPTIONAL_DEPS=()

check_critical() {
    if command -v "$1" &>/dev/null; then
        ok "$1 ${DIM}(core engine)${RESET}"
    else
        err "$1 ${BOLD}(required but not found)${RESET}"
        CRITICAL_DEPS+=("$1")
    fi
}

check_optional() {
    local cmd="$1"
    local desc="$2"
    if command -v "$cmd" &>/dev/null; then
        ok "$cmd ${DIM}($desc)${RESET}"
    else
        warn "$cmd ${DIM}($desc — recommended)${RESET}"
        OPTIONAL_DEPS+=("$cmd")
    fi
}

# Core runtime engines
check_critical quickshell
check_critical Hyprland
check_critical matugen
check_critical swww

# Audio, hardware, and peripheral utilities
check_optional pactl         "PipeWire / PulseAudio volume control"
check_optional brightnessctl "Display backlight control"
check_optional playerctl     "MPRIS media playback controller"
check_optional nmcli         "NetworkManager Wi-Fi control"
check_optional nvidia-smi    "Nvidia GPU stats monitor"

if [[ ${#CRITICAL_DEPS[@]} -gt 0 ]]; then
    echo ""
    err "Critical missing dependencies: ${CRITICAL_DEPS[*]}"
    echo -e "  ${DIM}Install quickshell (quickshell.outfoxxed.me), matugen (cargo install matugen), and swww.${RESET}"
    echo -e "  ${YELLOW}Installation will proceed, but KOMOREBI cannot run until these are present.${RESET}"
fi

# ── 2. Typography Verification ────────────────────────────────────────────────
step "2/6 Verifying typography & font cache"

FONTS_NEEDED=(
    "JetBrainsMono Nerd Font"
    "Inter"
    "Noto Serif CJK JP"
)

mkdir -p "$FONT_DIR"

for font in "${FONTS_NEEDED[@]}"; do
    if fc-list : family | grep -qi "$font"; then
        ok "Font discovered: $font"
    else
        warn "Font not detected in system cache: $font"
        info "Download from https://www.nerdfonts.com or Google Fonts."
    fi
done

# ── 3. Workspace & Directory Preparation ──────────────────────────────────────
step "3/6 Preparing directory architecture"

mkdir -p "$KOMOREBI_CONFIG_DIR"
mkdir -p "$WALLPAPERS_DIR"
mkdir -p "$USER_WALLPAPERS"
ok "Configuration root initialized: ${KOMOREBI_CONFIG_DIR}"
ok "Wallpaper library directories ready"

# ── 4. Deploying KOMOREBI Configuration ───────────────────────────────────────
step "4/6 Deploying KOMOREBI configuration to ~/.config/quickshell"

if [[ -e "$QUICKSHELL_DIR" || -L "$QUICKSHELL_DIR" ]]; then
    warn "Existing configuration found at ${QUICKSHELL_DIR}"
    info "Preserving current configuration to ${BACKUP_DIR}"
    mv "$QUICKSHELL_DIR" "$BACKUP_DIR"
    ok "Backup safely archived"
else
    ok "Clean target location: no existing configuration"
fi

if [[ "$USE_COPY" == true ]]; then
    info "Deployment mode: COPY"
    cp -r "$SCRIPT_DIR" "$QUICKSHELL_DIR"
    ok "Copied KOMOREBI repository tree to ${QUICKSHELL_DIR}"
else
    info "Deployment mode: SYMLINK (live development)"
    ln -sf "$SCRIPT_DIR" "$QUICKSHELL_DIR"
    ok "Created symbolic link: ${QUICKSHELL_DIR} → ${SCRIPT_DIR}"
fi

# ── 5. Hyprland Integration & Global Shortcuts ────────────────────────────────
step "5/6 Integrating Hyprland configuration"

if [[ -f "$HYPR_CONF" ]]; then
    # 1. Autostart quickshell
    if grep -q "exec-once.*quickshell" "$HYPR_CONF"; then
        ok "quickshell autostart entry already present"
    else
        echo "" >> "$HYPR_CONF"
        echo "# ── KOMOREBI Desktop Shell ──" >> "$HYPR_CONF"
        echo "exec-once = quickshell" >> "$HYPR_CONF"
        ok "Appended 'exec-once = quickshell' to ${HYPR_CONF}"
    fi

    # 2. Autostart swww-daemon
    if grep -q "exec-once.*swww-daemon" "$HYPR_CONF"; then
        ok "swww-daemon autostart already present"
    else
        echo "exec-once = swww-daemon" >> "$HYPR_CONF"
        ok "Appended 'exec-once = swww-daemon' to ${HYPR_CONF}"
    fi

    # 3. Global Shortcut for AppLauncher (Super + Space)
    if grep -q "quickshell:appLauncher" "$HYPR_CONF"; then
        ok "AppLauncher global keybinding already mapped"
    else
        echo "bind = SUPER, Space, global, quickshell:appLauncher" >> "$HYPR_CONF"
        ok "Bound 'SUPER + Space' to quickshell:appLauncher"
    fi

    # 4. Layer rules for optimal blur & input
    if grep -q "layerrule = blur, quickshell" "$HYPR_CONF"; then
        ok "quickshell layer blur rules already defined"
    else
        echo "layerrule = blur, quickshell" >> "$HYPR_CONF"
        echo "layerrule = ignorezero, quickshell" >> "$HYPR_CONF"
        echo "layerrule = ignorealpha 0.5, quickshell" >> "$HYPR_CONF"
        ok "Appended layer rules (blur, ignorezero, ignorealpha)"
    fi
else
    warn "hyprland.conf not located at ${HYPR_CONF}"
    info "Review config/hyprland.conf.komorebi and paste into your Hyprland configuration manually."
fi

# ── 6. Verification & Final Summary ───────────────────────────────────────────
step "6/6 Installation Complete"

echo ""
echo -e "${GREEN}${BOLD}  ✓ KOMOREBI has been successfully installed!${RESET}"
echo ""
echo -e "${CYAN}${BOLD}  Quick Start Guide:${RESET}"
echo -e "  • ${BOLD}TopBar Dynamic Island${RESET}    : Hover over top-center bezel to expand dashboard."
echo -e "  • ${BOLD}HoverDock${RESET}                : Hover cursor on the bottom 2px bezel to trigger wave reveal."
echo -e "  • ${BOLD}Wallpaper Context Menu${RESET}   : Right-click on any empty desktop area."
echo -e "  • ${BOLD}Fullscreen App Drawer${RESET}    : Press ${BOLD}SUPER + Space${RESET}."
echo -e "  • ${BOLD}Manual Shell Start${RESET}       : Run ${CYAN}quickshell${RESET} in terminal."
echo ""
echo -e "  ${DIM}Configuration path: ${QUICKSHELL_DIR}${RESET}"
echo ""
