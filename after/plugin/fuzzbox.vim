vim9script

# Compatibility hacks, loaded after other plugins

if exists('g:loaded_webdevicons') && !exists('g:fuzzbox_devicons_glyph_func')
    g:fuzzbox_devicons_glyph_func = 'g:WebDevIconsGetFileTypeSymbol'
endif

if exists('g:loaded_nerdfont') && !exists('g:fuzzbox_devicons_glyph_func')
    g:fuzzbox_devicons_glyph_func = 'nerdfont#find'
endif

if exists('g:loaded_glyph_palette') && !exists('g:fuzzbox_devicons_color_func')
    g:fuzzbox_devicons_color_func = 'glyph_palette#apply'
endif

if exists('g:loaded_nerd_tree') && !exists('g:fuzzbox_devicons_color_func') &&
        findfile('after/syntax/nerdtree.vim', &rtp) =~ 'nerdtree-syntax-highlight'
    import '../autoload/fuzzbox/internal/colors.vim'
    runtime! after/syntax/nerdtree.vim
    map(colors.DeviconsColorTable(), (key, val) => {
        var ext = fnamemodify(key, ':e')
        if !empty(ext) && hlexists('nerdtreeFileExtensionIcon_' .. tolower(ext))
            return hlget('nerdtreeFileExtensionIcon_' .. tolower(ext))[0]['guifg']
        elseif hlexists('nerdtreeExactMatchIcon_' .. tolower(key))
            return hlget('nerdtreeExactMatchIcon_' .. tolower(key))[0]['guifg']
        else
            return val
        endif
    })->filter((key, val) => key != '__default__')
endif

# FileType autocmd to colorize devicons. By default only applies to the Fuzzbox
# menu, but you can use this to apply Fuzzbox devicon colors to other filetypes.
# Check for devicons enabled must come after detecting devicons glyph function
import autoload '../../autoload/fuzzbox/internal/devicons.vim'
var devicons_colorize = exists('g:fuzzbox_devicons_colorize')
    && type(g:fuzzbox_devicons_colorize) == v:t_list ? g:fuzzbox_devicons_colorize : ['fuzzbox_menu']
if !empty(devicons_colorize) && devicons.Enabled()
    autocmd_add([{
        group: 'FuzzboxDeviconsColorize',
        event: 'FileType',
        cmd: 'devicons.Colorize()',
        pattern: join(devicons_colorize, ',')
    }])
endif
