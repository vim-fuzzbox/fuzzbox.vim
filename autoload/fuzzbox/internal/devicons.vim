vim9script

import autoload './colors.vim'

var devicon_char_width = 0
var devicon_byte_width = 0

# Options
var glyph_func = exists('g:fuzzbox_devicons_glyph_func') ? g:fuzzbox_devicons_glyph_func : ''

var color_func = exists('g:fuzzbox_devicons_color_func') ? g:fuzzbox_devicons_color_func : ''

var enabled = exists('g:fuzzbox_devicons') && !empty(glyph_func) ? g:fuzzbox_devicons : !empty(glyph_func)

if &encoding != 'utf-8'
    enabled = false
endif

export def Enabled(): bool
    return enabled
enddef

export def GetDevicon(str: string): string
    return function(glyph_func)(str)
enddef

if enabled
    var test_devicon = GetDevicon('a.lua')
    devicon_char_width = strcharlen(test_devicon)
    devicon_byte_width = strlen(test_devicon)
endif

# Allows the colors to be changed before loading devicons, see compat/fuzzbox.vim
var devicons_color_table = colors.DeviconsColorTable()

def SetHl()
    for val in uniq(values(devicons_color_table))
        exe 'hi fuzzboxDevicon_' .. substitute(val, '#', '', '') .. ' ctermfg=' .. colors.TermColor(val) .. ' guifg=' .. val
    endfor
enddef

if enabled
    SetHl()
    augroup FuzzboxDevicons
        autocmd!
        autocmd ColorScheme * SetHl()
    augroup END
endif

export def AddColor(wid: number)
    if !empty(color_func)
        win_execute(wid, color_func .. '()')
        return
    endif
    var added: list<string>
    for ft in reverse(sort(keys(devicons_color_table)))
        var icon = GetDevicon(ft)
        if index(added, icon) != -1
            continue
        endif
        var charnr = char2nr(icon)
        var charhex = printf('%x', charnr)
        var color = devicons_color_table[ft]
        try
        matchadd('fuzzboxDevicon_' .. substitute(color, '#', '', ''), '\v%U' .. charhex, 99, -1, { window: wid })
        add(added, icon)
        catch | endtry
    endfor
enddef

export def GetDeviconOffset(): number
    return devicon_byte_width + 1
enddef

export def RemoveDevicon(str: string): string
    return strcharpart(str, devicon_char_width + 1)
enddef

export def AddDevicons(li: list<string>): list<string>
    if !empty(li) && stridx(li[0], ':') != -1
        map(li, (_, val) => {
            return GetDevicon(split(val, ':')[0]) .. ' ' .. val
        })
    else
        map(li, 'GetDevicon(v:val) .. " " .. v:val')
    endif
    return li
enddef
