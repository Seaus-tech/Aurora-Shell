#!/bin/bash
# Aurora-Shell Homebrew Installer
# Non-interactive — runs install.sh in brew mode to generate the full theme
set -e

BREW_SHARE="$(brew --prefix)/share/aurora-shell"
INSTALL_SH="$BREW_SHARE/install.sh"

if [ ! -f "$INSTALL_SH" ]; then
    echo "❌ Aurora-Shell install.sh not found at $INSTALL_SH"
    exit 1
fi

# Run the main installer in non-interactive brew mode
# AURORA_BREW_INSTALL=1 tells install.sh to skip the wizard and just generate files
export AURORA_BREW_INSTALL=1
bash "$INSTALL_SH"
