#!/bin/bash
# Aurora-Shell updater — replaces theme/scripts only, preserves all user data
VER="5.7.2"
DATA_DIR="$HOME/.aurora-shell_files"
THEME_FILE="$DATA_DIR/aurora-shell_theme"
GIT_CLONE="https://github.com/Seaus-tech/Aurora-Shell.git"
REPO_BASE="https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell"
mkdir -p "$DATA_DIR/bin" "$DATA_DIR/casks"

safe_lolcat() { command -v lolcat &>/dev/null && command lolcat || cat; }
notify() {
    local title="${1:-Aurora-Shell}" msg="${2:-}" sound="${3:-}"
    command -v terminal-notifier &>/dev/null || return
    (terminal-notifier -title "$title" -message "$msg" ${sound:+-sound "$sound"} &>/dev/null) &>/dev/null
}

echo "⬆  Aurora-Shell Updater v$VER" | safe_lolcat
echo ""

# --- PRESERVE USER DATA ---
SETTINGS_BAK=""
ACCOUNT_BAK=""
PIN_BAK=""
PACKAGES_BAK=""
LAST_AUTH_BAK=""
LOGIN_LOG_BAK=""

[ -f "$DATA_DIR/aurora-shell_settings" ]  && SETTINGS_BAK=$(cat "$DATA_DIR/aurora-shell_settings")
[ -f "$DATA_DIR/active_account.json" ]    && ACCOUNT_BAK=$(cat "$DATA_DIR/active_account.json")
[ -f "$DATA_DIR/aurora-pin.enc" ]         && PIN_BAK=$(cat "$DATA_DIR/aurora-pin.enc")
[ -f "$DATA_DIR/packages.json" ]          && PACKAGES_BAK=$(cat "$DATA_DIR/packages.json")
[ -f "$DATA_DIR/.last_auth" ]             && LAST_AUTH_BAK=$(cat "$DATA_DIR/.last_auth")
[ -f "$DATA_DIR/login_history.log" ]      && LOGIN_LOG_BAK=$(cat "$DATA_DIR/login_history.log")

echo "💾 User data backed up" | safe_lolcat

# --- UPDATE SCRIPTS FROM REPO ---
echo "⬇  Downloading latest scripts..." | safe_lolcat

BRANCH="${1:-dev}"

# update wx.js and ensure wrapper exists
curl -sf "$REPO_BASE/$BRANCH/wx.js" -o "$DATA_DIR/wx.js" 2>/dev/null && echo "  ✅ wx.js" || echo "  ⚠  wx.js unchanged"
[ -f "$DATA_DIR/wx.js" ] && printf '#!/bin/zsh\nnode "$HOME/.aurora-shell_files/wx.js" "$@"\n' > "$DATA_DIR/bin/wx" && chmod +x "$DATA_DIR/bin/wx"

# update brew-progress.py and spinner.js
curl -sf "$REPO_BASE/$BRANCH/brew-progress.py" -o "$DATA_DIR/brew-progress.py" 2>/dev/null && echo "  ✅ brew-progress.py" || true
curl -sf "$REPO_BASE/$BRANCH/spinner.js"       -o "$DATA_DIR/spinner.js"       2>/dev/null && echo "  ✅ spinner.js"       || true

# update cli-packages.json
curl -sf "$REPO_BASE/$BRANCH/cli-packages.json" -o "$DATA_DIR/cli-packages.json" 2>/dev/null && echo "  ✅ cli-packages.json" || echo "  ⚠  cli-packages.json unchanged"

# --- REGENERATE THEME (preserves settings) ---
echo "🎨 Regenerating theme..." | safe_lolcat
curl -sf "$REPO_BASE/$BRANCH/install.sh" -o "/tmp/aurora-install-latest.sh" 2>/dev/null
if [ -f "/tmp/aurora-install-latest.sh" ]; then
    # extract just the generate_theme function and run it
    # source the latest installer functions without executing the main body
    bash -c "
        DATA_DIR='$DATA_DIR'
        THEME_FILE='$THEME_FILE'
        VER='$VER'
        $(grep -A 500 '^generate_theme()' /tmp/aurora-install-latest.sh | head -600)
        generate_theme
    " 2>/dev/null
    rm -f /tmp/aurora-install-latest.sh
    echo "  ✅ Theme regenerated"
fi

# --- RESTORE USER DATA ---
echo "🔁 Restoring user data..." | safe_lolcat
[ -n "$SETTINGS_BAK" ]  && echo "$SETTINGS_BAK"  > "$DATA_DIR/aurora-shell_settings"
[ -n "$ACCOUNT_BAK" ]   && echo "$ACCOUNT_BAK"   > "$DATA_DIR/active_account.json"
[ -n "$PIN_BAK" ]       && echo "$PIN_BAK"        > "$DATA_DIR/aurora-pin.enc"
[ -n "$PACKAGES_BAK" ]  && echo "$PACKAGES_BAK"  > "$DATA_DIR/packages.json"
[ -n "$LAST_AUTH_BAK" ] && echo "$LAST_AUTH_BAK" > "$DATA_DIR/.last_auth"
[ -n "$LOGIN_LOG_BAK" ] && echo "$LOGIN_LOG_BAK" > "$DATA_DIR/login_history.log"

# update version in settings
sed -i '' "s/^AURORA_VER=.*/AURORA_VER=\"$VER\"/" "$DATA_DIR/aurora-shell_settings" 2>/dev/null

echo ""
echo "✅ Aurora-Shell updated to v$VER — all settings preserved." | safe_lolcat
notify "Aurora-Shell" "Updated to v$VER" "Glass"
echo "↺  Restart your terminal or run: source $THEME_FILE"
