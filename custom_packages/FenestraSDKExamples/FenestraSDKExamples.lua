local fw = require('FenestraSDK')
local core_windower = require('core.windower')

local addon = {
    name = 'FenestraSDK Examples',
    author = 'You',
    version = '1.0.1'
}

-- ============================================================================
-- 1. STATE & IPC (Inter-Process Communication)
-- ============================================================================
local state = {
    show_ui = false,
    packet_count = 0,
    chat_lines_seen = 0,
    slider_value = 50,
    checkbox_value = false,
    text_input = fw.ui.edit_state() 
}

-- Set default text for our UI input box
state.text_input.text = "Ready to scan..."

-- HOST a server on the engine network
local my_host = fw.ipc.host('fenestra_network')

-- PIN THE SERVER: Prevent Lua from deleting it when the script finishes loading!
fw.memory.pin(my_host) 

my_host.env = {
    get_slider_data = function() return state.slider_value end
}

-- ============================================================================
-- 2. BACKGROUND HOOKS (Chat & Packets)
-- ============================================================================

-- Hook incoming chat to count how many lines of text hit the log
fw.chat.on_text_added(function(text_obj)
    state.chat_lines_seen = state.chat_lines_seen + 1
end)

-- Hook outgoing packets (Client -> Server)
fw.packet.on_outgoing(function(packet)
    state.packet_count = state.packet_count + 1
end)

-- ============================================================================
-- 3. ADVANCED UI RENDERING
-- ============================================================================
local main_window = fw.ui.window_state()
main_window.title = "FenestraSDK Showcase"
main_window.size = {width = 350, height = 400}
main_window.visible = false

-- Create a scroll panel so we can fit tons of widgets in a small window
local scroll_view = fw.ui.scroll_panel_state(310, 500)

fw.ui.display(function()
    local success, err = pcall(function()
        if state.show_ui then
            main_window.visible = true
            
            -- Capture the window state in a local variable instead of overwriting our global state
            local window_still_open = fw.ui.window(main_window, function(layout)
                
                layout:height(330):scroll_panel(scroll_view, function(canvas)
                    
                    canvas:label("FFXI Version: " .. tostring(fw.env.version))
                    canvas:label("System Date: " .. fw.os.date("%Y-%m-%d %H:%M:%S"))
                    canvas:space(15)
                    
                    canvas:label("Outgoing Packets: " .. state.packet_count)
                    canvas:label("Chat Lines Read: " .. state.chat_lines_seen)
                    canvas:space(15)

                    local clicked, _ = canvas:check("my_check", " Enable Super Mode", state.checkbox_value)
                    if clicked then state.checkbox_value = not state.checkbox_value end
                    
                    canvas:space(10)

                    canvas:label("Example Slider:")
                    state.slider_value = canvas:slider("my_slider", state.slider_value, 0, 100)
                    canvas:progress(state.slider_value, 100)
                    
                    canvas:space(15)

                    canvas:label("Custom Message:")
                    canvas:edit(state.text_input)
                    canvas:space(10)

                    if canvas:width(180):button("Read IPC Server Data") then
                        local target_addon = fw.env.package_name
                        local my_client = fw.ipc.connect(target_addon, 'fenestra_network')
                        
                        local network_val = my_client:call(function()
                            return get_slider_data()
                        end)
                        
                        fw.chat.print("IPC Client received slider value: " .. tostring(network_val), fw.ui.color.skin_accent)
                    end

                end) -- End Scroll Area
                
                layout:space(5)

                if layout:width(180):button("Close Dashboard") then
                    state.show_ui = false -- We turn it off manually here
                end
            end)
            
            -- If the C++ engine says the X was clicked, we honor it.
            -- Otherwise, we leave state.show_ui alone so our custom button works!
            if not window_still_open then
                state.show_ui = false
            end
            
        else
            main_window.visible = false
        end
    end)

    if not success then
        fw.chat.print("UI Crash: " .. tostring(err), fw.ui.color.system_error)
        return false 
    end
end)

-- ============================================================================
-- 4. COMMAND ROUTER (With Serializer & Memory APIs)
-- ============================================================================
fw.command.register('hw', function(args)
    local cmd = args[1] and args[1]:lower() or ""

    local success, err = pcall(function()
        if cmd == 'ui' then
            state.show_ui = not state.show_ui
            
        elseif cmd == 'binary' then
            -- SERIALIZER API: Convert a Lua table into raw machine bytes
            local my_data = { weapon = "Test Weapon", damage = 313 }
            local binary_string = fw.serializer.serialize(my_data)
            fw.chat.print("Serialized table to binary! Length: " .. #binary_string .. " bytes", 207)
            
        elseif cmd == 'scan' then
            -- MEMORY API: Search FFXI's live RAM for a dummy byte pattern
            local dummy_sig = "\x8B\x0D\x00\x00\x00\x00\x85\xC9\x74\x0A"
            local pointer = fw.memory.scan(dummy_sig)
            if pointer then
                fw.chat.print("Found signature in memory!", 207)
            else
                fw.chat.print("Signature not found (Expected).", 167)
            end
            
        else
            fw.chat.print("FenestraSDK Example Commands:", fw.ui.color.system_white)
            fw.chat.print(" /hw ui     - Open the massive UI Dashboard")
            fw.chat.print(" /hw binary - Test the IPC binary serializer")
            fw.chat.print(" /hw scan   - Test the live RAM scanner")
        end
    end)

    if not success then
        fw.chat.print("Command Crash: " .. tostring(err), fw.ui.color.system_error)
    end
end)

-- ============================================================================
-- 5. LIFECYCLE HOOKS
-- ============================================================================
addon.unload = function()
    -- This runs automatically right before the engine destroys the addon
    fw.chat.print("FenestraSDK Examples has been unloaded cleanly.", fw.ui.color.system_white)
end

fw.chat.print("FenestraSDK Examples Loaded! Type /hw", 207)

return addon