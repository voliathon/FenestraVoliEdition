local fw = require('FenestraSDK')

local addon = {
    name = 'FenestraMarket',
    author = 'You',
    version = '1.0'
}

-- ============================================================================
-- 1. MOCK DATABASE (Until we build the XML parser)
-- ============================================================================
-- This simulates what the engine will eventually read from your hard drive
local installed_packages = {
    { id = "core_sdk", name = "FenestraSDK", version = "1.0", loaded = true, protected = true },
    { id = "pkg_hw", name = "HelloWorld", version = "4.0", loaded = true, protected = false },
    { id = "pkg_heal", name = "AutoHealer", version = "1.2", loaded = false, protected = false },
    { id = "pkg_map", name = "MiniMap", version = "2.1", loaded = false, protected = false }
}

local state = {
    show_ui = false
}

-- ============================================================================
-- 2. UI RENDERING (The Marketplace Grid)
-- ============================================================================
local market_window = fw.ui.window_state()
market_window.title = "Fenestra Package Manager"
market_window.size = {width = 400, height = 300}
market_window.visible = false

local scroll_view = fw.ui.scroll_panel_state(380, 400)

fw.ui.display(function()
    local success, err = pcall(function()
        if state.show_ui then
            market_window.visible = true
            
            local window_still_open = fw.ui.window(market_window, function(layout)
                
                -- Header Row
                layout:label("INSTALLED ADDONS", fw.ui.color.skin_accent)
                layout:space(10)
                
                layout:height(230):scroll_panel(scroll_view, function(canvas)
                    
                    -- Loop through every package in our database and draw a row
                    for index, pkg in ipairs(installed_packages) do
                        
                        -- Draw the Addon Name and Version
                        canvas:label(pkg.name .. "  v" .. pkg.version)
                        
                        -- THE TOGGLE LOGIC
                        if pkg.protected then
                            -- If protected, we refuse to render a toggle switch.
                            -- We render a static, non-interactable label instead.
                            canvas:label("  [ 🔒 CORE SYSTEM ]", fw.ui.color.system_white)
                        else
                            -- If not protected, render the interactive toggle
                            local tgl_label = pkg.loaded and "  🟢 Active" or "  ⚪ Offline"
                            local clicked, _ = canvas:check("tgl_" .. pkg.id, tgl_label, pkg.loaded)
                            
                            -- If the user clicks the toggle, fire the C++ command!
                            if clicked then
                                pkg.loaded = not pkg.loaded
                                
                                if pkg.loaded then
                                    fw.chat.print("Marketplace: Loading " .. pkg.name .. "...", fw.ui.color.skin_accent)
                                    -- core_command.core.execute('/load ' .. pkg.name) -- (Commented out until we wire it up)
                                else
                                    fw.chat.print("Marketplace: Unloading " .. pkg.name .. "...", fw.ui.color.system_error)
                                    -- core_command.core.execute('/unload ' .. pkg.name)
                                end
                            end
                        end
                        
                        canvas:space(15) -- Space between rows
                    end
                    
                end) -- End Grid
            end)
            
            if not window_still_open then
                state.show_ui = false
            end
        else
            market_window.visible = false
        end
    end)

    if not success then
        fw.chat.print("Marketplace UI Crash: " .. tostring(err), fw.ui.color.system_error)
        return false 
    end
end)

-- ============================================================================
-- 3. COMMAND ROUTER
-- ============================================================================
fw.command.register('market', function(args)
    local success, err = pcall(function()
        state.show_ui = not state.show_ui
    end)
    if not success then fw.chat.print("Command Crash: " .. tostring(err), 167) end
end)

addon.unload = function()
    fw.chat.print("FenestraMarket has been unloaded.", fw.ui.color.system_white)
end

fw.chat.print("FenestraMarket Initialized. Type /market", 207)

return addon