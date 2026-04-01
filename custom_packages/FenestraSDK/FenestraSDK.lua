-- ============================================================================
-- Fenestra SDK (Voli Edition) - Master API Facade
-- ============================================================================

local core_chat       = require('core.chat')
local core_command    = require('core.command')
local core_packet     = require('core.packet')
local core_event      = require('core.event')
local core_channel    = require('core.channel')
local core_scanner    = require('core.scanner')
local core_hash       = require('core.hash')
local core_class      = require('core.class')
local native_os       = require('os')
local core_pin        = require('core.pin')
local core_serializer = require('core.serializer')
local core_ui         = require('core.ui')
local core_unicode    = require('core.unicode')
local core_windower   = require('core.windower')

local fw = {
    chat = {},
    command = {},
    packet = {},
    event = {},
    ipc = {},
    memory = {},
    os = {},
    unicode = {},
    serializer = {},
    env = {}
}

-- ============================================================================
-- 1. CHAT API
-- ============================================================================

--- Prints a message to the local game chat log.
---@param text string|number The message to print.
---@param color? integer The standard color code (Defaults to 207 / Pink).
function fw.chat.print(text, color)
    color = color or 207
    core_chat.add_text(tostring(text), color, false)
end

--- Registers a callback to intercept and modify incoming chat text.
---@param callback fun(text_obj: table)
function fw.chat.on_text_added(callback)
    core_chat.text_added:register(callback)
end

-- ============================================================================
-- 2. COMMAND API
-- ============================================================================
local active_commands = {}

--- Registers a new root slash-command with the game engine.
--- Automatically catches and routes sub-commands safely.
---@param command_name string The base command without the slash.
---@param callback fun(args: string[]) The function to execute.
function fw.command.register(command_name, callback)
    if not active_commands[command_name] then
        local cmd_obj = core_command.new(command_name)
        
        -- Pin the object to survive Garbage Collection
        fw.memory.pin(cmd_obj)
        
        -- THE MAGIC FIX: We pass '[string]*' to the C++ core.
        -- This forces the strict router to accept all sub-commands without crashing.
        cmd_obj:register(function(...)
            local args = {...}
            if active_commands[command_name] then
                active_commands[command_name](args)
            end
        end, '[string]*') 
    end
    
    active_commands[command_name] = callback
end

-- ============================================================================
-- 3. PACKET API
-- ============================================================================

--- Creates a new raw packet object.
---@param id integer The Packet ID.
---@param data string The raw binary data.
---@return table FenestraPacket
function fw.packet.new(id, data)
    return core_packet.new(id, data)
end

--- Injects a constructed packet into the incoming stream (Server -> Client).
---@param packet table
function fw.packet.inject_incoming(packet)
    core_packet.inject_incoming(packet)
end

--- Injects a constructed packet into the outgoing stream (Client -> Server).
---@param packet table
function fw.packet.inject_outgoing(packet)
    core_packet.inject_outgoing(packet)
end

--- Hooks into the incoming packet stream. Use this to read or block server packets.
---@param callback fun(packet: table)
function fw.packet.on_incoming(callback)
    core_packet.incoming:register(callback)
end

--- Hooks into the outgoing packet stream. Use this to read or block client packets.
---@param callback fun(packet: table)
function fw.packet.on_outgoing(callback)
    core_packet.outgoing:register(callback)
end

-- ============================================================================
-- 4. IPC & EVENTS (INTER-PROCESS COMMUNICATION)
-- ============================================================================

--- Creates a new event channel.
---@return table event_server
function fw.event.new()
    return core_event.new()
end

--- Creates a new server channel so other addons can communicate with this one.
---@param name string The name of the channel to broadcast.
---@return table server
function fw.ipc.host(name)
    return core_channel.new(name)
end

--- Connects to an IPC channel hosted by another addon.
---@param target_addon string The name of the addon hosting the channel.
---@param channel_name string The specific channel to connect to.
---@return table client
function fw.ipc.connect(target_addon, channel_name)
    return core_channel.get(target_addon, channel_name)
end

--- Registers a callback to run exactly when the addon is unloaded or reloaded.
---@param callback fun()
function fw.event.on_unload(callback)
    -- Hook into the core engine's unload broadcast
    core_event.register('unload', callback)
end

