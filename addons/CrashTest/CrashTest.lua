local chat = require('chat')

local addon = {
    name = 'CrashTest',
    author = 'Test',
    version = '1.0'
}

-- Use Windower 5's native scheduler
coroutine.schedule(function()
    -- Sleep for one frame so the addon finishes loading cleanly first
    coroutine.sleep_frame()
    
    -- Fire a massive burst of queued functions to stress the C++ std::swap logic
    for i = 1, 500 do
        -- Every single chat output forces C++ to queue a function in the core engine
        chat.success("Stress Test Message " .. tostring(i))
    end
end)

return addon