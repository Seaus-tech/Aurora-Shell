#DEPRECATED
#!/bin/bash
set -e

VERSION="2.0.0"
APP_NAME="Aurora Shell"
IDENTIFIER="com.yashb.aurora-shell"
BUILD_DIR="build"
PKG_ROOT="$BUILD_DIR/pkg-root"
SCRIPTS_DIR="$BUILD_DIR/scripts"

echo "🌌 Building Aurora Shell Installer..."

# Clean and create build directories
rm -rf "$BUILD_DIR"
mkdir -p "$PKG_ROOT"
mkdir -p "$SCRIPTS_DIR"

# Create postinstall script that runs as user
cat > "$SCRIPTS_DIR/postinstall" << 'POSTINSTALL'
#!/bin/bash
cat << 'EOF' > "$HOME/.aurora_theme.sh"
# Aurora Shell Official Banner
echo "
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
" | lolcat

get_battery() { 
    if command -v pmset &> /dev/null; then 
        pmset -g batt | grep -Eo "\d+%" | head -1
    else 
        echo "⚡ AC"
    fi
}
get_disk() { df -h / | awk 'NR==2 {print $4}'; }
get_cpu() { uptime | awk -F'load averages: ' '{ print $2 }' | cut -d' ' -f1; }

echo "📅 $(date +'%D') | 🔋 $(get_battery) | 🧠 CPU: $(get_cpu) | 💽 $(get_disk) Free" | lolcat
echo "---------------------------------------------------" | lolcat
export PROMPT="%F{cyan}🌌 Aurora %F{white}%n@%m: %f"
EOF

grep -q "source ~/.aurora_theme.sh" "$HOME/.zshrc" || echo "source ~/.aurora_theme.sh" >> "$HOME/.zshrc"
echo "✨ Aurora Shell installed! Restart your terminal."
exit 0
POSTINSTALL

chmod +x "$SCRIPTS_DIR/postinstall"

# Build component package
pkgbuild --root "$PKG_ROOT" \
         --scripts "$SCRIPTS_DIR" \
         --identifier "$IDENTIFIER" \
         --version "$VERSION" \
         --install-location "/" \
         "$BUILD_DIR/AuroraShell-component.pkg"

# Create distribution XML for user install
cat > "$BUILD_DIR/distribution.xml" << 'DISTXML'
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
    <title>Aurora Shell</title>
    <organization>com.yashb</organization>
    <domains enable_localSystem="false" enable_anywhere="false" enable_currentUserHome="true"/>
    <options customize="never" require-scripts="false" rootVolumeOnly="true"/>
    <choices-outline>
        <line choice="default">
            <line choice="com.yashb.aurora-shell"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="com.yashb.aurora-shell" visible="false">
        <pkg-ref id="com.yashb.aurora-shell"/>
    </choice>
    <pkg-ref id="com.yashb.aurora-shell" version="2.0.0" onConclusion="none">AuroraShell-component.pkg</pkg-ref>
</installer-gui-script>
DISTXML

# Build final product package
productbuild --distribution "$BUILD_DIR/distribution.xml" \
             --package-path "$BUILD_DIR" \
             "$BUILD_DIR/AuroraShell.pkg"

# Create DMG staging area
DMG_DIR="$BUILD_DIR/dmg"
mkdir -p "$DMG_DIR"
cp "$BUILD_DIR/AuroraShell.pkg" "$DMG_DIR/"
cp README.md "$DMG_DIR/"

# Create the .dmg
hdiutil create -volname "Aurora Shell $VERSION" \
               -srcfolder "$DMG_DIR" \
               -ov -format UDZO \
               "AuroraShell-$VERSION.dmg"

echo "✅ Build complete!"
echo "📦 Package: $BUILD_DIR/AuroraShell.pkg"
echo "💿 DMG: AuroraShell-$VERSION.dmg"
