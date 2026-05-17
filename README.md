# 🌌 Aurora-Shell
Aurora-Shell is a sleek, high-performance terminal theme and diagnostic dashboard for macOS (Zsh) and Windows (PowerShell 7+).

✨ Features

Real-time Diagnostics: View Battery, CPU usage, and Disk space every time you open a terminal.

Session Tracking: Displays a "Start Time" so you know exactly when you began your session.

Cross-Platform: Tailored experiences for both Mac and Windows environments.

🚀 Installation:

🍎 For macOS (Zsh)

**Option 1: Download macOS App (.dmg)**
1. Download the latest Aurora-Shell.dmg
2. Mount the DMG and install:
   ```bash
   cp -R '/Volumes/Aurora-Shell for Mac/Aurora-Shell.app' ~/Applications && xattr -d com.apple.quarantine ~/Applications/Aurora-Shell.app && open ~/Applications/Aurora-Shell.app
   ```

**Option 2: Download Theme Installer (.dmg)**
1. Download the latest [AuroraShell.dmg](https://github.com/Seaus-tech/Aurora-Shell-2/releases/latest)
2. Open the .dmg file
3. Open Terminal and run:
   ```bash
   cp '/Volumes/Aurora-Shell for Mac/Aurora-Shell.app' ~/downloads && xattr -d com.apple.quarantine ~/Downloads/Aurora-Shell.app && open ~/downloads/Aurora-Shell.app
   ```
4. Follow the installer prompts
5. Restart your terminal

**Option 2: Command Line Install**
```bash
bash <(curl -s https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell/main/install.sh)
```

🪟 For Windows (PowerShell 7+)

> [!IMPORTANT]
> This theme requires Microsoft PowerShell 7.0 or higher. It is not compatible with Microsoft Windows PowerShell 5.1.

**Install PowerShell 7 (if needed):**
```powershell
winget install Microsoft.PowerShell
```

Or for PowerShell Preview:
```powershell
winget install Microsoft.PowerShell.Preview
```

**Option 1: command line install**
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell/main/install.ps1'))
```

**Option 2: download installer (.exe)**
1. download [Aurora-Windows-Installer](https://github.com/Seaus-tech/Aurora-Shell-2/releases/download/v2.0.0/aurora-app.exe)

📦 **Dependencies**

macOS requires `lolcat` for colorful output:
```bash
brew install lolcat
```

🛠️ Customization
The main configuration logic is stored in:

Mac: ~/.aurora_theme.sh (sourced in your .zshrc)

Windows: $PROFILE (usually located in Documents\PowerShell\Microsoft.PowerShell_profile.ps1)

🗑️ Uninstall

To remove Aurora Shell on MacOS:
```bash
curl -s https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell-2/main/uninstall.sh | bash
```
 
or for windows:
```powershell
Invoke-RestMethod -Uri "https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell-2/main/uninstall.ps1" | PowerShell -ExecutionPolicy Bypass -Command -
```

Example banners:

for figlet:

```Aurora-Shell
                                ___                                    _____ __         ____
                               /   | __  ___________  _________ _     / ___// /_  ___  / / /
                              / /| |/ / / / ___/ __ \/ ___/ __ `/_____\__ \/ __ \/ _ \/ / / 
                             / ___ / /_/ / /  / /_/ / /  / /_/ /_____/__/ / / / /  __/ / /  
                            /_/  |_\__,_/_/   \____/_/   \__,_/     /____/_/ /_/\___/_/_/   
                                                                                            
                          ⚡ AURORA v5.4.0 | 🧠 CPU: 10.00% | 💾 FREE: 100Gi | 🔋 100% | 📅 00/00/00
------------------------------------------------------------------------------------------------------------------------
```

For block:

```Aurora-Shell
                                  
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
                                  
                          ⚡ AURORA v5.4.0 | 🧠 CPU: 10.00% | 💾 FREE: 100Gi | 🔋 100% | 📅 00/00/00
------------------------------------------------------------------------------------------------------------------------
```

For lock:

```Aurora-shell
           .---.
          /     \
         | (00)  |  SYSTEM ENCRYPTED
          \  ^  /
           '---'
     ╔════════════════════════════════════════╗
     ║     AURORA-SHELL SECURITY TERMINAL     ║
     ╚════════════════════════════════════════╝
[AUTH] Key: 
```

# sign up for the aurora-shell dev program to get updates on new releases, features, and exclusive content!

```bash
open "https://forms.cloud.microsoft/r/GYXq1H83eU"
```