-- ============================================================================
-- 5. MEMORY & GC API (SCANNER / PIN)
-- ============================================================================

--- Scans active RAM for a specific byte signature.
---@param signature string The byte signature to search for.
---@param module? string The DLL to scan inside (Defaults to 'ffximain.dll').
---@return userdata? pointer A raw C-pointer to the memory address.
function fw.memory.scan(signature, module)
    return core_scanner.scan(signature, module)
end

--- Pins a Lua object in memory, preventing the Garbage Collector from deleting it.
---@param value any The object to pin.
---@return any value The pinned object.
function fw.memory.pin(value)
    return core_pin(value)
end

-- ============================================================================
-- 6. OS & TIME API
-- ============================================================================

--- Formats a time value into a timezone-aware string (C++ Backend).
---@param format string Date format string (e.g., "%Y-%m-%d").
---@param time? number Defaults to current time.
---@param time_zone? string Optional Timezone (e.g., "Etc/UTC").
---@return string|table
function fw.os.date(format, time, time_zone)
    return native_os.date(format, time, time_zone)
end

--- Returns the current high-precision time from the C++ engine.
---@param t? table Optional date table to convert to time.
---@return number time
function fw.os.time(t)
    return native_os.time(t)
end

--- Calculates the difference in seconds between two times.
---@param t1 number Time 1
---@param t2 number Time 2
---@return number difference
function fw.os.difftime(t1, t2)
    return native_os.difftime(t1, t2)
end

-- ============================================================================
-- 7. UNICODE & TEXT ENCODING (FFXI SAFE)
-- ============================================================================

--- Converts a standard UTF-8 string to Shift-JIS (Required for FFXI Chat & Packets).
---@param utf8_string string
---@return string shift_jis_string, integer length
function fw.unicode.to_shift_jis(utf8_string)
    return core_unicode.to_shift_jis(utf8_string)
end

--- Converts an FFXI Shift-JIS string back to readable UTF-8.
---@param shift_jis_string string
---@return string utf8_string, integer length
function fw.unicode.from_shift_jis(shift_jis_string)
    return core_unicode.from_shift_jis(shift_jis_string)
end

--- Contains FFXI specific symbols (Fire, Ice, Light, Auto-Translate Brackets).
fw.unicode.symbols = core_unicode.symbol

-- ============================================================================
-- 8. SERIALIZER
-- ============================================================================

--- Serializes a Lua table/object into a binary string for IPC transfer.
---@param value any The data to serialize.
---@param preserve_upvalues? boolean
---@return string binary_data
function fw.serializer.serialize(value, preserve_upvalues)
    return core_serializer.serialize(value, preserve_upvalues)
end

--- Deserializes a binary string back into a Lua table/object.
---@param str string The binary data.
---@param preserve_upvalues? boolean
---@return any value
function fw.serializer.deserialize(str, preserve_upvalues)
    return core_serializer.deserialize(str, preserve_upvalues)
end

-- ============================================================================
-- 9. ENVIRONMENT & SYSTEM
-- ============================================================================

--- Read-only table containing the engine's current environment state.
fw.env = {
    version = core_windower.version,
    client_path = core_windower.client_path,
    settings_path = core_windower.settings_path,
    user_path = core_windower.user_path,
    package_path = core_windower.package_path,
    package_name = core_windower.package_name or '<script>',
    client_size = core_windower.settings.client_size,
    ui_size = core_windower.settings.ui_size
}

--- Hashes a string or value using the engine's native hashing algorithm.
function fw.env.hash(value, seed) return core_hash(value, seed) end

--- Extracts the class name from an object's metatable.
function fw.env.class(value) return core_class(value) end


-- ============================================================================
-- 10. UI & RENDERING API
-- ============================================================================

---@class FenestraUI
---@field color table<string, integer> Huge table of CSS-compliant colors (e.g., ui.color.red, ui.color.skin_accent).
---@field display fun(draw: function) Starts the main coroutine rendering loop.
---@field screen fun(draw: function) Renders elements directly to the overlay canvas.
---@field window_state fun(): table Creates a new reactive state object for a window.
---@field window fun(state: table, draw: function) Renders a window to the screen.
---@field layout fun(name: string, x: number, y: number, width: number, height: number, draw: function)
fw.ui = core_ui

return fw