local math = require('math')
local string = require('string')
local table = require('table')

local memory = require('memory')
local settings = require('settings')
local windower = require('core.windower')
local command = require('command')
local chat = require('chat')
local ui = require('ui')

local defaults = {
    gameplay = {
        auto_target = true,
        inventory = { sort = false, type = 1 },
    },
    graphics = {
        aspect_ratio = { auto = true, value = 16 / 9 },
        gamma = { red = 1.5, green = 1.5, blue = 1.5 },
        framerate = 60,
        animation_framerate = 60,
        clipping_plane = 10,
        footstep_effects = true,
    },
    audio = {
        volume = { effects = 1.0, music = 1.0 },
        footstep_effects = true,
    },
    system = {
        auto_disconnect = { enabled = false, time = 60 },
        language_filter = { enabled = false },
    },
}

local options = settings.load(defaults)
local state = { show_ui = false }

-- ============================================================================
-- 1. MEMORY INJECTION ENGINE
-- ============================================================================
local function apply_settings()
    local graphics = memory.graphics
    local graphics_options = options.graphics

    -- Gamma
    graphics.gamma.red = graphics_options.gamma.red
    graphics.gamma.green = graphics_options.gamma.green
    graphics.gamma.blue = graphics_options.gamma.blue

    -- Aspect Ratio
    local window_aspect_ratio = (4 / 3) / (windower.settings.client_size.width / windower.settings.client_size.height)
    graphics.render.aspect_ratio = graphics_options.aspect_ratio.auto and window_aspect_ratio or ((4 / 3) / graphics_options.aspect_ratio.value)

    -- Framerate Divisors
    if graphics_options.framerate == 'unlimited' then
        graphics.render.framerate_divisor = 0
    elseif graphics_options.framerate <= 30 then
        graphics.render.framerate_divisor = 2
    else
        graphics.render.framerate_divisor = 1
    end

    if graphics_options.animation_framerate == 'unlimited' then
        graphics.animation_framerate = 0
    elseif graphics_options.animation_framerate <= 30 then
        graphics.animation_framerate = 2
    else
        graphics.animation_framerate = 1
    end

    -- Clipping Plane & Particles
    graphics.clipping_plane_entity = graphics_options.clipping_plane
    graphics.clipping_plane_map = graphics_options.clipping_plane
    graphics.footstep_effects = options.graphics.footstep_effects

    -- Audio Adjustments
    memory.volumes.footsteps = options.audio.footstep_effects and 1.0 or 0.0

    pcall(function()
        memory.volumes.music = options.audio.volume.music
        memory.volumes.effects = options.audio.volume.effects
    end)

    -- System Toggles
    local auto_disconnect = memory.auto_disconnect
    local system_options = options.system
    auto_disconnect.enabled = system_options.auto_disconnect.enabled
    auto_disconnect.timeout_time = system_options.auto_disconnect.time
    memory.language_filter.disabled = not system_options.language_filter.enabled
end

-- Staggered Initialization
coroutine.schedule(function()
    coroutine.sleep_frame()
    local success, err = pcall(apply_settings)
    if not success then
        chat.print("Config Addon Init Error: " .. tostring(err), ui.color.system_error)
    else
        chat.print("Config Loaded: Type /cfg to open.", ui.color.skin_accent)
    end
end)

-- ============================================================================
-- 2. IMGUI DASHBOARD (Highly Compacted Layout)
-- ============================================================================
local config_window = ui.window_state()
config_window.title = "Client Configuration"
config_window.size = {width = 380, height = 540} -- Significantly reduced to avoid scrollbar clipping
config_window.resizable = false
config_window.visible = false

