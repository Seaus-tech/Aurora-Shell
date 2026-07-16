# 🌌 Aurora-Shell

<p align="center>
  <strong>A sleek, high-performance terminal theme and diagnostic dashboard for macOS (Zsh) and Windows (PowerShell 7+).</strong>
</p>

<p align="center>
  <img src="https://img.shields.io/badge/Platform-macOS%20%7C%20Windows-blue?style=flat-square&logo=apple" alt="Platform" />
  <img src="https://img.shields.io/badge/Shell-Zsh%20%7C%20PowerShell-0078D4?style=flat-square&logo=gnubash&logoColor=white" alt="Shell" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License" />
</p>

---

## 📖 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Screenshots](#screenshots)
- [Installation](#installation)
- [Dependencies](#dependencies)
- [Customization](#customization)
- [Uninstall](#uninstall)
- [Roadmap](#roadmap)
- [Contributing](#contributing)

## Overview

Aurora-Shell transforms your terminal into a high-performance dashboard with real-time system diagnostics. It provides beautiful, informative prompts for both macOS (Zsh) and Windows (PowerShell 7+).

## Features

| Feature | Description |
|---------|-------------|
| 📊 **Real-time Diagnostics** | View Battery, CPU usage, and Disk space every time you open a terminal |
| ⏱️ **Session Tracking** | Displays session start time and duration |
| 🔄 **Cross-Platform** | Tailored experiences for macOS and Windows |
| 🎨 **Multiple Themes** | Figlet and Block ASCII art styles |
| 🛡️ **Security Terminal** | Dedicated authentication prompt |

## Screenshots

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

## Installation

### 🍎 For macOS (Zsh)

**Option 1: Download macOS App (.dmg)**
```bash
mkdir ~/Applications && unzip ~/downloads/Aurora-Shell.zip -d ~/Applications && xattr -d com.apple.quarantine ~/Applications/Aurora-Shell.app && open ~/Applications/Aurora-Shell.app
```

**Option 2: Command Line Install**
```bash
bash <(curl -s https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell/main/install.sh)
```

### 🪟 For Windows (PowerShell 7+)

> **IMPORTANT**: This theme requires Microsoft PowerShell 7.0 or higher. It is not compatible with Windows PowerShell 5.1.

Install PowerShell 7 (if needed):
```powershell
winget install Microsoft.PowerShell
```

Or for PowerShell Preview:
```powershell
winget install Microsoft.PowerShell.Preview
```

Then install Aurora-Shell:
```powershell
irm "https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell/dev/install.ps1" | iex
```

## Dependencies

### macOS

macOS requires `lolcat` for colorful output:
```bash
brew install lolcat
```

### Windows

No additional dependencies required for PowerShell 7+.

## Customization

The main configuration logic is stored in:

- **macOS**: `~/.aurora-shell_tfiles` (sourced in your `.zshrc`)
- **Windows**: `$PROFILE` (usually `Documents\PowerShell\Microsoft.PowerShell_profile.ps1`)

## Uninstall

### macOS
```bash
cd $HOME && shell.aurora --uninstall && cd -
```

### Windows
```powershell
Invoke-RestMethod -Uri "https://raw.githubusercontent.com/Seaus-tech/Aurora-Shell-2/main/uninstall.ps1" | PowerShell -ExecutionPolicy Bypass -Command -
```

## Roadmap

- [ ] Add support for bash and fish shells
- [ ] Create themed prompt customization UI
- [ ] Add plugin system for custom modules
- [ ] Implement terminal color scheme generator

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📣 Stay Updated

Sign up for the Aurora-Shell dev program to get updates on new releases, features, and exclusive content!

```bash
open "https://forms.cloud.microsoft/r/GYXq1H83eU"
```

---

© 2026 Seaus Tech. All rights reserved.