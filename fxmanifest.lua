fx_version 'cerulean'
game 'gta5'

description 'esx-lapraces'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
	'@es_extended/imports.lua',
	'config.lua'
}

client_script 'client/main.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

files {
    'html/*.html',
    'html/*.css',
    'html/*.js',
    'html/fonts/*.otf',
    'html/img/*'
}

lua54 'yes'
