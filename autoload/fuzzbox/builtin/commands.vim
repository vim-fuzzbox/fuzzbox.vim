vim9script

import autoload '../utils/selector.vim'

def Select(wid: number, result: string)
    if result =~# '^[A-Z]'
        # User-defined command, check for nargs, send <CR> if no nargs
        var info = split(execute(':filter /\<' .. result .. '\>/ command ' .. result), '\n')[-1]
        var nargs = split(matchstr(info, '\<' .. result .. '\>\s\+\S'), '\s\+')[-1]
        feedkeys(':' .. result .. ' ', 'n')
        if nargs == "0"
            feedkeys("\<CR>", 'n')
        endif
    else !empty(result)
        # Built-in command, no check for nargs, just feed to cmdline
        feedkeys(':' .. result .. ' ', 'n')
    endif
enddef

export def Start(opts: dict<any> = {})
    var li: list<string> = getcompletion('', 'command')
    var wids = selector.Start(li, extend(opts, {
        select_cb: function('Select'),
        preview: 0
    }))
enddef
