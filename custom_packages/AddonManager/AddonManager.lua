local fw = require('FenestraSDK')
local packet = require('packet')
local file = require('file')
local ffi = require('ffi')
local core_windower = require('core.windower')
local core_command = require('core.command')

-- Explicitly binding the sandboxed base libraries
local table = require('table')
local string = require('string')
local math = require('math')

local profile_file = file.new('profiles.txt')

local addon = {
    name = 'AddonManager',
    author = 'You',
    version = '1.1'
}

local state = {
    show_ui = false,
    packages = {},
    scanned = false,
    show_readme = false,
    readme_title = "Readme",
    readme_content = "",
    
    current_character = "Global", 
    character_locked = false, 
    profiles = {},
    show_dropdown = false,
    show_dependencies = false 
}

-- ============================================================================
-- 1. NATIVE PERSISTENCE 
-- ============================================================================
local function save_profiles()
    local output = ""
    for char_name, loaded_addons in pairs(state.profiles) do
        for addon_id, is_active in pairs(loaded_addons) do
            if is_active then
                output = output .. char_name .. ":" .. addon_id .. "|"
            end
        end
    end
    profile_file:write(output)
end

local function load_profiles()
    state.profiles = {}
    local raw_data = ""
    
    if profile_file:exists() then
        raw_data = profile_file:read()
    end
    
    if raw_data and raw_data ~= "" then
        for entry in raw_data:gmatch("([^|]+)") do
            local char_name, addon_id = entry:match("([^:]+):([^:]+)")
            if char_name and addon_id then
                if not state.profiles[char_name] then state.profiles[char_name] = {} end
                state.profiles[char_name][addon_id] = true
            end
        end
    end
    
    if not state.profiles[state.current_character] then 
        state.profiles[state.current_character] = {} 
        save_profiles()
    end
end

local function switch_profile(character_name)
    state.current_character = character_name
    state.character_locked = true 
    
    if not state.profiles[state.current_character] then 
        state.profiles[state.current_character] = {} 
    end
    
    for _, pkg in ipairs(state.packages) do
        if pkg.category == "addon" then
            local should_be_loaded = state.profiles[state.current_character][pkg.id] or false
            
            if pkg.loaded and not should_be_loaded then
                fw.command.input('/unload ' .. pkg.id)
                pkg.loaded = false
            elseif not pkg.loaded and should_be_loaded then
                fw.command.input('/load ' .. pkg.id)
                pkg.loaded = true
            end
        end
    end
end

-- ============================================================================
-- 2. NETWORK LISTENER (Bypassing broken services)
-- ============================================================================
packet.incoming:register_init({
    [{0x00A}] = function(p)
        if p and p.player_name then
            local name = p.player_name
            
            if type(name) == 'cdata' then
                name = ffi.string(name)
            else
                name = tostring(name)
            end
            
            if name ~= "" and name:lower() ~= "global" and state.current_character ~= name then
                state.current_character = name
                state.character_locked = true 
                
                -- Read the profiles.txt file from the hard drive immediately
                load_profiles()
                
                -- Directly fire the load commands for this character's active addons
                if state.profiles[name] then
                    for addon_id, is_active in pairs(state.profiles[name]) do
                        if is_active then
                            core_command.input('/load ' .. addon_id)
                        end
                    end
                end
                
                -- Flag the UI to rescan so it matches reality next time you open it
                state.scanned = false 
            end
        end
    end
})

-- ============================================================================
-- 3. MARKDOWN TRANSLATOR
-- ============================================================================
local function parse_markdown_to_windower(text)
    if not text or text == "" then return "No content found." end
    text = text:gsub("^# (.-)\n", "[%1]{size:xx-large weight:bold color:skin_accent}\n")
    text = text:gsub("\n# (.-)\n", "\n[%1]{size:xx-large weight:bold color:skin_accent}\n")
    text = text:gsub("^## (.-)\n", "[%1]{size:x-large weight:bold}\n")
    text = text:gsub("\n## (.-)\n", "\n[%1]{size:x-large weight:bold}\n")
    text = text:gsub("^### (.-)\n", "[%1]{size:large weight:bold color:system_gray}\n")
    text = text:gsub("\n### (.-)\n", "\n[%1]{size:large weight:bold color:system_gray}\n")
    text = text:gsub("%*%*(.-)%*%-*", "[%1]{weight:bold}")
    text = text:gsub("%*(.-)%*", "[%1]{style:italic}")
    text = text:gsub("`(.-)`", "[%1]{color:system_white}")
    return text
