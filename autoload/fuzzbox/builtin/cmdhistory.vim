vim9script

import autoload '../internal/selector.vim'
import autoload '../internal/popup.vim'

def Select(wid: number, result: string)
    if empty(result)
        return
    endif
    feedkeys(':' .. result .. "\<CR>", 'n')
enddef

export def Start(opts: dict<any> = {})
    opts.title = has_key(opts, 'title') ? opts.title : 'Command History'

    var cmds = split(execute("history"), '\n')[1 : ]

    # remove index of command history
    cmds = reduce(cmds,
        (a, v) => add(a, substitute(v, '\m^.*\d\+\s\+', '', '')), [])

    selector.Start(reverse(cmds), extend(opts, {
        select_cb: function('Select'),
        preview: 0
    }))
enddef
