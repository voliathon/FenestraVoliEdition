# Windower 5 / Fenestra (Voli Edition)

Fenestra is a modern, high-performance launcher and windower utility for Final Fantasy XI. 

This repository is a heavily modernized fork of the original Windower launcher, completely upgraded to compile natively on the latest toolchains (Visual Studio 2026 / v145) and run on the cutting-edge **.NET 10** runtime.

## 🚀 Features
* **Lightning Fast UI:** A sleek, WPF-based launcher that manages profiles, dimensions, and game arguments.
* **Modern Package Manager:** A completely modular Lua scripting engine (Windower 5 architecture) that dynamically loads custom addons and tools directly into the game.
* **Automated CI/CD:** Fully automated GitHub Actions release pipeline for effortless distribution.
* **Modern Security:** Relies on the host OS for secure, modern TLS protocol negotiation and modern IPC standards.

> **Note for Developers:** For a detailed breakdown of the internal architectural changes, including the IPC rewrite and the migration to the .NET 10 runtime, please read the [Architecture & .NET 10 Migration Notes](DOTNET10_MIGRATION.md).

## 🛠️ Build Requirements
To compile this project locally, you will need the following installed:
1. **Visual Studio 2026**
2. **.NET 10 SDK** (Available via the Visual Studio Installer -> .NET Desktop Development)
3. **MSVC v143 Build Tools** (To maintain upstream compatibility with the `core.dll` and `luajit` submodules, ensure the VS 2022 v143 toolset is checked in the VS Installer).
4. **WiX Toolset v3.14** (Required only for building `installer.sln`. Install the core tools from the [WiX Releases Page](https://github.com/wixtoolset/wix3/releases) and the "WiX v3 - Visual Studio 2022" extension).

## 📂 Deployed File Structure
When installed or successfully compiled, the deployment directory will contain the following critical components:

* `windower.exe` — The lightweight, native bootstrapper. This is the main executable users launch to start the application.
* `windower.dll` — The core .NET 10 application payload containing all the UI, auto-updater, and game launching logic.
* `windower.runtimeconfig.json` — The configuration file that tells `windower.exe` exactly which .NET 10 framework resources to allocate.
* `core.dll` — The heavy-lifting C++ backend. This library is injected into FFXI to intercept network packets, hook DirectX, and provide the internal Lua environment.
* `paths.xml` — A configuration file required by the C++ core to correctly locate the engine's internal directories.
* `modules/` — A directory containing the engine's core Lua wrapper scripts (like `chat.lua` and `command.lua`) that bridge the gap between user addons and the C++ backend.
* `packages/` — The directory where all user-created Lua addons (like custom UI elements or chat tools) are installed. Each addon resides in its own folder with a `manifest.xml` file.

## 📄 License
This software is provided under the MIT License. See the `LICENSE.md` file for details.