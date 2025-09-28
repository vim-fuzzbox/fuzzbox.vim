vim9script

# Compatibility hacks, loaded from VimEnter autocmd in plugin/fuzzbox.vim
if exists("g:loaded_fuzzbox_compat")
  finish
endif
g:loaded_fuzzbox_compat = 1

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
