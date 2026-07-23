#!/bin/bash
# --- Aurora-Shell Installer ---
VER="5.8.3"
SHELL_VER="--- Aurora-Shell v$VER ---"

# --- DETECT OS ---
OS="$(uname -s)"
case "$OS" in
    Darwin)  PLATFORM="macos" ;;
    Linux)   PLATFORM="linux" ;;
    *)       PLATFORM="unknown" ;;
esac

# --- PATH CONFIGURATION ---
DATA_DIR="$HOME/.aurora-shell_files"
OLD_SHELL="$DATA_DIR"
THEME_FILE="$DATA_DIR/aurora-shell_theme"
CONFIG_FILE="$DATA_DIR/aurora-shell_settings"
REPO_BASE="https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell"
GIT_CLONE="https://github.com/Seaus-tech/Aurora-Shell.git"
CLI_PACKAGES_FILE="$DATA_DIR/cli-packages.json"

# -- HELPER: SAFE LOLCAT --
safe_lolcat() {
    if command -v lolcat &> /dev/null; then
        command lolcat "$@"
    else
        cat
    fi
}

# -- HELPER: SED --
safe_sed() {
    if [ "$PLATFORM" = "MacOS" ]; then
        /usr/bin/sed -i '' "$@"
    else
        /usr/bin/sed -i "$@"
    fi
}

echo "Running as $USER..." | safe_lolcat

# Prepare directory
mkdir -p "$DATA_DIR"
safe_sed '/aurora-shell_files/d' ~/.zshrc 2>/dev/null

# --- SYNC ENVIRONMENT ---
sync_env() {
    echo -ne "\033[1;33m🛠️  Syncing Environment... \033[0m"
    if ! command -v brew >/dev/null 2>&1; then
        if [ "$PLATFORM" = "macos" ]; then
            [ "${AURORA_UPDATE_MODE:-}" = "1" ] && echo "⚠ brew not found — skipping" && return
            echo "⬇ Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            if [ -d "/opt/homebrew/bin" ]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            elif [ -d "/usr/local/bin" ]; then
                eval "$(/usr/local/bin/brew shellenv)"
            fi
        else
             echo "⚠ brew not found. Please install it manually."
        fi
    fi
    echo -e "\033[1;32mDONE\033[0m"
}

# --- INSTALL COMPONENTS ---
install_com() {
    echo -ne "\033[1;33m📥 Downloading extensions... \033[0m"
    if command -v brew >/dev/null 2>&1; then
        brew install figlet lolcat pygments terminal-notifier jq fzf 2>/dev/null
    elif [ "$PLATFORM" = "linux" ]; then
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y figlet lolcat python3-pygments jq fzf
        fi
    fi
    echo -e "\033[1;32mREADY\033[0m"
}

# --- DEV TOOLS BOOTSTRAP (BASH 3.2 SAFE) ---
dev_tools_bootstrap() {
    echo -e "\n\033[1;36m--- DEV TOOLS SETUP ---\033[0m"

    tools=(
        "Git:git"
        "GitHub_CLI:gh"
        "NodeJS:node"
        "Python3:python@3.14"
        "Java:openjdk"
        "Go:go"
        "Rust:rust"
        "Docker:docker-desktop"
        "AWS_CLI:awscli"
        "Azure_CLI:azure-cli"
    )

    for entry in "${tools[@]}"; do
        name="${entry%%:*}"
        formula="${entry##*:}"

        printf "Install %s? (y/n): " "$name"
        read ans
        if [ "$ans" = "y" ]; then
            case "$name" in
                "Git")
                    if command -v git >/dev/null 2>&1; then
                        echo "✔ Git already installed: $(git --version)"
                    else
                        echo "⬇ Installing Git via Xcode Command Line Tools..."
                        xcode-select --install 2>/dev/null || open "/System/Library/CoreServices/Install Command Line Developer Tools.app" 2>/dev/null || true
                    fi
                    ;;
                "Docker")
                    if command -v sudo >/dev/null 2>&1; then
                        brew install --cask docker-desktop
                    else
                        echo "Skipping Docker: sudo not available for this user."
                    fi
                    ;;
                *)
                    brew install "$formula"
                    ;;
            esac
        fi
    done
}

# --- CONFIG WIZARD ---
run_wizard() {
    echo -e "\n\033[1;32m--- AURORA CONFIGURATION WIZARD ---\033[0m"
    
    # Load existing config if available
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

    # in update mode — auto-restore from backup, no prompts
    if [ "${AURORA_UPDATE_MODE:-}" = "1" ] && [ -f "/tmp/aurora-shell-preferences/aurora-shell_settings" ]; then
        source "/tmp/aurora-shell-preferences/aurora-shell_settings"
        HDR_MODE="${AURORA_HDR_MODE:-BLOCK}"
        HDR_VAL="${AURORA_HDR_VAL:-Aurora-Shell}"
        FIGLET_FONT="${AURORA_FIGLET_FONT:-slant}"
        BDAY="${AURORA_USER_BDAY:-}"
        P_ID="${AURORA_ID:-}"
        echo "⏭  Auto-restoring wizard settings from backup..." | safe_lolcat
        cat << EOF > "$CONFIG_FILE"
AURORA_VER="$VER"
AURORA_HDR_MODE="$HDR_MODE"
AURORA_HDR_VAL="$HDR_VAL"
AURORA_FIGLET_FONT="${FIGLET_FONT:-slant}"
AURORA_USER_BDAY="$BDAY"
AURORA_ID="$P_ID"
EOF
        # restore account sign-in silently
        if [ -f "/tmp/aurora-shell-preferences/active_account.json" ]; then
            cp "/tmp/aurora-shell-preferences/active_account.json" "$DATA_DIR/active_account.json"
            _uid=$(jq -r '.username // empty' "$DATA_DIR/active_account.json" 2>/dev/null)
            [ -n "$_uid" ] && safe_sed "s/^AURORA_ID=.*/AURORA_ID=\"$_uid\"/" "$CONFIG_FILE" 2>/dev/null
            echo "  ✅ Account restored: $_uid" | safe_lolcat
        fi
        return
    fi
    
    read -s -p "🔐 Set Terminal PIN (Enter for none): " NEW_PW < /dev/tty; echo ""
    if [ "${AURORA_UPDATE_MODE:-}" = "1" ]; then
        # keep existing keychain PIN silently
        echo "🔒 PIN kept from previous install"
    elif [ -n "$NEW_PW" ]; then
        security add-generic-password -a "$USER" -s "aurora-shell-pin" -w "$NEW_PW" -U 2>/dev/null
        echo "🔒 PIN stored securely in Keychain"
    fi
    echo "🎨 Header style:"
    echo "   1) Mega-Block  2) Slant  3) Doom  4) Banner  5) Big  6) Digital  7) Custom text"
    read -p "Selection: " choice < /dev/tty
    case "$choice" in
        2) HDR_MODE="CUSTOM"; read -p "✍️  Header Name: " HDR_VAL < /dev/tty; FIGLET_FONT="slant" ;;
        3) HDR_MODE="CUSTOM"; read -p "✍️  Header Name: " HDR_VAL < /dev/tty; FIGLET_FONT="doom" ;;
        4) HDR_MODE="CUSTOM"; read -p "✍️  Header Name: " HDR_VAL < /dev/tty; FIGLET_FONT="banner" ;;
        5) HDR_MODE="CUSTOM"; read -p "✍️  Header Name: " HDR_VAL < /dev/tty; FIGLET_FONT="big" ;;
        6) HDR_MODE="CUSTOM"; read -p "✍️  Header Name: " HDR_VAL < /dev/tty; FIGLET_FONT="digital" ;;
        7) HDR_MODE="CUSTOM"; read -p "✍️  Header Name: " HDR_VAL < /dev/tty; FIGLET_FONT="slant" ;;
        *) HDR_MODE="BLOCK"; HDR_VAL="Aurora-Shell"; FIGLET_FONT="" ;;
    esac

    printf "🎂 Birthday (MMDD): "
    read BDAY
    printf "🆔 Prompt ID: "
    read P_ID

    cat << EOF > "$CONFIG_FILE"
