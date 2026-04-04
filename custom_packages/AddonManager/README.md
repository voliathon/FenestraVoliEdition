# Addon Manager
## The Native In-Game Addon Manager

AddonManager is a lightweight, secure, and visually interactive addon manager for the Fenestra UI engine. It securely bridges the Lua sandbox with the core C++ engine to scan, load, and manage your addons entirely from within the game.

### Features
* **Secure Filesystem Access:** Utilizes native C++ memory bridges to scan the `packages` directory without compromising the Lua sandbox.
* **Hot-Swapping:** Instantly **load** or **unload** addons without restarting the client.
* **Rich Text Viewer:** Natively parses and displays `README.md` files using the engine's built-in text layout rasterizer.
* **Protected Core:** Automatically locks core system files (like the SDK) to prevent accidental unloads.

### Commands
* `/addon` - Toggles the addonplace UI window.
* `/addon rescan` - Forces the engine to rescan the hard drive for newly downloaded addons and packages.

### Installation
Ensure this addon is placed in your `packages/AddonManager/` directory. If you are setting up auto-load, ensure FenestraSDK is loaded *before* AddonManager.