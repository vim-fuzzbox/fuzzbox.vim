vim9script

import autoload '../utils/selector.vim'

var old_color: string
var old_bg: string
var changed: bool

def GetColors(): list<string>
   return uniq(sort(map(
     globpath(&runtimepath, "colors/*.vim", 0, 1),
     'fnamemodify(v:val, ":t:r")'
   )))
enddef

def Preview(wid: number, result: string)
    if empty(result)
        return
    endif
    var color = result
    &bg = old_bg
    noa execute 'colorscheme ' .. color
enddef

def Select(wid: number, result: string)
    if empty(result)
        return
    endif
    var color = result
    var bg: string
    if color =~# 'light$'
        noa &bg = 'light'
    endif
    execute 'colorscheme ' .. color
    changed = true
enddef

def Close(wid: number)
    if !changed
        noa &bg = old_bg
        execute 'colorscheme ' .. old_color
    endif
enddef

export def Start(opts: dict<any> = {})
    old_color = execute('colo')[1 :]
    old_bg = &bg
    var colors = GetColors()

    var wids = selector.Start(colors, extend(opts, {
        preview_cb: function('Preview'),
        select_cb: function('Select'),
        close_cb: function('Close'),
        preview: 0
    }))
enddef
