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
bash <(curl -sf "$REPO_BASE/$BRANCH/install.sh") "$BRANCH"

# --- STEP 3: RESTORE ACCOUNT + PIN (skip wizard data) ---
echo ""
echo "🔁 Restoring account and PIN..." | safe_lolcat

if [ -d "$BACKUP_DIR" ]; then
    # restore account
    if [ -f "$BACKUP_DIR/active_account.json" ]; then
        cp "$BACKUP_DIR/active_account.json" "$DATA_DIR/active_account.json"
        _uid=$(jq -r '.username // empty' "$DATA_DIR/active_account.json" 2>/dev/null)
        [ -n "$_uid" ] && echo "  ✅ Account restored: $_uid"
    fi

    # restore PIN
    if [ -f "$BACKUP_DIR/aurora-pin.enc" ]; then
        cp "$BACKUP_DIR/aurora-pin.enc" "$DATA_DIR/aurora-pin.enc"
        echo "  ✅ PIN restored"
    fi

    # restore settings (header, birthday, prompt ID, etc.)
    if [ -f "$BACKUP_DIR/aurora-shell_settings" ]; then
        cp "$BACKUP_DIR/aurora-shell_settings" "$DATA_DIR/aurora-shell_settings"
        # update version to new one
        sed -i '' "s/^AURORA_VER=.*/AURORA_VER=\"$VER\"/" "$DATA_DIR/aurora-shell_settings" 2>/dev/null
        echo "  ✅ Settings restored (header, birthday, prompt ID)"
    fi

    # restore login history
    if [ -f "$BACKUP_DIR/login_history.log" ]; then
        cp "$BACKUP_DIR/login_history.log" "$DATA_DIR/login_history.log"
        echo "  ✅ Login history restored"
    fi

    # restore custom packages
    if [ -f "$BACKUP_DIR/packages.json" ]; then
        cp "$BACKUP_DIR/packages.json" "$DATA_DIR/packages.json"
        echo "  ✅ Packages restored"
    fi

    # restore last_auth
    if [ -f "$BACKUP_DIR/.last_auth" ]; then
        cp "$BACKUP_DIR/.last_auth" "$DATA_DIR/.last_auth"
    fi

    rm -rf "$BACKUP_DIR"
    echo "  🗑  Cleaned up backup"
fi

echo ""
echo "✅ Aurora-Shell updated to v$VER" | safe_lolcat
notify "Aurora-Shell" "Updated to v$VER — account and PIN restored" "Glass"
echo "↺  Restart your terminal to apply the update"
