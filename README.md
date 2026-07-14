# 🌌 Aurora-Shell

<p align="center">
  <strong>A sleek, high-performance terminal theme and diagnostic dashboard for macOS (Zsh) and Windows (PowerShell 7+).</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%20%7C%20Windows-blue?style=flat-square&logo=apple" alt="Platform" />
  <img src="https://img.shields.io/badge/Shell-Zsh%20%7C%20PowerShell-0078D4?style=flat-square&logo=gnubash&logoColor=white" alt="Shell" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License" />
</p>

---

## 🌟 Features

- 📊 **Real-time Diagnostics** — View Battery, CPU usage, and Disk space every time you open a terminal
- ⏱️ **Session Tracking** — Displays a "Start Time" so you know exactly when you began your session
- 🔄 **Cross-Platform** — Tailored experiences for both macOS and Windows environments

---

## 🚀 Installation

### 🍎 For macOS (Zsh)

**Option 1: Download macOS App (.dmg)**
1. Download the latest `Aurora-Shell.dmg`
2. Mount the DMG and install:
```bash
mkdir ~/Applications && unzip ~/downloads/Aurora-Shell.zip -d ~/Applications && xattr -d com.apple.quarantine ~/Applications/Aurora-Shell.app && open ~/Applications/Aurora-Shell.app
```

**Option 2: Command Line Install**
```bash
bash <(curl -s https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell/main/install.sh)
```

### 🪟 For Windows (PowerShell 7+)

> [!IMPORTANT]
> This theme requires Microsoft PowerShell 7.0 or higher. It is not compatible with Windows PowerShell 5.1.

**Install PowerShell 7 (if needed):**
```powershell
winget install Microsoft.PowerShell
```

Or for PowerShell Preview:
```powershell
winget install Microsoft.PowerShell.Preview
```

**Option 1**:
```powershell
irm "https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell/dev/install.ps1" | iex
```

**Option 2: Download Installer (.exe)**
1. Download [Aurora-Windows-Installer](https://github.com/Seaus-tech/Aurora-Shell-2/releases/download/v2.0.0/aurora-app.exe)

---

## 📦 Dependencies

macOS requires `lolcat` for colorful output:
```bash
brew install lolcat
```

---

## 🛠️ Customization

The main configuration logic is stored in:

- **macOS**: `~/.aurora-shell_tfiles` (sourced in your `.zshrc`)
- **Windows**: `$PROFILE` (usually located in `Documents\PowerShell\Microsoft.PowerShell_profile.ps1`)

---

## 🗑️ Uninstall

To remove Aurora Shell on macOS:
```bash
cd $HOME && shell.aurora --uninstall && cd -
```

For Windows:
```powershell
Invoke-RestMethod -Uri "https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell-2/main/uninstall.ps1" | PowerShell -ExecutionPolicy Bypass -Command -
```

---

## 📺 Example Banners

### Figlet Style
```
                                ___                                    _____ __         ____
                               /   | __  ___________  _________ _     / ___// /_  ___  / / /
                              / /| |/ / / / ___/ __ \/ ___/ __ `/_____\__ \/ __ \/ _ \/ / / 
                             / ___ / /_/ / /  / /_/ / /  / /_/ /_____/__/ / / / /  __/ / /  
                            /_/  |_\__,_/_/   \____/_/   \__,_/     /____/_/ /_/\___/_/_/   
                                                                                            
                          ⚡ AURORA v5.4.0 | 🧠 CPU: 10.00% | 💾 FREE: 100Gi | 🔋 100% | 📅 00/00/00
------------------------------------------------------------------------------------------------------------------------
```

### Block Style
```
                                  
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

---

## 🔐 Security Terminal

```
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

---

## 📣 Stay Updated

Sign up for the Aurora-Shell dev program to get updates on new releases, features, and exclusive content!

```bash
open "https://forms.cloud.microsoft/r/GYXq1H83eU"
```

---

<p align="center">
  <sub>© 2026 Seaus Tech. All rights reserved.</sub>
</p>