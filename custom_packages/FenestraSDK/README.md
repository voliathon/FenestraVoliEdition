# FenestraSDK
## Master API Facade (Voli Edition)

The Fenestra SDK is the foundational library required for modern UI development. It wraps the raw, immediate-mode C++ `core` engine calls into a safe, clean, and reactive object-oriented Lua API.

### Core Modules
* **fw.ui:** A reactive, immediate-mode GUI builder supporting grid layouts, scroll panels, and primitive rendering.
* **fw.chat:** Safe injection of colored text into the local game client.
* **fw.command:** Command registration and routing.
* **fw.env:** Access to sandboxed engine paths, screen dimensions, and native C++ package tracking.
* **fw.event:** Hook into frame rendering, network packets, and system events.

### Developer Warning
**Do not unload this package.** Unloading the SDK while dependent user interfaces are active will result in immediate nil-reference crashes across the Lua state and will crash the UI rendering coroutines.