AURORA_VER="$VER"
AURORA_HDR_MODE="$HDR_MODE"
AURORA_HDR_VAL="$HDR_VAL"
AURORA_FIGLET_FONT="${FIGLET_FONT:-slant}"
AURORA_USER_BDAY="${BDAY:-$AURORA_USER_BDAY}"
AURORA_ID="${P_ID:-$AURORA_ID}"
EOF

    # --- ACCOUNT SIGN-IN ---
    echo ""
    echo "🌐 Aurora Account (optional — syncs your profile across machines)"
    printf "   Sign in? (y/n/create): "
    read acct_choice < /dev/tty
    case "$acct_choice" in
        y|yes)
            printf "   👤 Username: "; read -r _uname < /dev/tty
            printf "   🔐 Password: "; read -rs _pw < /dev/tty; echo ""
            _hash=$(echo -n "$_pw" | shasum -a 256 | awk '{print $1}')
            _resp=$(curl -sf -X POST -H "Content-Type: application/json" \
                -d "{\"username\":\"$_uname\",\"password_hash\":\"$_hash\"}" \
                "https://aurora-accounts.yash-behera.workers.dev/accounts/login" 2>/dev/null)
            _err=$(echo "$_resp" | jq -r '.error // empty' 2>/dev/null)
            if [ -n "$_err" ]; then
                echo "   ❌ $_err"
            else
                echo "$_resp" > "$DATA_DIR/active_account.json"
                _uid=$(echo "$_resp" | jq -r '.username')
                safe_sed "s/^AURORA_ID=.*/AURORA_ID=\"$_uid\"/" "$CONFIG_FILE" 2>/dev/null
                echo "   ✅ Signed in as $_uid"
            fi
            ;;
        create)
            printf "   👤 New username: "; read -r _uname < /dev/tty
            printf "   🔐 Password: "; read -rs _pw < /dev/tty; echo ""
            printf "   🔐 Confirm:  "; read -rs _pw2 < /dev/tty; echo ""
            if [ "$_pw" != "$_pw2" ]; then
                echo "   ❌ Passwords don't match — skipping"
            else
                _hash=$(echo -n "$_pw" | shasum -a 256 | awk '{print $1}')
                _payload=$(jq -n --arg u "$_uname" --arg h "$_hash" \
                    '{username:$u,password_hash:$h,installed:"",plugins:[],linked:{},header:"Aurora-Shell",header_mode:"BLOCK"}')
                _resp=$(curl -sf -X POST -H "Content-Type: application/json" \
                    -d "$_payload" \
                    "https://aurora-accounts.yash-behera.workers.dev/accounts" 2>/dev/null)
                _err=$(echo "$_resp" | jq -r '.error // empty' 2>/dev/null)
                [ -n "$_err" ] && echo "   ❌ $_err" || echo "   ✅ Account created! Login with: shell.aurora --account --login"
            fi
            ;;
    esac
}

