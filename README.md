# Windower 5 Launcher (Voli Edition .NET8)

A modernized, high-performance launcher and injector for Final Fantasy XI and the PlayOnline Viewer. 

This project manages game profiles, automatically handles required system dependencies (like DirectPlay), provides a seamless User Interface for configuration, and securely injects the core Windower DLLs into the game process.

## Features

* **Profile Management:** Create, save, and manage multiple launch profiles with custom resolutions, UI scales, and executable arguments.
* **Modern .NET 8 Architecture:** Fully upgraded to .NET 8.0 for improved performance, security, and cross-platform compatibility foundations.
* **Smart Injection:** Bypasses standard execution to launch the game in a suspended state, allowing the Windower core to inject seamlessly before the game boots.
* **Secure Privilege Elevation:** Uses a robust, custom Named-Pipe RPC system to safely request Administrator privileges only when necessary (e.g., for writing to protected directories or injecting into elevated processes).
* **Automatic Dependency Resolution:** Detects missing Windows features like DirectPlay and automatically prompts the user to install them via DISM.
* **Steam Integration:** Automatically detects Steam installations of Final Fantasy XI and routes the launch sequence through the correct AppID.
* **Integrated Crash Reporting:** Captures unhandled exceptions, generates detailed environment logs, creates crash dumps, and packages them into clean `.zip` reports for debugging.

## Prerequisites

To run or build the launcher, you will need the following installed:

* **OS:** Windows 10 or later (64-bit recommended)
* **Runtime:** [.NET 8.0 Desktop Runtime](https://dotnet.microsoft.com/en-us/download/dotnet/8.0)
* **IDE (For Developers):** Visual Studio 2022 (Version 17.8 or later)

## Building the Project

The build system has been modernized to use SDK-style projects while maintaining predictable output directories.

1. Open the solution file in Visual Studio 2022.
2. Ensure your active configuration is set to **Debug** or **Release** (Any CPU).
3. Right-click the Solution in the Solution Explorer and select **Restore NuGet Packages**.
4. Click **Build > Rebuild Solution**.

All compiled binaries, including the launcher and core DLLs, will be output directly to the `build\bin\<Configuration>\` directory.

## Recent Technical Updates

* **Networking Modernization:** Replaced obsolete `WebRequest` and `WebClient` APIs with a static, high-performance `HttpClient` implementation for the auto-updater.
* **Pathing & Reflection:** Migrated away from legacy `Assembly.EscapedCodeBase` and `Uri` wrappers in favor of direct `.Location` and `Environment.ProcessPath` calls.
* **Security & Execution:** Updated `Process.Start` calls to explicitly utilize `UseShellExecute = true` where appropriate, ensuring User Account Control (UAC) prompts and OS-level file associations function correctly under .NET 8 security policies.
* **Inter-Process Communication (IPC):** Hardened the Named Pipe RPC system. `BinaryFormatter` is now strictly configured to safely pass plain-text method signatures and primitive arguments across the pipe, bypassing modern .NET restrictions on serializing reflection objects like `MethodInfo`.


## 📜 License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.
