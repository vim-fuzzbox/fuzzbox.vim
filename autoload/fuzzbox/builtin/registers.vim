vim9script

import autoload '../internal/selector.vim'

var separator = g:fuzzbox_menu_separator

def Select(wid: number, result: string)
    if empty(result)
        return
    endif
    var reg = result->matchstr('\v^\s*\zs\S+')
    exe $'normal! "{reg}p'
enddef

export def Start(opts: dict<any> = {})
    opts.title = has_key(opts, 'title') ? opts.title : 'Registers'

    var lines = 'registers'->execute()->split("\n")->slice(1)->map((_, val) => {
        var reg = val->matchstr('\v^\s*\a\s*"\zs\S+')
        return printf($" %s %s %s", reg, separator, getreg(reg, 1, 1)[0])
    })

    selector.Start(lines, extend(opts, {
        preview: false,
        select_cb: function('Select')
    }))
enddef
