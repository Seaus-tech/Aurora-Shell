#!/bin/bash
# Aurora-Shell updater — backs up prefs, runs fresh install, restores account+PIN
BRANCH="${1:-dev}"
REPO_BASE="https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell"

# fetch real version from install.sh
VER=$(curl -sf "$REPO_BASE/$BRANCH/install.sh" 2>/dev/null | grep '^VER=' | head -1 | sed 's/VER="\(.*\)"/\1/')
[ -z "$VER" ] && VER="unknown"

DATA_DIR="$HOME/.aurora-shell_files"
BACKUP_DIR="/tmp/aurora-shell-preferences"

safe_lolcat() { command -v lolcat &>/dev/null && command lolcat || cat; }
notify() {
    local title="${1:-Aurora-Shell}" msg="${2:-}" sound="${3:-}"
    command -v terminal-notifier &>/dev/null || return
    (terminal-notifier -title "$title" -message "$msg" ${sound:+-sound "$sound"} &>/dev/null) &>/dev/null
}

echo "⬆  Aurora-Shell Updater v$VER" | safe_lolcat
echo ""

# --- STEP 1: MOVE ~/.aurora-shell_files to /tmp ---
if [ -d "$DATA_DIR" ]; then
    echo "📦 Backing up preferences to $BACKUP_DIR..." | safe_lolcat
    rm -rf "$BACKUP_DIR"
    cp -R "$DATA_DIR" "$BACKUP_DIR"
    echo "  ✅ Backed up"
else
    echo "  ⚠  No existing install found — fresh install"
fi

# --- STEP 2: RUN FRESH INSTALLER ---
echo ""
echo "⬇  Running fresh installer..." | safe_lolcat
echo ""
AURORA_UPDATE_MODE=1 bash <(curl -sf "$REPO_BASE/$BRANCH/install.sh") "$BRANCH"

# --- STEP 3: CLEANUP ---
echo ""
echo "🗑  Cleaning up..." | safe_lolcat
rm -rf "$BACKUP_DIR"
echo "  ✅ /tmp/aurora-shell-preferences removed"

echo ""
echo "✅ Aurora-Shell updated to v$VER" | safe_lolcat
notify "Aurora-Shell" "Updated to v$VER — account and PIN restored" "Glass"
echo "↺  Restart your terminal to apply the update"
