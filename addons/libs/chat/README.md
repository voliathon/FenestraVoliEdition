# Chat Library

The `chat` library provides a safe wrapper around the Windower 5 C++ engine's native chat injection and interception modules. It allows developers to safely output localized text arrays to the Final Fantasy XI chat log, or intercept incoming messages before they render on the screen.

---

## Functions

### `chat.print(text, [color])`
Prints a local message directly to the user's game chat log. This message is only visible to the player and is not broadcast to the server.
* **Parameters:**
  * `text` *(string | number)*: The message to print.
  * `color` *(integer, optional)*: The standard FFXI system color code. Defaults to 207 (System Pink).

### `chat.on_text_added(callback)`
Registers a listener that hooks directly into the incoming chat stream. Use this to intercept, read, modify, or block chat text before the game client renders it to the screen.
* **Parameters:**
  * `callback` *(function)*: The function to execute whenever a new chat line is processed by the engine. The callback receives a reactive text object containing the string, color, and chat mode data.