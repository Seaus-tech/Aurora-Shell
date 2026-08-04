#!/bin/bash
# Aurora-Shell Homebrew Installer
# Non-interactive — sets up files silently, wizard runs on first terminal open
VER="5.8.5"

OS="$(uname -s)"
case "$OS" in
    Darwin) PLATFORM="macos" ;;
    Linux)  PLATFORM="linux" ;;
    *)      PLATFORM="unknown" ;;
esac

DATA_DIR="$HOME/.aurora-shell_files"
THEME_FILE="$DATA_DIR/aurora-shell_theme"
CONFIG_FILE="$DATA_DIR/aurora-shell_settings"
BREW_INSTALL_FLAG="$DATA_DIR/.brew_first_launch"

mkdir -p "$DATA_DIR" "$DATA_DIR/bin"

# --- Install dependencies silently ---
if command -v brew >/dev/null 2>&1; then
    brew install figlet lolcat jq fzf terminal-notifier pygments 2>/dev/null
fi

# --- Write default config (no questions) ---
cat > "$CONFIG_FILE" << EOF
AURORA_VER="$VER"
AURORA_HDR_MODE="BLOCK"
AURORA_HDR_VAL="Aurora-Shell"
AURORA_FIGLET_FONT="slant"
AURORA_USER_BDAY=""
AURORA_ID="$USER"
EOF

# --- Mark as brew install needing wizard ---
touch "$BREW_INSTALL_FLAG"

# --- Copy assets from Homebrew prefix ---
BREW_SHARE="$(brew --prefix)/share/aurora-shell"
[ -f "$BREW_SHARE/brew-progress.py" ] && cp "$BREW_SHARE/brew-progress.py" "$DATA_DIR/"
[ -f "$BREW_SHARE/spinner.js" ]       && cp "$BREW_SHARE/spinner.js" "$DATA_DIR/"
[ -f "$BREW_SHARE/wx.js" ]            && cp "$BREW_SHARE/wx.js" "$DATA_DIR/"
if [ -f "$DATA_DIR/wx.js" ]; then
    printf '#!/bin/zsh\nnode "$HOME/.aurora-shell_files/wx.js" "$@"\n' > "$DATA_DIR/bin/wx"
    chmod +x "$DATA_DIR/bin/wx"
fi

# --- Copy shell.aurora binary ---
[ -f "$BREW_SHARE/shell.aurora" ] && cp "$BREW_SHARE/shell.aurora" "$DATA_DIR/bin/shell.aurora" && chmod +x "$DATA_DIR/bin/shell.aurora"

# --- Generate theme file (with first-launch wizard hook) ---
cat > "$THEME_FILE" << 'THEME_EOF'
#!/bin/zsh
source "$HOME/.aurora-shell_files/aurora-shell_settings"

safe_lolcat() { command -v lolcat &>/dev/null && command lolcat || cat; }

notify() {
    local title="${1:-Aurora-Shell}" msg="${2:-}" sound="${3:-}"
    if [[ "$(uname -s)" == "Darwin" ]] && command -v terminal-notifier &>/dev/null; then
        { terminal-notifier -title "$title" -message "$msg" ${sound:+-sound "$sound"} 2>/dev/null; } &>/dev/null &
        disown
    fi
}

# ── FIRST LAUNCH WIZARD ──────────────────────────────────────────────────────
# Runs once after a brew install, in the new terminal session
if [[ -f "$HOME/.aurora-shell_files/.brew_first_launch" ]]; then
    rm -f "$HOME/.aurora-shell_files/.brew_first_launch"
    echo ""
    echo "🎉 Welcome to Aurora-Shell (installed via Homebrew)" | safe_lolcat
    echo "   Let's set up your profile in just a few seconds."
    echo ""

    # Header style
    echo "🎨 Header style:"
    echo "   1) Mega-Block (default)  2) Slant  3) Doom  4) Banner  5) Big  6) Digital"
    printf "   Selection [1]: "
    read -r _choice
    case "$_choice" in
        2) _HDR_MODE="CUSTOM"; printf "✍️  Header Name: "; read -r _HDR_VAL; _FONT="slant" ;;
        3) _HDR_MODE="CUSTOM"; printf "✍️  Header Name: "; read -r _HDR_VAL; _FONT="doom" ;;
        4) _HDR_MODE="CUSTOM"; printf "✍️  Header Name: "; read -r _HDR_VAL; _FONT="banner" ;;
        5) _HDR_MODE="CUSTOM"; printf "✍️  Header Name: "; read -r _HDR_VAL; _FONT="big" ;;
        6) _HDR_MODE="CUSTOM"; printf "✍️  Header Name: "; read -r _HDR_VAL; _FONT="digital" ;;
        *) _HDR_MODE="BLOCK"; _HDR_VAL="Aurora-Shell"; _FONT="" ;;
    esac

    # PIN
    printf "🔐 Set Terminal PIN (Enter for none): "
    read -rs _pin; echo ""
    if [ -n "$_pin" ]; then
        security add-generic-password -a "$USER" -s "aurora-shell-pin" -w "$_pin" -U 2>/dev/null
        echo "🔒 PIN stored in Keychain"
    fi

    # Birthday + ID
    printf "🎂 Birthday (MMDD, Enter to skip): "; read -r _bday
    printf "🆔 Prompt ID (Enter to use $USER): "; read -r _pid
    _pid="${_pid:-$USER}"

    # Save config
    cat > "$HOME/.aurora-shell_files/aurora-shell_settings" << CFG_EOF
