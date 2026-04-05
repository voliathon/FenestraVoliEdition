local ui = require('ui')
local chat = require('chat')
local command = require('command')
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
    author = 'Voliathon of Bahamut',
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

-- Cache table to prevent micro-stutters from repetitive disk I/O
local version_cache = {}

-- ============================================================================
-- 1. NATIVE PERSISTENCE 
-- ============================================================================
local function save_profiles()
    local buffer = {}
    for char_name, loaded_addons in pairs(state.profiles) do
        for addon_id, is_active in pairs(loaded_addons) do
            if is_active then
                table.insert(buffer, char_name .. ":" .. addon_id)
            end
        end
    end
    
    local final_string = table.concat(buffer, "|")
    if final_string ~= "" then 
        final_string = final_string .. "|" 
    end
    
    profile_file:write(final_string)
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
                core_command.input('/unload ' .. pkg.id)
                pkg.loaded = false
            elseif not pkg.loaded and should_be_loaded then
                core_command.input('/load ' .. pkg.id)
                pkg.loaded = true
            end
        end
    end
end

-- ============================================================================
-- 2. NETWORK LISTENER (Autoloads on Login)
-- ============================================================================
coroutine.schedule(function()
    -- Yield for 1 frame to guarantee all *_service IPC channels are broadcasting
    coroutine.sleep_frame()
    
    local packet = require('packet')
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
                    
                    load_profiles()
                    
                    if state.profiles[name] then
                        for addon_id, is_active in pairs(state.profiles[name]) do
                            if is_active then
                                core_command.input('/load ' .. addon_id)
                            end
                        end
                    end
                    
                    state.scanned = false 
                end
            end
        end
    })
end)

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
-- 4. DYNAMIC SCROLL BAR & PACKAGE SCANNER
-- ============================================================================
local scroll_view_content_height = 360
local scroll_view = ui.scroll_panel_state(430, scroll_view_content_height)

local function update_scroll_canvas()
    local required_height = 50 
    
    for _, pkg in ipairs(state.packages) do
        if pkg.category == "addon" then 
            required_height = required_height + 65 
        end
    end
    
    if state.show_dependencies then
        required_height = required_height + 50 
        for _, pkg in ipairs(state.packages) do
            if pkg.category ~= "addon" then 
                required_height = required_height + 60 
            end
        end
    end
    
    local final_height = math.max(360, required_height)
    if final_height ~= scroll_view_content_height then
        scroll_view_content_height = final_height
        scroll_view = ui.scroll_panel_state(430, scroll_view_content_height)
    end
end

local function calculate_readme_height(text)
    if not text or text == "" then return 460 end
    
    local total_height = 0
    -- Iterate through every line individually
    for line in text:gmatch("([^\n]*)\n?") do
        if line == "" then
            total_height = total_height + 15 -- Blank line spacing
        elseif line:match("^# ") then
            total_height = total_height + 45 -- xx-large font height
        elseif line:match("^## ") then
            total_height = total_height + 35 -- x-large font height
        elseif line:match("^### ") then
            total_height = total_height + 25 -- large font height
        else
            -- Standard text wrap. A 580px canvas fits about 85 chars of standard font.
            local chars = #line
            local wraps = math.max(1, math.ceil(chars / 85))
            total_height = total_height + (wraps * 20)
        end
    end
    
    -- Add 50px of bottom padding so the very last line never clips
    return math.max(460, total_height + 50)
end

local function scan_packages()
    state.packages = {}
    load_profiles() 
    
    local raw_data = core_windower.get_package_list()
    if not raw_data then return end

    for pkg_str in raw_data:gmatch("([^;]+)") do
        local raw_name, pkg_version, pkg_path, has_readme_str = pkg_str:match("([^|]+)|([^|]+)|([^|]+)|([^|]+)")
        if raw_name then
            local pkg_name = raw_name:match("^%s*(.-)%s*$")
            
            -- Bypass C++ and read the exact string directly from the manifest file
            local exact_version = pkg_version:match("^%s*([%d%.]+)") or pkg_version 
            
            -- Use Cache to prevent disk I/O micro-stutters
            if version_cache[pkg_path] then
                exact_version = version_cache[pkg_path]
            else
                local manifest_file = file.new(pkg_path .. "\\manifest.xml")
                if manifest_file:exists() then
                    local content = manifest_file:read()
                    if content then
                        -- Extract literally whatever is between the <version> tags
                        local raw_v = content:match("<version>%s*(.-)%s*</version>")
                        if raw_v then exact_version = raw_v end
                    end
                end
                version_cache[pkg_path] = exact_version
            end
            
            local cat = "addon"
            if pkg_name == "FenestraSDK" or pkg_name == "AddonManager" then
                cat = "core"
            elseif pkg_path:find("[\\/]libs[\\/]") or 
                   pkg_name:match("_service$") or 
                   pkg_name:match("_data$") or 
                   pkg_name == "mime" or 
                   pkg_name == "socket" then
                cat = "dependency"
            end

            local is_loaded = (state.profiles[state.current_character] and state.profiles[state.current_character][pkg_name] == true)
            
            table.insert(state.packages, {
                id = pkg_name, 
                name = pkg_name,
                version = exact_version, 
                path = pkg_path,
                has_readme = (has_readme_str == "1"), 
                loaded = is_loaded,
                category = cat
            })
        end
    end
    
    table.sort(state.packages, function(a, b) return a.name < b.name end)
    state.scanned = true
    
    update_scroll_canvas()
end

