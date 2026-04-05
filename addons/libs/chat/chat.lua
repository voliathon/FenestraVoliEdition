local core_chat = require('core.chat')
local chat = {}

function chat.print(text, color)
    color = color or 207
    core_chat.add_text(tostring(text), color, false)
end

function chat.on_text_added(callback)
    core_chat.text_added:register(callback)
end

return chat