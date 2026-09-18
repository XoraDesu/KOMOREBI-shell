#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# KOMOREBI — uninstall.sh / uninstaller.sh
# Safely uninstalls KOMOREBI from ~/.config/quickshell and cleans Hyprland rules.
#
# Usage:
#   chmod +x uninstall.sh && ./uninstall.sh
#
# What it does:
#   1. Prompts for confirmation before making any changes
#   2. Gracefully stops any active quickshell daemon processes
#   3. Removes ~/.config/quickshell (unlinks symlink or deletes copy)
#   4. Offers to restore the most recent backup (~/.config/quickshell.bak.*)
#   5. Optionally purges user caches and runtime data in ~/.config/komorebi
#   6. Cleans autostart commands, layer rules, and shortcuts from hyprland.conf
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Terminal ANSI Colors ──────────────────────────────────────────────────────
RESET="\033[0m"
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
DIM="\033[2m"

ok()   { echo -e "  ${GREEN}✓${RESET}  $*"; }
warn() { echo -e "  ${YELLOW}⚠${RESET}  $*"; }
err()  { echo -e "  ${RED}✗${RESET}  $*"; }
info() { echo -e "  ${CYAN}→${RESET}  $*"; }
step() { echo -e "\n${BOLD}── $* ${RESET}"; }

QUICKSHELL_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
KOMOREBI_DATA_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/komorebi"
HYPR_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"

# ── Banner ────────────────────────────────────────────────────────────────────
echo -e ""
echo -e "${CYAN}${BOLD}  KOMOREBI — Uninstaller${RESET}"
echo -e "${DIM}  Safe removal and backup restoration tool${RESET}"
echo -e ""

# ── 1. Confirmation ───────────────────────────────────────────────────────────
if [[ ! -e "$QUICKSHELL_DIR" && ! -L "$QUICKSHELL_DIR" ]]; then
    warn "No KOMOREBI installation found at ${QUICKSHELL_DIR}"
    echo ""
    read -rp "  Proceed with cleaning Hyprland configuration and caches anyway? [y/N] " proceed_anyway
    case "$proceed_anyway" in
        [yY]) : ;;
        *) info "Aborted."; exit 0 ;;
    esac
else
    read -rp "  Remove KOMOREBI configuration from ${QUICKSHELL_DIR}? [y/N] " confirm
    case "$confirm" in
        [yY]) : ;;
        *) info "Aborted."; exit 0 ;;
    esac
fi

# ── 2. Terminate Running Shell Instances ──────────────────────────────────────
step "1/4 Stopping active QuickShell processes"

if pgrep -x "quickshell" &>/dev/null; then
    info "Found active QuickShell instance. Terminating..."
    pkill -x "quickshell" || true
    sleep 0.5
    ok "QuickShell process stopped"
else
    ok "No active QuickShell process running"
fi

# ── 3. Remove Shell Configuration ─────────────────────────────────────────────
step "2/4 Removing configuration files"

if [[ -L "$QUICKSHELL_DIR" ]]; then
    rm "$QUICKSHELL_DIR"
    ok "Symlink removed: ${QUICKSHELL_DIR}"
elif [[ -d "$QUICKSHELL_DIR" ]]; then
    rm -rf "$QUICKSHELL_DIR"
    ok "Directory removed: ${QUICKSHELL_DIR}"
fi

# Optional data directory cleanup
if [[ -d "$KOMOREBI_DATA_DIR" ]]; then
    read -rp "  Delete KOMOREBI data and cache directory (${KOMOREBI_DATA_DIR})? [y/N] " purge_data
    case "$purge_data" in
        [yY])
            rm -rf "$KOMOREBI_DATA_DIR"
            ok "Data directory purged"
            ;;
        *) info "Preserved ${KOMOREBI_DATA_DIR}" ;;
    esac
fi

# ── 4. Restore Backups ────────────────────────────────────────────────────────
step "3/4 Checking for existing backups"

LATEST_BACKUP=$(ls -td "${CONFIG_DIR}"/quickshell.bak.* 2>/dev/null | head -1 || true)
if [[ -n "$LATEST_BACKUP" ]]; then
    info "Discovered backup archive: ${LATEST_BACKUP}"
    read -rp "  Restore this backup to ${QUICKSHELL_DIR}? [y/N] " restore
    case "$restore" in
        [yY])
            mv "$LATEST_BACKUP" "$QUICKSHELL_DIR"
            ok "Restored backup to ${QUICKSHELL_DIR}"
            ;;
        *) info "Backup left intact at ${LATEST_BACKUP}" ;;
    esac
else
    info "No quickshell.bak.* archives found — skipping restore"
fi

# ── 5. Clean Hyprland Configuration ───────────────────────────────────────────
step "4/4 Cleaning Hyprland configuration"

if [[ -f "$HYPR_CONF" ]]; then
    # Clean autostart and comments
    sed -i '/# ── KOMOREBI Desktop Shell ──/d' "$HYPR_CONF"
    sed -i '/# KOMOREBI — QuickShell autostart/d' "$HYPR_CONF"
    sed -i '/exec-once = quickshell/d' "$HYPR_CONF"

    # Clean global shortcut bindings
    sed -i '/quickshell:appLauncher/d' "$HYPR_CONF"

    # Clean layer rules
    sed -i '/layerrule = blur, quickshell/d' "$HYPR_CONF"
    sed -i '/layerrule = ignorezero, quickshell/d' "$HYPR_CONF"
    sed -i '/layerrule = ignorealpha 0.5, quickshell/d' "$HYPR_CONF"

    ok "Removed KOMOREBI autostarts, layer rules, and keybindings from ${HYPR_CONF}"
else
    warn "hyprland.conf not found at ${HYPR_CONF} — nothing to clean"
fi

echo ""
echo -e "${GREEN}${BOLD}  ✓ KOMOREBI has been cleanly uninstalled.${RESET}"
echo ""
