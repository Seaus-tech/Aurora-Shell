
# 🌅 Horizon

**A sleek, high-performance native macOS terminal emulator companion app built using Swift and SwiftUI for [Aurora-Shell](https://github.com/Seaus-tech/Aurora-Shell).**

---

## 📖 Table of Contents
- [Overview](#-overview)
- [Features](#-features)
- [Project Structure](#-project-structure)
- [Requirements](#-requirements)
- [Installation & Build](#-installation--build)
- [Dependencies](#-dependencies)
- [License](#-license)

---

## 👀 Overview
**Horizon** serves as the graphical, native macOS application layer for **Aurora-Shell**. It utilizes custom pseudo-terminal (PTY) bridging structures to seamlessly load and handle high-performance configurations, real-time telemetry diagnostics, and beautiful terminal rendering out of a sandboxed or unsandboxed macOS environment.

---

## ✨ Features
* 🧵 **PTY Bridge Core** – Native integration to pipe shell processes cleanly directly inside a native Swift execution cycle.
* 🌌 **Liquid Background** – A stunning, modern visual aesthetic layer rendering fluid animations matching the Aurora design language.
* 🛡️ **Sandboxed & Secure** – Optional secure terminal profile contexts to control sandboxed file navigation or broad root system access.
* 🎨 **View Representables** – Seamless SwiftUI multi-window wrapper architectures powering continuous shell render rendering passes.

---

## 📂 Project Structure
Below is a map of the core logic files driving Horizon inside this repository:

* `Aurora_shellApp.swift` — The main entry point initializing core application windows.
* `PTYBridge.swift` — Handles pseudo-terminal interactions, piping text, and lifecycle actions between your machine and shell.
* `TerminalEngine.swift` & `TerminalViewRepresentable.swift` — The primary backend parsing logic and SwiftUI layout engine layers.
* `ShellViewModel.swift` & `ShellModel.swift` — Coordinates application runtime variables, theme configurations, and text history stream parsing.
* `LiquidBackground.swift` — Custom graphic display layout producing reactive backdrop textures.
* `EditorView.swift` & `FileViewerView.swift` — Extra workspace modular tools built to browse configurations and files directly.

---

## ⚙️ Requirements
* **macOS**: 13.0 (Ventura) or newer
* **Xcode**: 15.0+ 
* **Swift**: 5.9+

---

## 🛠 Installation & Build

1. Clone the project locally:
   ```bash
   git clone https://github.com
   cd Horizon
   ```
2. Open `Horizon.xcodeproj` inside Xcode.
3. Resolve package dependencies via Swift Package Manager (SPM).
4. Select target architecture as **My Mac**, and press `⌘ + R` to compile and run!

---

## 📦 Dependencies
Horizon depends on the following libraries (synced automatically over Swift Package Manager):
* **`swift-argument-parser`** (v1.8.2) — Clean utility tools processing launch arguments.
* **`SwiftTerm`** (`main` branch tracking) — High-performance terminal emulation engine canvas mapping input/output flows.

---

## 📄 License
This project is licensed under the terms of the **MIT License**.

