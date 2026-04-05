local core_command = require('core.command')
local core_pin = require('core.pin')

local command = {}
local active_commands = {}

function command.register(command_name, callback)
    if not active_commands[command_name] then
        local cmd_obj = core_command.new(command_name)
        core_pin(cmd_obj)
        
        cmd_obj:register(function(...)
            local args = {...}
            if active_commands[command_name] then
                active_commands[command_name](args)
            end
        end, '[string]*') 
    end
    
    active_commands[command_name] = callback
end

return command