-- ============================================================================
-- 5. UI RENDERING 
-- ============================================================================
local market_window = ui.window_state()
market_window.title = "Addon Manager"
market_window.size = {width = 450, height = 550}
market_window.resizable = false
market_window.visible = false

local readme_window = ui.window_state()
readme_window.title = "Readme Viewer"
readme_window.size = {width = 600, height = 500}
readme_window.resizable = false
readme_window.visible = false
local readme_scroll = ui.scroll_panel_state(580, 460)

ui.display(function()
    local success, err = pcall(function()

        if state.show_ui then
            market_window.visible = true
            if not state.scanned then scan_packages() end
            
            local window_still_open = ui.window(market_window, function(layout)
                
                layout:label("ACTIVE PROFILE: " .. state.current_character:upper(), ui.color.skin_accent)
                layout:space(5)
                
                local clicked_dd, _ = layout:check("chk_dd_toggle", "⇄ Switch Profile", state.show_dropdown)
                if clicked_dd then state.show_dropdown = not state.show_dropdown end
                
                -- Track alt profiles for dynamic layout sizing
                local alt_profiles = {}
                for char_name, _ in pairs(state.profiles) do
                    if char_name ~= state.current_character then
                        table.insert(alt_profiles, char_name)
                    end
                end
                
                if state.show_dropdown then
                    if #alt_profiles > 0 then
                        layout:space(5)
                        -- NO MORE SCROLLBOX: Just clean, inline buttons
                        for _, char_name in ipairs(alt_profiles) do
                            if layout:button("btn_prof_"..char_name, "   Load " .. char_name .. "'s Profile", false) then
                                state.current_character = char_name
                                state.show_dropdown = false
                                state.scanned = false
                            end
                        end
                        layout:space(5)
                    else
                        layout:label("  No other profiles found.", ui.color.system_disabled)
                    end
                end
                
                layout:space(5)
                layout:label("──────────────────────────────────────────", ui.color.system_gray)
                layout:space(5)

                -- DYNAMIC VIEWPORT ALGORITHM
                -- Base height stretches all the way to the bottom of the 550px window
                local viewport_height = 440 
                if state.show_dropdown and #alt_profiles > 0 then
                    -- If profiles are open, shrink the list by ~30px per profile so it doesn't get pushed out of the window
                    viewport_height = math.max(200, 440 - (#alt_profiles * 30) - 20)
                end

                layout:height(viewport_height):scroll_panel(scroll_view, function(canvas)
                    
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
                                    local raw_text = core_windower.get_package_readme(pkg.id) or ""
                                    state.readme_content = parse_markdown_to_windower(raw_text)
                                    
                                    -- Recalculate and reset the scroll canvas for dependencies
                                    local dynamic_h = calculate_readme_height(raw_text)
                                    readme_scroll = ui.scroll_panel_state(580, dynamic_h)
                                    
                                    state.show_readme = true
                                end
                            end
                            canvas:space(25) 
                        end
                    end
                    
                    canvas:space(10)
                    canvas:label("──────────────────────────────────────────", ui.color.system_gray)
                    canvas:space(5)
                    
                    local clicked_dep, _ = canvas:check("chk_dep_toggle", "Core Systems & Libraries", state.show_dependencies)
                    if clicked_dep then 
                        state.show_dependencies = not state.show_dependencies 
                        update_scroll_canvas()
                    end
                    
                    if state.show_dependencies then
                        canvas:space(10)
                        for index, pkg in ipairs(state.packages) do
                            if pkg.category == "core" or pkg.category == "dependency" then
                                canvas:label(pkg.name .. "  v" .. pkg.version, ui.color.system_gray)
                                
                                if pkg.category == "core" then
                                    canvas:label("  🔒 CORE SYSTEM", ui.color.system_white)
                                else
                                    canvas:label("  [ LIBRARY ]", ui.color.system_disabled)
                                end
                                
                                if pkg.has_readme then
                                    local clicked_readme = canvas:button("btn_rm_" .. pkg.id, "📄 ReadMe", false)
                                    if clicked_readme then
                                        state.readme_title = pkg.name .. " Readme"
                                        local raw_text = core_windower.get_package_readme(pkg.id) or ""
                                        state.readme_content = parse_markdown_to_windower(raw_text)
                                        
                                        -- Recalculate and reset the scroll canvas for dependencies
                                        local dynamic_h = calculate_readme_height(raw_text)
                                        readme_scroll = ui.scroll_panel_state(580, dynamic_h)
                                        
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
            
            local rm_still_open = ui.window(readme_window, function(layout)
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
        chat.print("Marketplace UI Crash: " .. tostring(err), ui.color.system_error) 
    end
end)

-- ============================================================================
-- 6. COMMAND ROUTER
-- ============================================================================
command.register('addon', function(args)
    local success, err = pcall(function()
        if args[1] == "rescan" then
            scan_packages()
            chat.print("AddonManager: Addons rescanned.", ui.color.skin_accent)
        elseif args[1] == "profile" and args[2] then
            switch_profile(args[2])
            state.scanned = false
        else
            state.show_ui = not state.show_ui
            if state.show_ui then state.scanned = false end 
        end
    end)
    if not success then chat.print("Command Crash: " .. tostring(err), 167) end
end)

addon.unload = function()
    chat.print("AddonManager has been unloaded.", ui.color.system_white)
end

chat.print("----------------------------------------------------", 207)
chat.print("AddonManager Initialized. Type /addon to continue...", 207)
chat.print("----------------------------------------------------", 207)
return addon