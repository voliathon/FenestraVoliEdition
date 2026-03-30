# Windower 5 / Fenestra (Voli Edition)

Fenestra is a modern, high-performance launcher and windower utility for Final Fantasy XI. 

This repository is a heavily modernized fork of the original Windower launcher, completely upgraded to compile natively on the latest toolchains (Visual Studio 2026 / v145) and run on the cutting-edge **.NET 10** runtime.

## 🚀 Features
* **Modern Toolchain:** Fully migrated from legacy .NET Frameworks to the modern .NET 10 ecosystem.
* **Secure IPC:** Completely overhauled inter-process communication using newline-delimited JSON.
* **C++ Core:** Compatible with modern MSVC compilers (v145) while retaining backward compatibility with the upstream v143 C++ Core Guidelines.
* **Modern Installer:** Automated `.msi` and `.zip` generation via modernized WiX v3 toolsets.
* **Automated CI/CD:** Fully automated GitHub Actions release pipeline for effortless distribution.

## 🛠️ Build Requirements
To compile this project locally, you will need the following installed:
1. **Visual Studio 2026**
2. **.NET 10 SDK** (Available via the Visual Studio Installer -> .NET Desktop Development)
3. **MSVC v143 Build Tools** (To maintain upstream compatibility with the `core.dll` and `luajit` submodules, ensure the VS 2022 v143 toolset is checked in the VS Installer).
4. **WiX Toolset v3.14** (Required only for building `installer.sln`. Install the core tools from the [WiX Releases Page](https://github.com/wixtoolset/wix3/releases) and the "WiX v3 - Visual Studio 2022" extension).

---

## 🏗️ Architecture & Migration History

### The "Two-Window" Workflow
This repository separates the core application (`fenestra.sln`) from the setup wizard (`installer.sln`) to reduce contributor friction. 
* **For daily development:** Open `fenestra.sln`. This compiles the C# launcher and C++ core instantly without requiring the WiX Toolset.
* **For packaging releases:** Open a second Visual Studio instance with `installer.sln` to wrap the compiled binaries into the `.msi` setup wizard.

### The .NET 8.0 to .NET 10.0 Migration
Upgrading from .NET 8 to the Long-Term Support (LTS) release of .NET 10 required several critical architectural shifts, primarily concerning security and inter-process communication between the UI and the elevated background process (`windower.exe`).

#### 1. The Death of `BinaryFormatter`
In .NET 10, Microsoft completely removed `BinaryFormatter` from the runtime. 
* **The Fix:** The Named Pipe IPC was entirely rewritten to use `System.Text.Json`. The `CallDescriptor` and `ResultDescriptor` structs were stripped of their old `[Serializable]` attributes and modernized to transmit plain strings and object arrays instead of raw memory graphs.

#### 2. IPC Message Framing (The EOF Deadlock)
`System.Text.Json` does not inherently know when to stop reading a continuous network stream, which caused the UI and background processes to infinitely hang waiting for an End-Of-File (EOF) signal over the Named Pipe.
* **The Fix:** Implemented manual message framing using `StreamWriter.WriteLine()` and `StreamReader.ReadLine()`. The JSON payload is serialized to a string, pushed across the pipe as a single line, and instantly flushed, preventing the deadlock.

#### 3. Strict Type Deserialization (`JsonElement`)
When the background process returned primitive types (like a `bool`), the JSON deserializer wrapped them in an anonymous `JsonElement`. This caused UI crashes (`InvalidCastException`) when attempting to read the result.
* **The Fix:** Added reflection logic to inspect the original `method.Method.ReturnType`. Before the result is handed back to the UI, the `JsonElement` is dynamically unpacked back into its native C# type.

#### 4. Stream Read Strictness (CA2022)
.NET 10 enforces strict rules regarding network and file streams. Legacy calls to `Stream.Read()` threw compiler errors because they do not guarantee the buffer is completely filled.
* **The Fix:** Replaced legacy array reads with the modern, deterministic `input.ReadExactly(buffer)` in the VDF readers.

### C++ Core Modernization
Compiling the legacy C++ game injection core on modern MSVC v145 compilers triggered strict modern C++ Core Guidelines (specifically `bounds.1` regarding pointer arithmetic). 
* **The Fix:** Rather than rewriting the highly optimized, math-heavy injection hooks to use `std::span`, Code Analysis is explicitly disabled for the `core` project during Release builds to maintain performance and upstream stability.

### Installer & Build Pipeline Modernization
* **MSBuild Engine Update:** The WiX project (`installer.wixproj`) relied on an inline C# script to stamp version numbers on the `.zip` artifacts. This was upgraded from the deprecated `v4.0` MSBuild engine to `Microsoft.Build.Tasks.Core.dll` to support VS 2026.
* **AppHost Packing:** The setup wizard (`windower.wxs`) was updated to explicitly pack the new .NET 10 AppHost artifacts (`windower.dll` and `windower.runtimeconfig.json`) alongside the native `.exe`, preventing runtime crashes on fresh installs.

---

## 📄 License
This software is provided under the MIT License. See the `LICENSE.md` file for details.