# --- THEME ENGINE ---
generate_theme() {
cat << 'EOF' > "$THEME_FILE"
#!/bin/zsh
# Generated by Aurora-Shell Installer
source "$HOME/.aurora-shell_files/aurora-shell_settings"

# -- HELPER: SAFE LOLCAT --
safe_lolcat() {
    if command -v lolcat &> /dev/null; then command lolcat; else cat; fi
}

# -- HELPER: NOTIFY --
notify() {
    local title="${1:-Aurora-Shell}"
    local msg="${2:-}"
    local sound="${3:-}"
    if [[ "$(uname -s)" == "Darwin" ]] && command -v terminal-notifier &>/dev/null; then
        { terminal-notifier -title "$title" -message "$msg" ${sound:+-sound "$sound"} 2>/dev/null; } &>/dev/null &
        disown
    elif command -v notify-send &>/dev/null; then
        notify-send "$title" "$msg"
    fi
}
install_xcode_if_needed() {
    # Only attempt on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        return
    fi

    # If Xcode.app exists, do nothing
    if [ -d "/Applications/Xcode.app" ] || [ -d "$HOME/Applications/Xcode.app" ]; then
        echo "✔ Xcode found."
        return
    fi

    echo "⚠ Xcode not found — attempting installation...(press Ctrl+C to cancel)"

    # Ensure Homebrew exists
    if ! command -v brew &> /dev/null; then
        echo "⚠ Homebrew missing — installing Homebrew...(press Ctrl+C to cancel)"
        mkdir -p "$HOME/.brew"
        curl -L https://github.com/Homebrew/brew/tarball/master \
            | tar xz --strip 1 -C "$HOME/.brew"
        export PATH="$HOME/.brew/bin:$PATH"
    fi

    # Try installing full Xcode via cask (requires App Store download)
    if brew info --cask xcode >/dev/null 2>&1; then
        echo "⬇ Installing Xcode via App store..."
        open https://apps.apple.com/us/app/xcode/id497799835?mt=12 || true
    fi

    # Fallback: ensure Command Line Tools are installed
    if ! xcode-select -p >/dev/null 2>&1; then
        echo "⬇ Installing Xcode Command Line Tools..."
        xcode-select --install || true
    fi
}

authenticate_user() {
    local is_manual=0
    local target_pw
    if [[ "$1" == "MANUAL" ]]; then
        is_manual=1
        target_pw=$(security find-generic-password -a "$USER" -s "aurora-shell-pin" -w 2>/dev/null | tr -d '\n\r')
    else
        target_pw="${1:-$(security find-generic-password -a "$USER" -s "aurora-shell-pin" -w 2>/dev/null | tr -d '\n\r')}"
    fi
    [[ -z "$target_pw" ]] && return
    local lock_file="$HOME/.aurora-shell_files/.last_auth"
    if [[ $is_manual -eq 0 ]]; then
        if [[ -f "$lock_file" ]]; then
            local last=$(cat "$lock_file" 2>/dev/null)
            local now=$(date +%s)
            [[ $(( now - last )) -lt 600 ]] && return
        fi
    fi
    clear
    echo "           .---.
          /     \\
         | (00)  |  SYSTEM ENCRYPTED
          \\  ^  /
           '---'
     ╔════════════════════════════════════════╗
     ║     AURORA-SHELL SECURITY TERMINAL     ║
     ╚════════════════════════════════════════╝" | safe_lolcat
    local attempts=0
    while true; do
        echo -ne "[AUTH] Key: " | safe_lolcat
        if ! read -s in_pw; then echo ""; echo "DENIED"; continue; fi
        in_pw=$(echo "$in_pw" | tr -d '\n\r')
        echo ""
        if [[ "$in_pw" == "$target_pw" ]]; then
            date +%s > "$lock_file"
            echo "$(date '+%Y-%m-%d %H:%M:%S') — login OK" >> "$HOME/.aurora-shell_files/login_history.log"
            notify "Aurora-Shell" "✅ Logged in as ${AURORA_ID:-$USER}" "default"
            if [[ ! -o interactive ]]; then trap INT; trap TSTP; trap QUIT; fi
            clear
            break
        else
            (( attempts++ ))
            echo "DENIED ($attempts failed attempt$([ $attempts -gt 1 ] && echo 's'))"
            echo "$(date '+%Y-%m-%d %H:%M:%S') — FAILED attempt $attempts" >> "$HOME/.aurora-shell_files/login_history.log"
            notify "Aurora-Shell 🔒" "Failed PIN attempt #$attempts" "Basso"
            [[ $attempts -ge 5 ]] && echo "🔒 Too many failed attempts. Locking session." | safe_lolcat && notify "Aurora-Shell 🔒" "Locked out after 5 failed attempts" "Sosumi" && return 1
        fi
    done
    source "$HOME/.aurora-shell_files/aurora-shell_settings" 2>/dev/null
    local box_width=100
    local label="Logged in as ${AURORA_ID:-$USER}"
    local inner_width=$(( box_width - 2 ))
    local label_len=${#label}
    local total_pad=$(( inner_width - label_len ))
    local pad_left=$(( total_pad / 2 ))
    local pad_right=$(( total_pad - pad_left ))
    local top="╭$(printf '─%.0s' $(seq 1 $inner_width))╮"
    local empty="│$(printf ' %.0s' $(seq 1 $inner_width))│"
    local mid="│$(printf ' %.0s' $(seq 1 $pad_left))${label}$(printf ' %.0s' $(seq 1 $pad_right))│"
    local bot="╰$(printf '─%.0s' $(seq 1 $inner_width))╯"
    printf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n" "$top" "$empty" "$empty" "$empty" "$mid" "$empty" "$empty" "$empty" "$bot" | safe_lolcat

}

Show-Aurora() {
    source "$HOME/.aurora-shell_files/aurora-shell_settings"
    local cols=$(tput cols)
    local content=""

    if [[ "$AURORA_HDR_MODE" == "BLOCK" ]]; then
        content="
 █████╗ ██╗   ██╗██████╗  ██████╗ ██████╗  █████╗  
██╔══██╗██║   ██║██╔══██╗██╔═══██╗██╔══██╗██╔══██╗ 
███████║██║   ██║██████╔╝██║   ██║██████╔╝███████║ 
██╔══██║██║   ██║██╔══██╗██║   ██║██╔══██╗██╔══██║ 
██║  ██║╚██████╔╝██║  ██║╚██████╔╝██║  ██║██║  ██║ 
╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ 
                                                   
      ███████╗██╗  ██╗███████╗██╗     ██╗          
      ██╔════╝██║  ██║██╔════╝██║     ██║          
      ███████╗███████║█████╗  ██║     ██║          
      ╚════██║██╔══██║██╔══╝  ██║     ██║          
      ███████║██║  ██║███████╗███████╗███████╗     
      ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝
"
    else
        if [[ "${AURORA_FIGLET_FONT:-slant}" == "banner" ]]; then
            # banner font is wide — render each word separately and stack
            local word1=$(echo "$AURORA_HDR_VAL" | cut -d'-' -f1)
            local word2=$(echo "$AURORA_HDR_VAL" | cut -d'-' -f2)
            if [[ -n "$word2" ]]; then
                content=$(figlet -f banner "$word1" 2>/dev/null)$'\n'$(figlet -f banner "$word2" 2>/dev/null)
            else
                content=$(figlet -f banner "$AURORA_HDR_VAL" 2>/dev/null)
            fi
        else
            content=$(figlet -f "${AURORA_FIGLET_FONT:-slant}" "$AURORA_HDR_VAL" 2>/dev/null | sed '/^[[:space:]]*$/d')
        fi
    fi

    # Centering Header
    local max_w=0
    while IFS= read -r line; do
        (( ${#line} > max_w )) && max_w=${#line}
    done <<< "$content"
    local pad=$(( (cols - max_w) / 2 ))
    (( pad < 0 )) && pad=0

    while IFS= read -r line; do
        printf "%${pad}s%s\n" "" "$line"
    done <<< "$content" | safe_lolcat

    # --- TELEMETRY ---
    local cpu_load="?"
    case "$(uname -s)" in
        Darwin) cpu_load=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//') ;;
        Linux)  cpu_load=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1) ;;
    esac
    local disk_free=$(df -h / | tail -1 | awk '{print $4}')
    local batt="?"
    case "$(uname -s)" in
        Darwin) batt=$(pmset -g batt | grep -Eo '[0-9]+%' | head -1 || echo "?") ;;
        Linux)  batt=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "AC") ;;
    esac
    
    local stats="⚡ AURORA v$AURORA_VER | 🧠 CPU: ${cpu_load}% | 💾 FREE: $disk_free | 🔋 $batt | 📅 $(date +'%D')"
    local s_pad=$(( (cols - ${#stats}) / 2 ))
    [[ $s_pad -lt 0 ]] && s_pad=0
    printf "%${s_pad}s\033[1;34m%s\033[0m\n" "" "$stats"

    # --- THE SEPARATOR DASH LINE ---
    local line_str=""
    for ((i=1; i<=$cols; i++)); do line_str+="-"; done
    echo "$line_str" | safe_lolcat
}

shell.aurora() {
    case "$1" in
        --display) Show-Aurora ;;
        --sys)
            case "$(uname -s)" in
                Darwin) sw_vers && sysctl -n machdep.cpu.brand_string ;;
                Linux)  cat /etc/os-release 2>/dev/null && lscpu | grep "Model name" | head -1 ;;
                *)      uname -a ;;
            esac
            ;;
        --update)
            local branch="${2:-main}"
            # fetch remote version
            local remote_ver=$(curl -sf "https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell/$branch/install.sh" 2>/dev/null | grep '^VER=' | head -1 | sed 's/VER="\(.*\)"/\1/')
            if [[ -z "$remote_ver" ]]; then
                echo "❌ Could not reach update server." | safe_lolcat; return 1
            fi
            # TUI update screen
            clear
            local cols=$(tput cols)
            local line_str=$(printf '─%.0s' $(seq 1 $cols))
            echo "$line_str" | safe_lolcat
            printf "\n"
            printf "%*s\n" $(( (cols + 24) / 2 )) "🔄 AURORA-SHELL UPDATE CHECK" | safe_lolcat
            printf "\n"
            printf "  %-20s %s\n" "Installed version:" "v$AURORA_VER"
            printf "  %-20s %s\n" "Available version:" "v$remote_ver"
            printf "\n"
            if [[ "$remote_ver" == "$AURORA_VER" ]]; then
                printf "  ✅ Already up to date.\n" | safe_lolcat
                printf "\n"; echo "$line_str" | safe_lolcat; return 0
            fi
            printf "  ⬆  Update available: v$AURORA_VER → v$remote_ver\n" | safe_lolcat
            printf "\n"; echo "$line_str" | safe_lolcat; printf "\n"
            # account password gate
            if [[ -f "$HOME/.aurora-shell_files/active_account.json" ]]; then
                local acct_user=$(jq -r '.username' "$HOME/.aurora-shell_files/active_account.json")
                printf "  🔐 Account password for %s: " "$acct_user"
                read -rs _upd_pw; echo ""
                local _upd_hash=$(echo -n "$_upd_pw" | shasum -a 256 | awk '{print $1}')
                local _upd_check=$(curl -sf -X POST -H "Content-Type: application/json" \
                    -d "{\"username\":\"$acct_user\",\"password_hash\":\"$_upd_hash\"}" \
                    "https://aurora-accounts.yash-behera.workers.dev/accounts/login" 2>/dev/null | jq -r '.username // empty')
                if [[ -z "$_upd_check" ]]; then
                    echo "  ❌ Incorrect password — update cancelled." | safe_lolcat
                notify "Aurora-Shell 🔒" "Update cancelled — wrong password" "Basso"
                return 1
                fi
            else
                printf "  ⚠  No account logged in. Continue anyway? (y/N): "
                read _yn; [[ "$_yn" != "y" && "$_yn" != "Y" ]] && echo "  Cancelled." && return 0
            fi
            printf "\n  ⬇  Installing update...\n" | safe_lolcat
            notify "Aurora-Shell" "⬇ Installing update v$remote_ver..." "Ping"
            bash <(curl -s "https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell/$branch/update.sh") "$branch"
            ;;
        --config)
            local _cfg="$HOME/.aurora-shell_files/aurora-shell_settings"
            if open -a "Xcode" "$_cfg" 2>/dev/null; then :
            elif open -a "Xcode-beta" "$_cfg" 2>/dev/null; then :
            elif open -a "Kiro" "$_cfg" 2>/dev/null; then :
            elif open -a "Visual Studio Code" "$_cfg" 2>/dev/null; then :
            elif open -a "Cursor" "$_cfg" 2>/dev/null; then :
            elif open -a "Zed" "$_cfg" 2>/dev/null; then :
            elif open -a "TextEdit" "$_cfg" 2>/dev/null; then :
            elif command -v code &>/dev/null; then code "$_cfg"
            elif command -v kiro &>/dev/null; then kiro "$_cfg"
            elif command -v cursor &>/dev/null; then cursor "$_cfg"
            elif command -v zed &>/dev/null; then zed "$_cfg"
            elif command -v nano &>/dev/null; then nano "$_cfg"
            else ${EDITOR:-vi} "$_cfg"
            fi
            ;;
        --lock)
            local _pin=$(security find-generic-password -a "$USER" -s "aurora-shell-pin" -w 2>/dev/null)
            authenticate_user "MANUAL" && Show-Aurora
            ;;
        --uninstall) rm -rf "$HOME/.aurora-shell_files" && rm -rf $HOME/Applications/Aurora-Shell.app && sed -i '' '/aurora-shell_files/d' ~/.zshrc ;;
        --account) aurora_account "$2" ;;
        --modules-components|-mc)
            echo "📦 Installing Aurora-Shell Module System..." | safe_lolcat
            local _shell_dir="$HOME/.local/shell"
            local _pack_base="https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell/dev/.pack/shell/jackets"
            local _arch=$(uname -m | sed 's/arm64/arm64/;s/x86_64/x86_64/')
            local _platform=$(uname -s | tr '[:upper:]' '[:lower:]' | sed 's/darwin/darwin/;s/linux/linux/')

            mkdir -p "$_shell_dir/bin" "$_shell_dir/cellar" "$_shell_dir/jackets"

            # fetch jacket index
            echo "  ⬇  Fetching jacket index..."
            curl -sf "$_pack_base/index.json" -o "$_shell_dir/jackets/index.json" 2>/dev/null \
                && echo "  ✅ Jacket index fetched" \
                || echo "  ⚠  Could not fetch index — will use fallback"

            # write the shell command
            cat > "$_shell_dir/bin/shell" << 'SHELLEOF'