AURORA_VER="$AURORA_VER"
AURORA_HDR_MODE="$_HDR_MODE"
AURORA_HDR_VAL="${_HDR_VAL:-Aurora-Shell}"
AURORA_FIGLET_FONT="${_FONT:-slant}"
AURORA_USER_BDAY="${_bday:-}"
AURORA_ID="$_pid"
CFG_EOF

    # Account
    echo ""
    echo "🌐 Aurora Account (optional — syncs profile across machines)"
    printf "   Sign in? (y/n/create) [n]: "
    read -r _acct
    case "$_acct" in
        y|yes)
            printf "   👤 Username: "; read -r _uname
            printf "   🔐 Password: "; read -rs _pw; echo ""
            _hash=$(echo -n "$_pw" | shasum -a 256 | awk '{print $1}')
            _resp=$(curl -sf -X POST -H "Content-Type: application/json" \
                -d "{\"username\":\"$_uname\",\"password_hash\":\"$_hash\"}" \
                "https://aurora-accounts.yash-behera.workers.dev/accounts/login" 2>/dev/null)
            _err=$(echo "$_resp" | jq -r '.error // empty' 2>/dev/null)
            if [ -n "$_err" ]; then echo "   ❌ $_err"
            else
                _resp=$(echo "$_resp" | jq --arg h "$_hash" '. + {password_hash: $h}')
                echo "$_resp" > "$HOME/.aurora-shell_files/active_account.json"
                echo "   ✅ Signed in as $(echo "$_resp" | jq -r '.username')"
            fi
            ;;
        create)
            printf "   👤 New username: "; read -r _uname
            printf "   🔐 Password: "; read -rs _pw; echo ""
            printf "   🔐 Confirm:  "; read -rs _pw2; echo ""
            if [ "$_pw" != "$_pw2" ]; then echo "   ❌ Passwords don't match"
            else
                _hash=$(echo -n "$_pw" | shasum -a 256 | awk '{print $1}')
                _payload=$(jq -n --arg u "$_uname" --arg h "$_hash" \
                    '{username:$u,password_hash:$h,installed:"",plugins:[],linked:{},header:"Aurora-Shell",header_mode:"BLOCK"}')
                _resp=$(curl -sf -X POST -H "Content-Type: application/json" -d "$_payload" \
                    "https://aurora-accounts.yash-behera.workers.dev/accounts" 2>/dev/null)
                _err=$(echo "$_resp" | jq -r '.error // empty' 2>/dev/null)
                [ -n "$_err" ] && echo "   ❌ $_err" || echo "   ✅ Account created!"
            fi
            ;;
    esac

    source "$HOME/.aurora-shell_files/aurora-shell_settings"
    echo ""
    echo "✅ Aurora-Shell configured! Reloading..." | safe_lolcat
    sleep 1
    exec "$SHELL" -l
fi
# ─────────────────────────────────────────────────────────────────────────────

THEME_EOF

# Append the rest of the theme (Show-Aurora, shell.aurora, etc.) from main install
# by sourcing from the brew share directory
echo "source \"$(brew --prefix)/share/aurora-shell/aurora_theme.sh\" 2>/dev/null || true" >> "$THEME_FILE"

# --- Wire into .zshrc ---
grep -q "aurora-shell_theme" "$HOME/.zshrc" 2>/dev/null || echo "source $THEME_FILE" >> "$HOME/.zshrc"
grep -q "aurora-shell_files/bin" "$HOME/.zshrc" 2>/dev/null || echo 'export PATH="$HOME/.aurora-shell_files/bin:$PATH"' >> "$HOME/.zshrc"

echo ""
echo "✅ Aurora-Shell v$VER installed via Homebrew!"
echo "   Open a new terminal tab to complete setup."
echo ""