ui.display(function()
    local success, err = pcall(function()
        if state.show_ui then
            config_window.visible = true
            
            local window_still_open = ui.window(config_window, function(layout)
                
                layout:label("[GRAPHICS]{color:skin_accent weight:bold}")
                
                -- Framerate Row
                layout:label("Camera FPS (Cur: " .. tostring(options.graphics.framerate) .. ")")
                local c30 = layout:button("btn_fps_30", "  30  ", false); layout:same_line()
                local c60 = layout:button("btn_fps_60", "  60  ", false); layout:same_line()
                local cul = layout:button("btn_fps_unl", " Unl ", false)
                if c30 then options.graphics.framerate = 30; apply_settings(); settings.save() end
                if c60 then options.graphics.framerate = 60; apply_settings(); settings.save() end
                if cul then options.graphics.framerate = 'unlimited'; apply_settings(); settings.save() end
                
                layout:space(5)
                
                -- Animation Row
                layout:label("Animation FPS (Cur: " .. tostring(options.graphics.animation_framerate) .. ")")
                local a30 = layout:button("btn_afps_30", "  30  ", false); layout:same_line()
                local a60 = layout:button("btn_afps_60", "  60  ", false); layout:same_line()
                local aul = layout:button("btn_afps_unl", " Unl ", false)
                if a30 then options.graphics.animation_framerate = 30; apply_settings(); settings.save() end
                if a60 then options.graphics.animation_framerate = 60; apply_settings(); settings.save() end
                if aul then options.graphics.animation_framerate = 'unlimited'; apply_settings(); settings.save() end

                layout:space(5)
                
                -- Graphics Sliders
                layout:label("[Draw Distance / Clipping Plane (" .. string.format("%.1f", options.graphics.clipping_plane) .. ")]{color:system_white}")
                local new_clip = layout:slider("sld_clip", options.graphics.clipping_plane, 1.0, 25.0)
                if new_clip ~= options.graphics.clipping_plane then options.graphics.clipping_plane = new_clip; apply_settings(); settings.save() end

                layout:label("[Gamma - Red (" .. string.format("%.2f", options.graphics.gamma.red) .. ")]{color:red}")
                local new_r = layout:slider("sld_gamma_r", options.graphics.gamma.red, 0.5, 3.0)
                if new_r ~= options.graphics.gamma.red then options.graphics.gamma.red = new_r; apply_settings(); settings.save() end

                layout:label("[Gamma - Green (" .. string.format("%.2f", options.graphics.gamma.green) .. ")]{color:green}")
                local new_g = layout:slider("sld_gamma_g", options.graphics.gamma.green, 0.5, 3.0)
                if new_g ~= options.graphics.gamma.green then options.graphics.gamma.green = new_g; apply_settings(); settings.save() end

                layout:label("[Gamma - Blue (" .. string.format("%.2f", options.graphics.gamma.blue) .. ")]{color:dodgerblue}")
                local new_b = layout:slider("sld_gamma_b", options.graphics.gamma.blue, 0.5, 3.0)
                if new_b ~= options.graphics.gamma.blue then options.graphics.gamma.blue = new_b; apply_settings(); settings.save() end

                layout:space(10)
                layout:label("[SYSTEM & AUDIO]{color:skin_accent weight:bold}")
                layout:space(5)

                -- Audio Sliders
                layout:label("[Music Volume (BGM) (" .. string.format("%.1f", options.audio.volume.music) .. ")]{color:system_white}")
                local new_music = layout:slider("sld_vol_music", options.audio.volume.music, 0.0, 1.0)
                if new_music ~= options.audio.volume.music then options.audio.volume.music = new_music; apply_settings(); settings.save() end

                layout:label("[Sound Effects Volume (SE) (" .. string.format("%.1f", options.audio.volume.effects) .. ")]{color:system_white}")
                local new_effects = layout:slider("sld_vol_effects", options.audio.volume.effects, 0.0, 1.0)
                if new_effects ~= options.audio.volume.effects then options.audio.volume.effects = new_effects; apply_settings(); settings.save() end

                layout:space(10)

                -- Condensed Checkboxes
                local particle_clicked, _ = layout:check("chk_particles", "Enable Footstep Particles", options.graphics.footstep_effects)
                if particle_clicked then options.graphics.footstep_effects = not options.graphics.footstep_effects; apply_settings(); settings.save() end

                local foot_clicked, _ = layout:check("chk_foot", "Enable Footstep Audio", options.audio.footstep_effects)
                if foot_clicked then options.audio.footstep_effects = not options.audio.footstep_effects; apply_settings(); settings.save() end

                local filter_clicked, _ = layout:check("chk_filter", "Enable Profanity Filter", options.system.language_filter.enabled)
                if filter_clicked then options.system.language_filter.enabled = not options.system.language_filter.enabled; apply_settings(); settings.save() end
                
                local afk_clicked, _ = layout:check("chk_afk", "Enable Auto-Disconnect (AFK Kick)", options.system.auto_disconnect.enabled)
                if afk_clicked then options.system.auto_disconnect.enabled = not options.system.auto_disconnect.enabled; apply_settings(); settings.save() end

            end)
            
            if not window_still_open then 
                state.show_ui = false 
                chat.print("Config UI Closed.", ui.color.system_gray)
            end
        else
            config_window.visible = false
        end
    end)
    
    if not success then 
        state.show_ui = false 
        chat.print("Config UI Crash: " .. tostring(err), ui.color.system_error) 
    end
end)

-- ============================================================================
-- 3. COMMAND ROUTER
-- ============================================================================
command.register('cfg', function(args)
    state.show_ui = not state.show_ui
    if state.show_ui then
        chat.print("Config UI Opened.", ui.color.skin_accent)
    end
end)