#!/bin/zsh
# Aurora-Shell module system
SHELL_DIR="$HOME/.local/shell"
JACKET_DIR="$SHELL_DIR/jackets"
CELLAR_DIR="$SHELL_DIR/cellar"
PACK_BASE="https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell/dev/.pack/shell/jackets"
CLI_PACKAGES_FILE="$HOME/.aurora-shell_files/cli-packages.json"
ARCH=$(uname -m)
PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')

safe_lolcat() { command -v lolcat &>/dev/null && command lolcat || cat; }

_jacket_install() {
    local pkg="$1"
    local index="$JACKET_DIR/index.json"
    [ ! -f "$index" ] && curl -sf "$PACK_BASE/index.json" -o "$index" 2>/dev/null

    # resolve alias
    local resolved=$(jq -r ".jackets | to_entries[] | select(.value | to_entries[].value | .name == \"$pkg\" or (.bin == \"$pkg\")) | .key" "$index" 2>/dev/null | head -1)
    [ -n "$resolved" ] && pkg="$resolved"

    local jacket_key="${ARCH}_${PLATFORM}"
    local jacket=$(jq -r ".jackets[\"$pkg\"][\"$jacket_key\"] // empty" "$index" 2>/dev/null)

    if [ -z "$jacket" ]; then
        echo "⚠  No jacket found for $pkg ($jacket_key) — falling back to brew/npm..." | safe_lolcat
        _fallback_install "$pkg"
        return
    fi

    local file=$(echo "$jacket" | jq -r '.file')
    local bin=$(echo "$jacket" | jq -r '.bin')
    local ver=$(echo "$jacket" | jq -r '.version')
    local url="$PACK_BASE/$file"

    echo "🧥 Installing jacket: $pkg v$ver ($jacket_key)" | safe_lolcat
    local tmp=$(mktemp -d)
    curl -sf "$url" -o "$tmp/jacket.tar.gz" 2>/dev/null || { echo "❌ Download failed — falling back"; _fallback_install "$pkg"; rm -rf "$tmp"; return; }
    tar -xzf "$tmp/jacket.tar.gz" -C "$tmp"
    mkdir -p "$CELLAR_DIR/$pkg/$ver"
    cp -R "$tmp/"* "$CELLAR_DIR/$pkg/$ver/" 2>/dev/null
    ln -sf "$CELLAR_DIR/$pkg/$ver/$bin" "$SHELL_DIR/bin/$bin"
    chmod +x "$SHELL_DIR/bin/$bin"
    rm -rf "$tmp"
    echo "✅ $pkg v$ver installed via jacket" | safe_lolcat
}

_fallback_install() {
    local pkg="$1"
    
    # First try to find in CLI packages (third-party tools)
    local cli_pkg=$(jq -r ".packages[\"$pkg\"] // empty" "$CLI_PACKAGES_FILE" 2>/dev/null)
    local pkg_source="cli-packages"
    
    if [ -z "$cli_pkg" ]; then
        # If not found in CLI packages, try core Aurora packages
        cli_pkg=$(jq -r ".packages[\"$pkg\"] // empty" "$PACKAGES_FILE" 2>/dev/null)
        pkg_source="packages"
    fi
    
    if [ -z "$cli_pkg" ]; then
        echo "❌ $pkg not found in jackets or package registries" | safe_lolcat; return 1
    fi
    
    # Handle based on package source/type
    if [ "$pkg_source" = "cli-packages" ]; then
        # Third-party CLI tool - execute install command directly
        local cmd=$(echo "$cli_pkg" | jq -r '.install')
        echo "⬇  Fallback: $cmd" | safe_lolcat
        eval "$cmd"
    else
        # Core Aurora package - handle based on type
        local pkg_type=$(echo "$cli_pkg" | jq -r '.type // empty')
        local pkg_url=$(echo "$cli_pkg" | jq -r '.url // empty')
        
        case "$pkg_type" in
            "dmg")
                # Download and install .dmg file
                echo "⬇  Downloading DMG package..." | safe_lolcat
                local dmg_file="$TEMP_DIR/$(basename "$pkg_url")"
                if curl -sfL "$pkg_url" -o "$dmg_file"; then
                    echo "⬇  Installing from DMG..." | safe_lolcat
                    if hdiutil attach "$dmg_file" -quiet -noautoopen -mountpoint "/Volumes/Install"; then
                        # Find .app file in the mounted volume
                        local app_path=$(find "/Volumes/Install" -name "*.app" -maxdepth 1 -type d | head -n 1)
                        if [ -n "$app_path" ]; then
                            cp -R "$app_path" "/Applications/" && echo "✅ Installed application to /Applications" | safe_lolcat
                        else
                            echo "❌ No .app file found in DMG" | safe_lolcat
                        fi
                        hdiutil detach "/Volumes/Install" -quiet
                    else
                        echo "❌ Failed to mount DMG" | safe_lolcat
                    fi
                    rm -f "$dmg_file"
                else
                    echo "❌ Failed to download DMG" | safe_lolcat
                fi
                ;;
            "wx-installer")
                # Handle wx package (file converter)
                echo "⬇  Installing wx package..." | safe_lolcat
                local wx_file="$INSTALLED_DIR/wx.js"
                if [ ! -f "$wx_file" ]; then
                    if curl -sfL "$pkg_url" -o "$wx_file"; then
                        chmod +x "$wx_file"
                        echo "✅ Installed wx.js" | safe_lolcat
                    else
                        echo "❌ Failed to download wx.js" | safe_lolcat
                        return 1
                    fi
                fi
                # Create wrapper script
                local wrapper="$INSTALLED_DIR/bin/wx"
                mkdir -p "$(dirname "$wrapper")"
                printf '#!/bin/zsh\nnode "%s" "$@"\n' "$wx_file" > "$wrapper"
                chmod +x "$wrapper"
                echo "✅ Created wx wrapper" | safe_lolcat
                ;;
            "cli-installer")
                # Handle cli package (CLI framework itself)
                echo "⬇  Installing CLI package..." | safe_lolcat
                local cli_file="$INSTALLED_DIR/cli.js"
                if [ ! -f "$cli_file" ]; then
                    # Try to download cli.js if URL is provided
                    if [ -n "$pkg_url" ] && [ "$pkg_url" != "install-cli" ]; then
                        if curl -sfL "$pkg_url" -o "$cli_file"; then
                            chmod +x "$cli_file"
                            echo "✅ Installed cli.js" | safe_lolcat
                        else
                            echo "⚠  Failed to download cli.js, creating basic wrapper" | safe_lolcat
                            # Create a basic cli.js file
                            cat > "$cli_file" << 'CLI_EOF'
#!/usr/bin/env node
// Aurora-Shell CLI - Install CLI versions of apps
// This is a placeholder implementation

const program = require('commander');
program
  .name('cli')
  .description('Aurora-Shell CLI - Install CLI versions of apps')
  .version('1.0.0');

program
  .command('install <package>')
  .description('Install a CLI tool')
  .action((package) => {
    console.log(`Installing CLI tool: ${package}`);
    console.log('Use: shell install <package> instead');
  });

program
  .command('list')
  .description('List available CLI tools')
  .action(() => {
    console.log('Available CLI tools can be installed with: shell install <package>');
    console.log('Examples: shell install gh, shell install aws, shell install docker');
  });

program.parse(process.argv);
CLI_EOF
                            chmod +x "$cli_file"
                        fi
                    else
                        # Create a basic cli.js file
                        cat > "$cli_file" << 'CLI_EOF'
#!/usr/bin/env node
// Aurora-Shell CLI - Install CLI versions of apps
// This is a placeholder implementation

const program = require('commander');
program
  .name('cli')
  .description('Aurora-Shell CLI - Install CLI versions of apps')
  .version('1.0.0');

program
  .command('install <package>')
  .description('Install a CLI tool')
  .action((package) => {
    console.log(`Installing CLI tool: ${package}`);
    console.log('Use: shell install <package> instead');
  });

program
  .command('list')
  .description('List available CLI tools')
  .action(() => {
    console.log('Available CLI tools can be installed with: shell install <package>');
    console.log('Examples: shell install gh, shell install aws, shell install docker');
  });

