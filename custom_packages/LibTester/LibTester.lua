local fw = require('FenestraSDK')

local addon = {
    name = 'LibTester',
    author = 'You',
    version = '1.0'
}

fw.command.register('libtest', function(args)
    local target_lib = args[1] or "file"
    
    fw.chat.print("LibTester: Attempting to load '" .. target_lib .. "'...", fw.ui.color.system_white)
    
    local success, result = pcall(require, target_lib)
    
    if success then
        fw.chat.print("SUCCESS: '" .. target_lib .. "' loaded correctly!", fw.ui.color.green)
        
        -- If it's a table, count the keys to prove it's not an empty dummy table
        if type(result) == "table" then
            local count = 0
            for k, v in pairs(result) do count = count + 1 end
            fw.chat.print(" -> Returned a table with " .. count .. " keys.", fw.ui.color.green)
        end
    else
        fw.chat.print("FAIL: Sandbox blocked '" .. target_lib .. "'.", fw.ui.color.system_error)
        fw.chat.print(" -> Error: " .. tostring(result), fw.ui.color.system_error)
    end
end)

fw.chat.print("LibTester Initialized. Type /libtest <library_name>", fw.ui.color.skin_accent)

return addon