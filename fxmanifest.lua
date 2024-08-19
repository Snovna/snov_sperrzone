fx_version 'cerulean'
games { 'gta5' }

version '1.0'
author 'Snov'
lua54 'yes'

client_scripts {
    'client.lua',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

server_scripts {
    'server.lua',
}