program.parse(process.argv);
CLI_EOF
                        chmod +x "$cli_file"
                    fi
                fi
                # Create wrapper script
                local wrapper="$INSTALLED_DIR/bin/cli"
                mkdir -p "$(dirname "$wrapper")"
                printf '#!/bin/zsh\nnode "%s" "$@"\n' "$cli_file" > "$wrapper"
                chmod +x "$wrapper"
                echo "✅ Created cli wrapper" | safe_lolcat
                ;;
            *)
                # Fallback: treat install field as a command to execute
                local cmd=$(echo "$cli_pkg" | jq -r '.install')
                if [ -n "$cmd" ] && [ "$cmd" != "null" ]; then
                    echo "⬇  Fallback: $cmd" | safe_lolcat
                    eval "$cmd"
                else
                    echo "❌ No install command available for package" | safe_lolcat
                    return 1
                fi
                ;;
        esac
    fi
}
    install)
        _jacket_install "$2"
        ;;
    uninstall)
        local pkg="$2"
        local bin=$(jq -r ".jackets[\"$pkg\"] | to_entries[0].value.bin // empty" "$JACKET_DIR/index.json" 2>/dev/null)
        rm -f "$SHELL_DIR/bin/$bin"
        rm -rf "$CELLAR_DIR/$pkg"
        echo "✅ Uninstalled $pkg" | safe_lolcat
        ;;
    list)
        echo "🧥 Installed jackets:"
        ls "$CELLAR_DIR" 2>/dev/null | while read p; do
            local ver=$(ls "$CELLAR_DIR/$p" 2>/dev/null | head -1)
            printf "  %-30s %s\n" "$p" "$ver"
        done
        ;;
    search)
        local q=$(echo "${2:-}" | tr '[:upper:]' '[:lower:]')
        echo "🔍 Searching jackets..."
        jq -r ".jackets | to_entries[] | select(.key | ascii_downcase | contains(\"$q\")) | \"  \(.key) — \(.value | to_entries[0].value.description)\"" "$JACKET_DIR/index.json" 2>/dev/null
        ;;
    update)
        echo "🔄 Updating jacket index..." | safe_lolcat
        curl -sf "$PACK_BASE/index.json" -o "$JACKET_DIR/index.json" 2>/dev/null && echo "✅ Index updated" | safe_lolcat
        ;;
    outdated)
        echo "📋 Checking for outdated jackets..."
        ls "$CELLAR_DIR" 2>/dev/null | while read p; do
            local installed=$(ls "$CELLAR_DIR/$p" | head -1)
            local latest=$(jq -r ".jackets[\"$p\"] | to_entries[0].value.version // \"unknown\"" "$JACKET_DIR/index.json" 2>/dev/null)
            [ "$installed" != "$latest" ] && echo "  $p: $installed → $latest"
        done
        ;;
    *)
        echo "Aurora-Shell Module System (shell)"
        echo ""
        echo "Usage: shell install|uninstall|list|search|update|outdated <package>"
        echo ""
        echo "Packages are installed from pre-built jackets at:"
        echo "  github.com/Seaus-tech/Aurora-Shell/.pack/shell/jackets"
        echo "  Falls back to brew/npm if no jacket available."
        ;;
esac
SHELLEOF
            chmod +x "$_shell_dir/bin/shell"

            # add to PATH if not already there
            grep -q '\.local/shell/bin' ~/.zshrc 2>/dev/null || echo 'export PATH="$HOME/.local/shell/bin:$PATH"' >> ~/.zshrc
            export PATH="$_shell_dir/bin:$PATH"

            echo ""
            echo "✅ Aurora-Shell Module System installed!" | safe_lolcat
            echo "   shell install <package>   — install from jacket"
            echo "   shell search <query>      — search jackets"
            echo "   shell list                — list installed"
            echo ""
            echo "↺  Restart terminal or run: source ~/.zshrc"
            ;;
        --motd)
            local motd=$(curl -sf --max-time 5 "https://zenquotes.io/api/today" 2>/dev/null | jq -r '.[0] | "\(.q) — \(.a)"' 2>/dev/null)
            [ -n "$motd" ] && echo "$motd" | safe_lolcat || echo "No MOTD available."
            ;;
        --doctor)
            echo "🩺 Aurora-Shell Doctor" | safe_lolcat
            local ok=true
            # PATH
            echo "$PATH" | grep -q "$HOME/.aurora-shell_files/bin" || { echo "⚠ ~/.aurora-shell_files/bin not in PATH"; ok=false; }
            # theme sourced
            grep -q "aurora-shell_theme" "$HOME/.zshrc" 2>/dev/null || { echo "⚠ Theme not sourced in ~/.zshrc"; ok=false; }
            # key tools
            for cmd in jq curl git fzf figlet lolcat; do
                command -v "$cmd" &>/dev/null && echo "✅ $cmd" || { echo "❌ $cmd missing — install with: brew install $cmd"; ok=false; }
            done
            # settings file
            [ -f "$HOME/.aurora-shell_files/aurora-shell_settings" ] || { echo "❌ settings file missing — run installer"; ok=false; }
            $ok && echo "✅ All checks passed" | safe_lolcat && notify "Aurora-Shell" "✅ Doctor: all checks passed"
            $ok || notify "Aurora-Shell ⚠️" "Doctor found issues — check your terminal" "Basso"
            ;;
        --sync)
            [ ! -f "$HOME/.aurora-shell_files/active_account.json" ] && echo "❌ Not logged in" && return 1
            local uname=$(jq -r '.username' "$HOME/.aurora-shell_files/active_account.json")
            local hash=$(jq -r '.password_hash' "$HOME/.aurora-shell_files/active_account.json")
            local aliases=$(alias 2>/dev/null | head -50 | base64 2>/dev/null || echo "")
            local payload=$(jq -n --arg a "$aliases" --arg h "$hash" '{password_hash:$h,aliases:$a}')
            curl -sf -X PATCH -H "Content-Type: application/json" -d "$payload" \
                "https://aurora-accounts.yash-behera.workers.dev/accounts/$uname" >/dev/null 2>&1 \
                && echo "✅ Synced to Aurora account" || echo "❌ Sync failed"
            ;;
        --history)
            if command -v fzf &>/dev/null; then
                local cmd=$(fc -l 1 | fzf --tac --no-sort --prompt="🔍 history> " | sed 's/^ *[0-9]* *//')
                [ -n "$cmd" ] && print -z "$cmd"
            else
                echo "❌ fzf not installed — run: brew install fzf"
            fi
            ;;
        --run)
            if [ -f "package.json" ]; then npm start
            elif [ -f "Cargo.toml" ]; then cargo run
            elif [ -f "go.mod" ]; then go run .
            elif [ -f "manage.py" ]; then python3 manage.py runserver
            elif [ -f "requirements.txt" ] && ls *.py &>/dev/null; then python3 $(ls *.py | head -1)
            elif [ -f "Makefile" ]; then make
            elif [ -f "pom.xml" ]; then mvn spring-boot:run
            elif [ -f "build.gradle" ]; then ./gradlew bootRun
            else echo "❌ No recognisable project type in $(pwd)"; fi
            ;;
        *)
            echo "Flags: --display, --sys, --update [branch], --config, --lock, --uninstall, --account, --motd, --doctor, --sync, --history, --run"
            ;;
    esac
}


# --- SHELL PACKAGE MANAGER ---
PACKAGES_FILE="$HOME/.aurora-shell_files/packages.json"
CLI_PACKAGES_FILE="$HOME/.aurora-shell_files/cli-packages.json"
INSTALLED_DIR="$HOME/.aurora-shell_files/bin"
CASKS_DIR="$HOME/.aurora-shell_files/casks"
mkdir -p "$INSTALLED_DIR"
mkdir -p "$CASKS_DIR"
export PATH="$INSTALLED_DIR:$PATH"

if [ ! -f "$PACKAGES_FILE" ]; then
    cat > "$PACKAGES_FILE" << 'PKGEOF'
{
  "packages": {
    "Aurora.App": {
      "aliases": ["aurora-app"],
      "url": "https://github.com/Seaus-tech/Aurora-Shell/releases/latest/download/aurora-shell.mac.dmg",
      "type": "dmg",
      "description": "Aurora Shell Terminal App for mac"
    },
    "Aurora.CLI": {
      "aliases": ["CLI"],
      "url": "install-cli",
      "type": "cli-installer",
      "description": "Aurora-Shell CLI - Install CLI versions of apps"
    },
    "Aurora.wx": {
      "aliases": ["wx"],
      "url": "install-wx",
      "type": "wx-installer",
      "description": "wx — universal file converter, re-platformer, importer and exporter"
    }
  }
}
PKGEOF
fi


