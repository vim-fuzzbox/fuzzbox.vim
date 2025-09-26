vim9script

import autoload '../internal/selector.vim'
import autoload '../internal/previewer.vim'
import autoload '../internal/actions.vim'

def ParseResult(str: string): list<any>
    var seq = matchstrpos(str, '\:\d\+:\d\+:')
    if seq[1] == -1
        return [null, -1, -1]
    endif
    var path = strpart(str, 0, seq[1])
    var linecol = split(seq[0], ':')
    var line = str2nr(linecol[0])
    var col: number
    if len(linecol) == 2
        col = str2nr(linecol[1])
    else
        col = 0
    endif
    return [fnamemodify(path, ':p'), line, col]
enddef

def Preview(wid: number, result: string)
    if wid == -1
        return
    endif
    if empty(result)
        previewer.PreviewText(wid, '')
        return
    endif
    var [file, lnum, col] = ParseResult(result)
    if empty(file)
        previewer.PreviewText(wid, '')
        return
    endif
    previewer.PreviewFile(wid, file)
    win_execute(wid, 'norm! ' .. lnum .. 'G')
    win_execute(wid, 'norm! zz')
    clearmatches(wid)
    if col == 0
        col = 1
    endif
    matchaddpos('fuzzboxPreviewMatch', [[lnum, col]], 9999, -1,  {window: wid})
enddef

export def Start(opts: dict<any> = {})
    var jumplist = getjumplist()[0]
    var jumplast = getjumplist()[1]

    var jumps: list<any>
    for idx in range(len(jumplist))
        var jump = jumplist[idx]
        var loc = expand('#' .. jump.bufnr .. ':p:~:.')
        if empty(loc)
            loc = '[No Name]'
        endif
        loc ..= ':' .. jump.lnum .. ':' .. jump.col
        var line = printf('%s: %s', loc, getbufoneline(jump.bufnr, jump.lnum))
        add(jumps, line)
    endfor
    reverse(jumps)

    var wins = selector.Start(jumps, extend(opts, {
        prompt_title: 'Jumps',
        select_cb: actions.OpenFile,
        preview_cb: function('Preview'),
    }))

    if jumplast != len(jumplist)
        var move = len(jumplist) - jumplast - 1
        if move > 0
            if opts.dropdown
                win_execute(wins.menu, "norm! " .. move .. "j")
            else
                win_execute(wins.menu, "norm! " .. move .. "k")
            endif
        endif
    endif
enddef