end

-- ============================================================================
-- 4. NATIVE C++ PACKAGE SCANNER (Updated Classification)
-- ============================================================================
local function scan_packages()
    state.packages = {}
    load_profiles() 
    
    local raw_data = core_windower.get_package_list()
    if not raw_data then return end

	for pkg_str in raw_data:gmatch("([^;]+)") do
        local raw_name, pkg_version, pkg_path, has_readme_str = pkg_str:match("([^|]+)|([^|]+)|([^|]+)|([^|]+)")
        if raw_name then
            local pkg_name = raw_name:match("^%s*(.-)%s*$")
            
            -- Strip the C++ trailing garbage and isolate the clean numbers
            pkg_version = pkg_version:match("^%s*([%d%.]+)") or pkg_version
            
            local cat = "addon"
            if pkg_name == "FenestraSDK" or pkg_name == "FenestraMarket" then
                cat = "core"
            elseif pkg_path:find("[\\/]libs[\\/]") or pkg_name:match("_service$") or pkg_name:match("_data$") then
                cat = "dependency"
            end

            local is_loaded = (state.profiles[state.current_character] and state.profiles[state.current_character][pkg_name] == true)
            
            table.insert(state.packages, {
                id = pkg_name, 
                name = pkg_name,
                version = pkg_version,
                path = pkg_path,
                has_readme = (has_readme_str == "1"), 
                loaded = is_loaded,
                category = cat
            })
        end
    end
    
    table.sort(state.packages, function(a, b) return a.name < b.name end)
    state.scanned = true
end

-- ============================================================================
-- 5. UI RENDERING (Addon Manager Polish)
-- ============================================================================
local market_window = fw.ui.window_state()
market_window.title = "Addon Manager"
market_window.size = {width = 450, height = 550} -- Increased base height
market_window.visible = false

-- Adjusted scroll panel sizes to ensure the bar triggers
local scroll_view = fw.ui.scroll_panel_state(420, 360) 
local profile_scroll = fw.ui.scroll_panel_state(420, 80)

local readme_window = fw.ui.window_state()
readme_window.title = "Readme Viewer"
readme_window.size = {width = 600, height = 500}
readme_window.visible = false
local readme_scroll = fw.ui.scroll_panel_state(580, 460)