# shell() removed — use the jacket-based module system instead
# Install with: shell.aurora --modules-components
# Then use: shell install|search|list|update|outdated


rainbow_prompt() {
  local raw_text="${AURORA_ID} %n@%m %* > "
  local expanded_text=$(print -P "$raw_text")
  local colors=(196 202 226 190 82 46 48 51 45 39 27 21 57 93 129 165 201 199)
  local out=""
  for (( j=1; j<=${#expanded_text}; j++ )); do
    out+="%{%F{${colors[$(( (j % ${#colors}) + 1 ))]}}%}${expanded_text[j]}%{%f%}"
  done
  echo -n "$out"
}

authenticate_user || { echo "🔒 Session locked." | safe_lolcat; exit; }
Show-Aurora

# --- MOTD ---
_motd=$(curl -sf --max-time 2 "https://zenquotes.io/api/today" 2>/dev/null | jq -r '.[0] | "\(.q) — \(.a)"' 2>/dev/null)
[ -n "$_motd" ] && echo "$_motd" | safe_lolcat

# --- AUTO-SETUP ZSH PLUGINS ---
_setup_zsh_plugins() {
    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    if [ -d "$HOME/.oh-my-zsh" ]; then
        [ ! -d "$zsh_custom/plugins/zsh-autosuggestions" ] && \
            git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions" &>/dev/null
        [ ! -d "$zsh_custom/plugins/zsh-syntax-highlighting" ] && \
            git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$zsh_custom/plugins/zsh-syntax-highlighting" &>/dev/null
        grep -q "zsh-autosuggestions" "$HOME/.zshrc" 2>/dev/null || \
            safe_sed 's/^plugins=(\(.*\))/plugins=(\1 zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc" 2>/dev/null
    fi
}
_setup_zsh_plugins

# --- ACCOUNTS SYSTEM ---
AURORA_WORKER_URL="https://aurora-accounts.yash-behera.workers.dev"
AURORA_ACCOUNT_FILE="$HOME/.aurora-shell_files/active_account.json"
AURORA_SESSION_INSTALLED="$HOME/.aurora-shell_files/session_installed.txt"

_aurora_hash() { echo -n "$1" | shasum -a 256 | awk '{print $1}'; }

_aurora_fetch_account() {
    local username="$1"
    curl -sf "$AURORA_WORKER_URL/accounts/$username" 2>/dev/null
}

_aurora_scan_installed() {
    local pkgs=""
    for cmd in git gh node python3 java go rustc docker aws az gcloud kubectl helm terraform ansible; do
        command -v "$cmd" &>/dev/null && pkgs="$pkgs $cmd"
    done
    # oh-my-zsh plugins
    [ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ] && pkgs="$pkgs zsh-autosuggestions"
    [ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ] && pkgs="$pkgs zsh-syntax-highlighting"
    echo "$pkgs" | xargs
}

_aurora_take_snapshot() {
    local snap="$HOME/.aurora-shell_files/session_snapshot"
    rm -rf "$snap" && mkdir -p "$snap"
    # Shell configs
    for f in ~/.zshrc ~/.zshenv ~/.zprofile ~/.bashrc ~/.bash_profile ~/.bash_login; do
        [ -f "$f" ] && cp "$f" "$snap/$(basename $f).bak"
    done
    # Python config
    [ -f "$HOME/.python-version" ] && cp "$HOME/.python-version" "$snap/python-version.bak"
    [ -f "$HOME/.config/pip/pip.conf" ] && cp "$HOME/.config/pip/pip.conf" "$snap/pip.conf.bak"
    [ -f "$HOME/.pyenv/version" ] && cp "$HOME/.pyenv/version" "$snap/pyenv-version.bak"
    # Package snapshots
    brew list --formula 2>/dev/null | sort > "$snap/brew-formulae.txt"
    brew list --cask 2>/dev/null | sort > "$snap/brew-casks.txt"
    npm list -g --depth=0 2>/dev/null | tail -n +2 | awk '{print $2}' | sort > "$snap/npm-global.txt"
    pip3 list 2>/dev/null | tail -n +3 | awk '{print $1}' | sort > "$snap/pip.txt"
    pipx list 2>/dev/null | grep "package " | awk '{print $2}' | sort > "$snap/pipx.txt"
    gem list 2>/dev/null | sort > "$snap/gem.txt"
    cargo install --list 2>/dev/null | grep -v '^\s' | awk '{print $1}' | sort > "$snap/cargo.txt"
    ls "$HOME/.aurora-shell_files/bin/" 2>/dev/null | sort > "$snap/aurora-bin.txt"
    # oh-my-zsh plugins
    ls "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/" 2>/dev/null | sort > "$snap/omz-plugins.txt"
}

_aurora_apply_profile() {
    local profile="$1"
    local fast="${2:-}"
    local uid=$(echo "$profile" | jq -r '.username // empty')
    local hdr=$(echo "$profile" | jq -r '.header // "Aurora-Shell"')
    local hdr_mode=$(echo "$profile" | jq -r '.header_mode // "BLOCK"')

    # Take full snapshot before changing anything
    _aurora_take_snapshot

    # Apply account settings
    safe_sed 's/^AURORA_ID=.*/AURORA_ID=\"$uid\"/' "$HOME/.aurora-shell_files/aurora-shell_settings" 2>/dev/null
    safe_sed "s/^AURORA_HDR_VAL=.*/AURORA_HDR_VAL=\"$hdr\"/" "$HOME/.aurora-shell_files/aurora-shell_settings" 2>/dev/null
    safe_sed "s/^AURORA_HDR_MODE=.*/AURORA_HDR_MODE=\"$hdr_mode\"/" "$HOME/.aurora-shell_files/aurora-shell_settings" 2>/dev/null

    if [ "$fast" != "--fast" ]; then
        # Install oh-my-zsh if not present
        if [ ! -d "$HOME/.oh-my-zsh" ]; then
            echo "📦 Installing oh-my-zsh for $uid..."
            RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" > /dev/null 2>&1
        fi

        # Install plugins the account uses
        local plugins=$(echo "$profile" | jq -r '.plugins // [] | .[]' 2>/dev/null)
        for plugin in $plugins; do
            local pdir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/$plugin"
            if [ ! -d "$pdir" ]; then
                case "$plugin" in
                    zsh-autosuggestions)
                        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$pdir" > /dev/null 2>&1 ;;
                    zsh-syntax-highlighting)
                        git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$pdir" > /dev/null 2>&1 ;;
                esac
            fi
        done

        # Inject plugins into .zshrc
        if [ -f "$HOME/.zshrc" ] && [ -n "$plugins" ]; then
            safe_sed "s/^plugins=(.*/plugins=($(echo "$plugins" | tr '\n' ' '))/" "$HOME/.zshrc" 2>/dev/null
        fi
    fi

    # Export linked service keys
    local aws_key=$(echo "$profile" | jq -r '.linked.aws_key // empty')
    local aws_secret=$(echo "$profile" | jq -r '.linked.aws_secret // empty')
    local openai_key=$(echo "$profile" | jq -r '.linked.openai_key // empty')
    local anthropic_key=$(echo "$profile" | jq -r '.linked.anthropic_key // empty')
    local gh_token=$(echo "$profile" | jq -r '.linked.gh_token // empty')
    local ollama_host=$(echo "$profile" | jq -r '.linked.ollama_host // empty')
    [ -n "$aws_key" ] && export AWS_ACCESS_KEY_ID="$aws_key" && export AWS_SECRET_ACCESS_KEY="$aws_secret"
    [ -n "$openai_key" ] && export OPENAI_API_KEY="$openai_key"
    [ -n "$anthropic_key" ] && export ANTHROPIC_API_KEY="$anthropic_key"
    [ -n "$gh_token" ] && export GITHUB_TOKEN="$gh_token"
    [ -n "$ollama_host" ] && export OLLAMA_HOST="$ollama_host"

    echo "$profile" > "$AURORA_ACCOUNT_FILE"
    echo "✅ Logged in as $uid${fast:+ (fast mode — installations skipped)}"
}

_aurora_logout_cleanup() {
    local snap="$HOME/.aurora-shell_files/session_snapshot"
    local fast="${1:-}"
    [ ! -d "$snap" ] && return
    echo "🧹 Restoring system state..."

    if [ "$fast" != "--fast" ]; then
        # Diff and uninstall brew formulae added this session
        if [ -f "$snap/brew-formulae.txt" ]; then
            brew list --formula 2>/dev/null | sort | comm -13 "$snap/brew-formulae.txt" - | while read -r pkg; do
                echo "  🗑 brew uninstall $pkg"
                brew uninstall --ignore-dependencies "$pkg" 2>/dev/null
            done
        fi
        # Diff and uninstall brew casks added this session
        if [ -f "$snap/brew-casks.txt" ]; then
            brew list --cask 2>/dev/null | sort | comm -13 "$snap/brew-casks.txt" - | while read -r pkg; do
                echo "  🗑 brew uninstall --cask $pkg"
                brew uninstall --cask "$pkg" 2>/dev/null
            done
        fi
        # npm global
        if [ -f "$snap/npm-global.txt" ]; then
            npm list -g --depth=0 2>/dev/null | tail -n +2 | awk '{print $2}' | sort | \
            comm -13 "$snap/npm-global.txt" - | while read -r pkg; do
                echo "  🗑 npm uninstall -g $pkg"
                npm uninstall -g "$pkg" 2>/dev/null
            done
        fi
        # pip
        if [ -f "$snap/pip.txt" ]; then
            pip3 list 2>/dev/null | tail -n +3 | awk '{print $1}' | sort | \
            comm -13 "$snap/pip.txt" - | while read -r pkg; do
                echo "  🗑 pip uninstall $pkg"
                pip3 uninstall -y "$pkg" 2>/dev/null
            done
        fi
        # pipx
        if [ -f "$snap/pipx.txt" ]; then
            pipx list 2>/dev/null | grep "package " | awk '{print $2}' | sort | \
            comm -13 "$snap/pipx.txt" - | while read -r pkg; do
                echo "  🗑 pipx uninstall $pkg"
                pipx uninstall "$pkg" 2>/dev/null
            done
        fi
        # gem
        if [ -f "$snap/gem.txt" ]; then
            gem list 2>/dev/null | sort | comm -13 "$snap/gem.txt" - | awk '{print $1}' | while read -r pkg; do
                echo "  🗑 gem uninstall $pkg"
                gem uninstall -x "$pkg" 2>/dev/null
            done
        fi
        # cargo
        if [ -f "$snap/cargo.txt" ]; then
            cargo install --list 2>/dev/null | grep -v '^\s' | awk '{print $1}' | sort | \
            comm -13 "$snap/cargo.txt" - | while read -r pkg; do
                echo "  🗑 cargo uninstall $pkg"
                cargo uninstall "$pkg" 2>/dev/null
            done
        fi
        # aurora bin
        if [ -f "$snap/aurora-bin.txt" ]; then
            ls "$HOME/.aurora-shell_files/bin/" 2>/dev/null | sort | \
            comm -13 "$snap/aurora-bin.txt" - | while read -r bin; do
                echo "  🗑 removing aurora bin: $bin"
                rm -f "$HOME/.aurora-shell_files/bin/$bin"
            done
        fi
        # omz plugins added this session
        if [ -f "$snap/omz-plugins.txt" ]; then
            ls "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/" 2>/dev/null | sort | \
            comm -13 "$snap/omz-plugins.txt" - | while read -r plugin; do
                echo "  🗑 removing omz plugin: $plugin"
                rm -rf "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/$plugin"
            done
        fi
        # Remove oh-my-zsh if it wasn't there before
        [ ! -f "$snap/omz-plugins.txt" ] && [ -d "$HOME/.oh-my-zsh" ] && rm -rf "$HOME/.oh-my-zsh"
    fi

    # Restore shell configs
    for f in zshrc zshenv zprofile bashrc bash_profile bash_login; do
        if [ -f "$snap/.$f.bak" ]; then
            cp "$snap/.$f.bak" "$HOME/.$f"
        else
            rm -f "$HOME/.$f"
        fi
    done
    # Restore python configs
    [ -f "$snap/python-version.bak" ] && cp "$snap/python-version.bak" "$HOME/.python-version"
    [ -f "$snap/pip.conf.bak" ] && mkdir -p "$HOME/.config/pip" && cp "$snap/pip.conf.bak" "$HOME/.config/pip/pip.conf"
    [ -f "$snap/pyenv-version.bak" ] && cp "$snap/pyenv-version.bak" "$HOME/.pyenv/version"

    # Clear session state
    rm -rf "$snap" "$AURORA_ACCOUNT_FILE" "$AURORA_SESSION_INSTALLED"
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY OPENAI_API_KEY ANTHROPIC_API_KEY GITHUB_TOKEN OLLAMA_HOST
    echo "👋 Logged out. System restored."
}

aurora_account() {
    case "$1" in
        --create)
            printf "👤 Username: "; read -r uname
            printf "🔐 Password: "; read -rs pw; echo ""
            printf "🔐 Confirm:  "; read -rs pw2; echo ""
            [ "$pw" != "$pw2" ] && echo "❌ Passwords don't match" && return 1

            # Check username not taken
            local existing=$(curl -sf -X POST -H "Content-Type: application/json" \
                -d "{\"username\":\"$uname\",\"password_hash\":\"x\"}" \
                "$AURORA_WORKER_URL/accounts/login" 2>/dev/null | jq -r '.error // empty')
            # If error is NOT "Not found", username exists
            [ "$existing" != "Not found" ] && [ -n "$(curl -sf "$AURORA_WORKER_URL/accounts/$uname" 2>/dev/null)" ] && echo "❌ Username '$uname' already taken" && return 1

            local hash=$(_aurora_hash "$pw")
            local installed=$(_aurora_scan_installed)
            local plugins=""
            echo "$installed" | grep -q "zsh-autosuggestions" && plugins="$plugins\"zsh-autosuggestions\","
            echo "$installed" | grep -q "zsh-syntax-highlighting" && plugins="$plugins\"zsh-syntax-highlighting\","
            plugins="[${plugins%,}]"

            local payload=$(jq -n \
                --arg u "$uname" \
                --arg h "$hash" \
                --arg i "$installed" \
                --argjson p "$plugins" \
                '{username:$u, password_hash:$h, installed:$i, plugins:$p, linked:{}, header:"Aurora-Shell", header_mode:"BLOCK"}')

            echo "📤 Creating account..."
            local resp=$(curl -sf -X POST -H "Content-Type: application/json" \
                -d "$payload" "$AURORA_WORKER_URL/accounts")
            local err=$(echo "$resp" | jq -r '.error // empty')
            [ -n "$err" ] && echo "❌ $err" && return 1
            echo "✅ Account created. You can now login with: aurora --account --login"
            ;;

        --login)
            printf "👤 Username: "; read -r uname
            printf "🔐 Password: "; read -rs pw; echo ""
            local hash=$(_aurora_hash "$pw")
            local resp=$(curl -sf -X POST -H "Content-Type: application/json" \
                -d "{\"username\":\"$uname\",\"password_hash\":\"$hash\"}" \
                "$AURORA_WORKER_URL/accounts/login")
            local err=$(echo "$resp" | jq -r '.error // empty')
            [ -n "$err" ] && echo "❌ $err" && return 1
            # Store hash locally for owner API calls (already hashed, safe on disk)
            resp=$(echo "$resp" | jq --arg h "$hash" '. + {password_hash: $h}')
            _aurora_apply_profile "$resp" "$2"
            ;;

        --logout)
            _aurora_logout_cleanup "$2"
            ;;

        --link)
            [ ! -f "$AURORA_ACCOUNT_FILE" ] && echo "❌ Not logged in" && return 1
            local profile=$(cat "$AURORA_ACCOUNT_FILE")
            local uname=$(echo "$profile" | jq -r '.username')
            printf "🔐 Password: "; read -rs pw; echo ""
            local hash=$(_aurora_hash "$pw")

            echo "Link service: 1) AWS  2) GitHub  3) OpenAI  4) Anthropic  5) Ollama"
            printf "Choice: "; read -r svc
            local update="{}"
            case "$svc" in
                1) printf "AWS Key ID: "; read -r k; printf "AWS Secret: "; read -rs s; echo ""
                   update=$(jq -n --arg k "$k" --arg s "$s" --arg h "$hash" '{password_hash:$h,linked:{aws_key:$k,aws_secret:$s}}') ;;
                2) printf "GitHub Token: "; read -rs t; echo ""
                   update=$(jq -n --arg t "$t" --arg h "$hash" '{password_hash:$h,linked:{gh_token:$t}}') ;;
                3) printf "OpenAI API Key: "; read -rs t; echo ""
                   update=$(jq -n --arg t "$t" --arg h "$hash" '{password_hash:$h,linked:{openai_key:$t}}') ;;
                4) printf "Anthropic API Key: "; read -rs t; echo ""
                   update=$(jq -n --arg t "$t" --arg h "$hash" '{password_hash:$h,linked:{anthropic_key:$t}}') ;;
                5) printf "Ollama Host (default localhost:11434): "; read -r h
                   update=$(jq -n --arg h "${h:-localhost:11434}" --arg pw "$hash" '{password_hash:$pw,linked:{ollama_host:$h}}') ;;
                *) echo "❌ Invalid choice" && return 1 ;;
            esac

            local resp=$(curl -sf -X PATCH -H "Content-Type: application/json" \
                -d "$update" "$AURORA_WORKER_URL/accounts/$uname")
            local err=$(echo "$resp" | jq -r '.error // empty')
            [ -n "$err" ] && echo "❌ $err" && return 1
            # Refresh local profile
            local new_profile=$(curl -sf -X POST -H "Content-Type: application/json" \
                -d "{\"username\":\"$uname\",\"password_hash\":\"$hash\"}" \
                "$AURORA_WORKER_URL/accounts/login")
            echo "$new_profile" > "$AURORA_ACCOUNT_FILE"
            echo "✅ Service linked and synced"
            ;;

        --whoami)
            [ ! -f "$AURORA_ACCOUNT_FILE" ] && echo "Not logged in" && return
            local owner_badge=$(jq -r 'if .is_owner then " 👑 OWNER" else "" end' "$AURORA_ACCOUNT_FILE")
            jq -r '"👤 \(.username)\(.is_owner // false | if . then " 👑 OWNER" else "" end) | plugins: \(.plugins | join(", ")) | linked: \(.linked | keys | join(", "))"' "$AURORA_ACCOUNT_FILE"
            ;;

        --users)
            [ ! -f "$AURORA_ACCOUNT_FILE" ] && echo "❌ Not logged in" && return 1
            local uname=$(jq -r '.username' "$AURORA_ACCOUNT_FILE")
            local hash=$(jq -r '.password_hash' "$AURORA_ACCOUNT_FILE" 2>/dev/null)
            [ -z "$hash" ] && printf "🔐 Password: " && read -rs hash && hash=$(_aurora_hash "$hash") && echo ""
            local resp=$(curl -sf -H "X-Username: $uname" -H "X-Password-Hash: $hash" \
                "$AURORA_WORKER_URL/accounts")
            local err=$(echo "$resp" | jq -r '.error // empty')
            [ -n "$err" ] && echo "❌ $err (owner only)" && return 1
            echo "$resp" | jq -r '.[] | "👤 \(.username)\(if .is_owner then " 👑" else "" end) | plugins: \(.plugins | join(", "))"'
            ;;

        --audit)
            local log="$HOME/.aurora-shell_files/login_history.log"
            [ -f "$log" ] && cat "$log" | tail -20 | safe_lolcat || echo "No login history found."
            ;;
        --switch)
            [ -z "$2" ] && echo "Usage: aurora_account --switch <username>" && return 1
            _aurora_logout_cleanup --fast 2>/dev/null
            printf "🔐 Password for $2: "; read -rs pw; echo ""
            local hash=$(_aurora_hash "$pw")
            local resp=$(curl -sf -X POST -H "Content-Type: application/json" \
                -d "{\"username\":\"$2\",\"password_hash\":\"$hash\"}" \
                "$AURORA_WORKER_URL/accounts/login")
            local err=$(echo "$resp" | jq -r '.error // empty')
            [ -n "$err" ] && echo "❌ $err" && return 1
            resp=$(echo "$resp" | jq --arg h "$hash" '. + {password_hash: $h}')
            _aurora_apply_profile "$resp" --fast
            ;;
        *)
            echo "  --create   Create a new Aurora account"
            echo "  --login           Sign in to your account"
            echo "  --login --fast    Sign in, apply config only (skip installations)"
            echo "  --logout         Sign out and restore system to pre-login state"
            echo "  --logout --fast  Sign out quickly (restore configs only, skip uninstalls)"
            echo "  --link            Link a service (AWS, GitHub, OpenAI, Anthropic, Ollama)"
            echo "  --whoami          Show current logged-in account"
            echo "  --users           List all accounts (owner only)"
            echo "  --audit           Show login history"
            echo "  --switch <user>   Switch to another account (fast)"
            ;;
    esac
}

