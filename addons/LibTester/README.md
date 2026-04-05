# LibTester

Welcome to the **LibTester** diagnostic tool. 

This is a lightweight developer utility designed specifically to check if your background libraries, services, and core systems are communicating correctly with the game engine. 

## How to Use

Type the following command directly into your game chat:
`/libtest <library_name>`

**Example:** `/libtest shared`

The tool will attempt to forcefully load the target library into the isolated Lua sandbox. It will instantly report back in the chat if the library successfully initialized, or if it crashed due to missing sandbox clearances or broken code.

*Note: This is a developer tool and is not required for standard gameplay.*