fw.ui.display(function()
    local success, err = pcall(function()

        if state.show_ui then
            market_window.visible = true
            if not state.scanned then scan_packages() end
            
            local window_still_open = fw.ui.window(market_window, function(layout)
                
                layout:label("ACTIVE PROFILE: " .. state.current_character:upper(), fw.ui.color.skin_accent)
                layout:space(5)
                
                local clicked_dd, _ = layout:check("chk_dd_toggle", "Manage Profiles", state.show_dropdown)
                if clicked_dd then state.show_dropdown = not state.show_dropdown end
                
                if state.show_dropdown then
                    local alt_profiles = {}
                    for char_name, _ in pairs(state.profiles) do
                        if char_name ~= state.current_character then
                            table.insert(alt_profiles, char_name)
                        end
                    end
                    
                    if #alt_profiles > 0 then
                        local dynamic_height = math.min(#alt_profiles * 30 + 10, 100)
                        layout:height(dynamic_height):scroll_panel(profile_scroll, function(p_canvas)
                            for _, char_name in ipairs(alt_profiles) do
                                if p_canvas:button("btn_prof_"..char_name, "Switch to " .. char_name, false) then
                                    state.current_character = char_name
                                    state.show_dropdown = false
                                    state.scanned = false
                                end
                            end
                        end)
                    else
                        layout:label("  No other profiles found.", fw.ui.color.system_disabled)
                    end
                end
                
                layout:space(5)
                layout:label("──────────────────────────────────────────", fw.ui.color.system_gray)
                layout:space(5)

                -- The Main Scrollable Grid
                layout:height(360):scroll_panel(scroll_view, function(canvas)
                    
                    -- Render User Addons First
                    for index, pkg in ipairs(state.packages) do
                        if pkg.category == "addon" then
                            canvas:label(pkg.name .. "  v" .. pkg.version)
                            
                            local tgl_label = pkg.loaded and "  🟢 Active" or "  ⚪ Offline"
                            local clicked, _ = canvas:check("tgl_" .. pkg.id, tgl_label, pkg.loaded)
                            
                            if clicked then
                                pkg.loaded = not pkg.loaded
                                if pkg.loaded then
                                    core_command.input('/load ' .. pkg.id) 
                                    state.profiles[state.current_character][pkg.id] = true 
                                else
                                    core_command.input('/unload ' .. pkg.id)
                                    state.profiles[state.current_character][pkg.id] = nil 
                                end
                                save_profiles() 
                            end

                            if pkg.has_readme then
                                local clicked_readme = canvas:button("btn_rm_" .. pkg.id, "📄 ReadMe", false)
                                if clicked_readme then
                                    state.readme_title = pkg.name .. " Readme"
                                    state.readme_content = parse_markdown_to_windower(core_windower.get_package_readme(pkg.id))
                                    state.show_readme = true
                                end
                            else
                                canvas:label("  📄 No Readme Available", fw.ui.color.system_disabled)
                            end
                            canvas:space(25) 
                        end
                    end
                    
                    canvas:space(10)
                    canvas:label("──────────────────────────────────────────", fw.ui.color.system_gray)
                    canvas:space(5)
                    
                    local clicked_dep, _ = canvas:check("chk_dep_toggle", "Core Systems & Libraries", state.show_dependencies)
                    if clicked_dep then state.show_dependencies = not state.show_dependencies end
                    
                    -- Render Core/Libraries if toggled
                    if state.show_dependencies then
                        canvas:space(10)
                        for index, pkg in ipairs(state.packages) do
                            if pkg.category == "core" or pkg.category == "dependency" then
                                canvas:label(pkg.name .. "  v" .. pkg.version, fw.ui.color.system_gray)
                                
                                if pkg.category == "core" then
                                    canvas:label("  🔒 CORE SYSTEM", fw.ui.color.system_white)
                                else
                                    canvas:label("  [ LIBRARY ]", fw.ui.color.system_disabled)
                                end
                                
                                if pkg.has_readme then
                                    local clicked_readme = canvas:button("btn_rm_" .. pkg.id, "📄 ReadMe", false)
                                    if clicked_readme then
                                        state.readme_title = pkg.name .. " Readme"
                                        state.readme_content = parse_markdown_to_windower(core_windower.get_package_readme(pkg.id))
                                        state.show_readme = true
                                    end
                                end
                                canvas:space(20) 
                            end
                        end
                    end
                    
                end) 
            end)
            if not window_still_open then state.show_ui = false end
        else
            market_window.visible = false
        end

        if state.show_readme then
            readme_window.visible = true
            readme_window.title = state.readme_title
            
            local rm_still_open = fw.ui.window(readme_window, function(layout)
                layout:height(460):scroll_panel(readme_scroll, function(canvas)
                    canvas:label(state.readme_content)
                end)
            end)
            if not rm_still_open then state.show_readme = false end
        else
            readme_window.visible = false
        end
    end)
    if not success then 
        state.show_ui = false 
        state.show_readme = false
        fw.chat.print("AddonManager UI Crash: " .. tostring(err), fw.ui.color.system_error) 
    end
end)

-- ============================================================================
-- 6. COMMAND ROUTER
-- ============================================================================
fw.command.register('addon', function(args)
    local success, err = pcall(function()
        if args[1] == "rescan" then
            scan_packages()
            fw.chat.print("AddonManager: Addons & Packages Rescanned.", fw.ui.color.skin_accent)
        elseif args[1] == "profile" and args[2] then
            switch_profile(args[2])
            state.scanned = false
        else
            state.show_ui = not state.show_ui
            if state.show_ui then state.scanned = false end 
        end
    end)
    if not success then fw.chat.print("Command Crash: " .. tostring(err), 167) end
end)

fw.chat.print("AddonManager Initialized. Type /addon", 207)

return addon