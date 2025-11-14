vim9script

import autoload '../internal/selector.vim'
import autoload '../internal/previewer.vim'
import autoload '../internal/actions.vim'

var jumplist: list<any>
var jumplast: number

def ParseResult(result: string): list<any>
    var idx = str2nr(split(result, '│')[0]) - 1
    var jump = jumplist[idx]
    var file = bufname(jump.bufnr)
    if empty(file)
        return [jump.bufnr, jump.lnum, jump.col]
    endif
    return [file, jump.lnum, jump.col]
enddef

def Preview(wid: number, result: string)
    if wid == -1
        return
    endif
    if empty(result)
        previewer.PreviewText(wid, '')
        return
    endif
    echow ParseResult(result)
    var [file, lnum, col] = ParseResult(result)
    if type(file) == v:t_number
        previewer.PreviewText(wid, 'dfdsf')
        popup_settext(wid, getbufline(file, 1, '$'))
    else
        previewer.PreviewFile(wid, file)
    endif
    win_execute(wid, 'norm! ' .. lnum .. 'G')
    win_execute(wid, 'norm! zz')
    clearmatches(wid)
    if col == 0
        col = 1
    endif
    matchaddpos('fuzzboxPreviewMatch', [[lnum, col]], 9999, -1,  {window: wid})
enddef

export def Start(opts: dict<any> = {})
    jumplist = getjumplist()[0]
    jumplast = getjumplist()[1]

    var size = len(jumplist)
    var fmt = ' %' ..  len(string(size)) .. 'd │ '
    var lines = jumplist->mapnew((idx, jump) => {
        var fname = bufname(jump.bufnr)
        if empty(fname)
            fname = "[No Name]"
        endif
        var text = getbufoneline(jump.bufnr, jump.lnum)
        return printf($"{fmt}%s:%d:%d:%s", idx + 1, fname, jump.lnum, jump.col, text)
    })
    reverse(lines) # Reverse list so we start at the end of the jumplist

    var wins = selector.Start(lines, extend(opts, {
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
