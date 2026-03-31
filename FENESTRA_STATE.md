# 🏗️ Fenestra (Voli Edition) - Master Architecture State

## 📌 Project Overview
Fenestra is a heavily modernized fork of the Windower 5 engine for FFXI, completely upgraded to run on **.NET 10** (UI/Launcher) and compiled with **MSVC v145** (C++ Core). 

## 🛑 The "Hidden Engine" Quirks (What We've Reverse-Engineered)
The Fenestra C++ core actively hides its mechanics. To successfully write and load Lua addons, we discovered the following immutable rules:
1. **The AppData Trap:** The engine silently defaults to `%LocalAppData%/Windower/packages` unless `paths.xml` is placed exactly next to the `core.dll` in the build output.
2. **The Manifest Mandate:** `package_manager.cpp` completely ignores any folder in the `packages/` directory unless it contains a valid `manifest.xml` file.
3. **The Preload Sandbox:** Legacy `require('chat')` is dead. The core APIs (`chat.lua`, `command.lua`) are dynamically injected into the C++ memory and preloaded globally as `core.chat` and `core.command`.
4. **The Pedantic Router:** The `core.command` module enforces mutually exclusive routing. If you register a base command (e.g., `/hello`), attempting to register a sub-command (e.g., `/hello ping`) will intentionally crash the engine via an `assert(not store.nested)` trap.
5. **Silent Futures:** Network tasks (like `/install`) drop their `std::future` results. If they fail, the C++ engine swallows the exception and provides zero in-game feedback.

## ✅ Current Build Pipeline
We have automated the Visual Studio `launcher.csproj` MSBuild targets to completely bypass the manual developer friction:
* Automatically copies `paths.xml` to `build\bin\Release\`.
* Automatically provisions an empty `packages/` deployment folder.
* Automatically syncs user-created addons from the repository's root `custom_packages/` folder directly into the game's deployment directory.

## 🚀 The 4-Pillar Re-Architecture Roadmap (Active Plan)
The current goal is to strip the hostility out of the engine and make building a "Hello World" addon frictionless. We are actively executing this 4-part roadmap:

### Pillar 1: The API Exporter
* **Goal:** Make the invisible engine code visible to IDEs (like VS Code) for IntelliSense and autocomplete.
* **Action:** Add an MSBuild target to copy the raw `core/src/addon/modules/*.lua` files into a developer-facing `sdk/` folder during compilation.

### Pillar 2: The Boilerplate Nuke (C++ Manifest Fix)
* **Goal:** Eliminate the need to write `manifest.xml` for simple, single-file addons.
* **Action:** Modify `populate_installed_packages()` in `package_manager.cpp`. If a folder contains a `.lua` file matching the folder name but lacks an XML file, the C++ core should dynamically generate a basic manifest in memory.

### Pillar 3: The Engine Feedback Loop
* **Goal:** Stop silent failures.
* **Action:** Edit `command_handlers.cpp`. Inject `core::output` success logs into `/pkg reload`. `co_await` the dropped network futures so exceptions print red text to the game chat instead of vanishing.

### Pillar 4: The Clean Facade & Router Rewrite
* **Goal:** Fix the pedantic command assertions and simplify imports.
* **Action:** Create a unified `fenestra.lua` SDK wrapper that securely interacts with `core.*` memory objects, and rewrite the internal `command.lua` to gracefully handle both base commands and sub-commands without crashing.