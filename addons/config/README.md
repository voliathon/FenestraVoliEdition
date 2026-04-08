# Config Addon for Fenestra Voli Edition

**Version:** 1.0.2.2  
**Type:** Addon  

## Overview
The `config` addon provides a native, immediate-mode GUI (IMGUI) for managing FFXI client settings in real-time. Built specifically for the Fenestra sandboxed environment, it safely injects user preferences directly into the game's memory—bypassing CPU-heavy background loops and seamlessly replicating functionality that used to be locked inside legacy DLLs.

## Features
* **Interactive Dashboard:** A fast, crash-proof user interface driven by Fenestra C++ FFI bindings.
* **Graphics Control:** * Uncap or limit your **Main Camera Framerate** (30 FPS, 60 FPS, or Unlimited).
  * Uncap or limit your **Animation Framerate** to fix stop-motion character movements at higher framerates.
  * Adjust your **Draw Distance / Clipping Plane** to render landscapes further out than the native client allows.
  * Toggle **Footstep Particles** to enable or disable visual dust clouds when running.
  * Real-time RGB Gamma slider adjustments.
  * Automatic aspect-ratio correction based on your client window size.
* **System & Audio Toggles:**
  * Toggle **Footstep Audio** to mute or unmute the physical sound volume of running independently from the visual effects.
  * Toggle the game's native **Profanity Filter**.
  * Toggle the **Auto-Disconnect** (AFK Kick) timeout.
* **Persistent Settings:** All adjustments are automatically saved to your local profile and loaded seamlessly upon login.

## Commands
Type the following directly into your game chat:

* `/cfg` - Toggles the configuration dashboard on or off.

## Technical Details (Fenestra)
This addon adheres to strict Fenestra sandboxing rules:
* **No Global Namespace:** Base Lua libraries (`math`, `string`, `table`) are explicitly required and declared in the `manifest.xml`.
* **Direct Struct Injection:** Settings like `memory.volumes.footsteps` and `graphics.animation_framerate` interact directly with the client's mapped C-structs.
* **Alias Avoidance:** The command utilizes `/cfg` to avoid any crossover or native interception by the built-in FFXI `/config` macro.
* **Rich Text UI Parsing:** Utilizes Fenestra's inline CSS color tags (e.g., `[Text]{color:tomato}`) for dashboard headers and warnings.

## Dependencies
This addon requires the following packages to be present and declared in the `manifest.xml`:
* `memory`
* `settings`
* `ui`
* `chat`
* `command`
* Base libs (`math`, `string`, `table`)

## License
Copyright © Windower Dev Team / Fenestra Voli Edition.
Provided under the conditions specified in the source code.