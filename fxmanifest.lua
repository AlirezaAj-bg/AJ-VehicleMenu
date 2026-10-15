fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Alireza'
description 'AJ Vehicle Menu - vehicle control dock with live stats, driving tools, lighting and keyfob mode'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/controls.lua',
    'client/driving.lua',
    'client/remote.lua',
    'client/sync.lua',
}

server_scripts {
    'server/main.lua',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
}

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/nui.js',
    'html/js/icons.js',
    'html/js/app.js',
    'html/vendor/vue.global.prod.js',
    'html/fonts/Inter-Regular.woff2',
    'html/fonts/Inter-Medium.woff2',
    'html/fonts/Inter-SemiBold.woff2',
    'html/fonts/Inter-Bold.woff2',
    'html/fonts/Inter-ExtraBold.woff2',
}