# Register logout cleanup on shell exit
trap '_aurora_logout_cleanup' EXIT

# --- VERSION CHECK ---
REMOTE_VER=$(curl -sf "https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell/dev/install.sh" 2>/dev/null | grep '^VER=' | head -1 | sed 's/VER="\(.*\)"/\1/')
if [ -n "$REMOTE_VER" ] && [ "$REMOTE_VER" != "$AURORA_VER" ]; then
    echo ""
    echo "🔔 Aurora-Shell update available (v$AURORA_VER → v$REMOTE_VER) — run: shell.aurora --update" | safe_lolcat
    notify "Aurora-Shell" "Update available: v$AURORA_VER → v$REMOTE_VER" "Ping"
fi
EOF
}

# --- EXECUTE ---
sync_env
install_com
run_wizard
generate_theme

safe_sed '/aurora-shell_theme/d' ~/.zshrc 2>/dev/null
echo "source $THEME_FILE" >> "$HOME/.zshrc"

# --- REPO DISCOVERY ---
echo "🌀 Checking Aurora-shell..."
cd "$HOME"

# Targeted search instead of global find
check_dir() {
    [ -z "$1" ] && return 1
    if [ -d "$1/.git" ]; then
        local origin=$(git -C "$1" remote get-url origin 2>/dev/null)
        if [ "$origin" = "$GIT_CLONE" ]; then
            echo "$1"
            return 0
        fi
    fi
    return 1
}

