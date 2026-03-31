local chat = require('core.chat')
local command = require('core.command')

local addon = {
    name = 'HelloWorld',
    author = 'You',
    version = '1.0'
}

-- Create a new root command: '/hello'
local hello_cmd = command.new('hello')

-- In Fenestra, if sub-commands exist, the base command cannot have an action.
hello_cmd:register('ping', function()
    chat.add_text('Pong! Your addon is listening.', 207)
end)

hello_cmd:register('help', function()
    chat.add_text('Commands: /hello ping, /hello help', 207)
end)

-- Print a message as soon as the package manager loads the script
chat.add_text('HelloWorld loaded: Time to build some dope addons!', 207)

return addon