FOUND_REPO=""
# Check common locations
for d in "$(pwd)" "$HOME/Documents/Aurora-Shell" "$HOME/Aurora-Shell" "$DATA_DIR/aurora-shell"; do
    if FOUND_REPO=$(check_dir "$d"); then
        break
    fi
    FOUND_REPO=""
done

if [ -n "$FOUND_REPO" ]; then
    echo "🔄 Found existing Aurora-shell repo at: $FOUND_REPO"
    cd "$FOUND_REPO"
    git pull || true
    cp "$FOUND_REPO/brew-progress.py" "$DATA_DIR/brew-progress.py" 2>/dev/null || true
    cp "$FOUND_REPO/spinner.js" "$DATA_DIR/spinner.js" 2>/dev/null || true
    cp "$FOUND_REPO/wx.js" "$DATA_DIR/wx.js" 2>/dev/null || true
    [ -f "$DATA_DIR/wx.js" ] && printf '#!/bin/zsh\nnode "$HOME/.aurora-shell_files/wx.js" "$@"\n' > "$DATA_DIR/bin/wx" && chmod +x "$DATA_DIR/bin/wx"
else
    echo "⬇ No matching repo found — cloning fresh copy..."
    cd "$DATA_DIR"
    rm -rf aurora-shell # Clean up if it exists but is not a repo
    git clone "$GIT_CLONE" aurora-shell || true
    cp "$DATA_DIR/aurora-shell/brew-progress.py" "$DATA_DIR/brew-progress.py" 2>/dev/null || true
    cp "$DATA_DIR/aurora-shell/spinner.js" "$DATA_DIR/spinner.js" 2>/dev/null || true
    cp "$DATA_DIR/aurora-shell/wx.js" "$DATA_DIR/wx.js" 2>/dev/null || true
    [ -f "$DATA_DIR/wx.js" ] && printf '#!/bin/zsh\nnode "$HOME/.aurora-shell_files/wx.js" "$@"\n' > "$DATA_DIR/bin/wx" && chmod +x "$DATA_DIR/bin/wx"
fi

echo -e "\n\033[1;32m✅ successfully deployed Aurora-Shell v$VER.\033[0m"

if command -v terminal-notifier &>/dev/null; then
    terminal-notifier -title "Aurora-Shell" -message "Setup complete" -sound "Ping"
fi

cd "$HOME"
sleep 1
exec "$SHELL" -l
