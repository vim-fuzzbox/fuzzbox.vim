vim9script

import autoload '../internal/selector.vim'
import autoload '../internal/previewer.vim'

var jumplist: list<any>
var jumplast: number

def ParseResult(result: string): list<any>
    var idx = str2nr(split(result, '│')[0]) - 1
    var jump = jumplist[idx]
    return [jump.bufnr, jump.lnum, jump.col]
enddef

def Select(wid: number, result: string)
    if empty(result)
        return
    endif
    var [bufnr, lnum, col] = ParseResult(result)
    exe 'buffer ' .. bufnr
    cursor(lnum, col)
    exe 'norm! zz'
enddef

def Preview(wid: number, result: string)
    if wid == -1
        return
    endif
    if empty(result)
        previewer.PreviewText(wid, '')
        return
    endif
    var [bufnr, lnum, col] = ParseResult(result)
    var file = bufname(bufnr)
    if empty(file)
        previewer.PreviewText(wid, '')
        popup_settext(wid, getbufline(bufnr, 1, '$'))
    else
        previewer.PreviewFile(wid, fnamemodify(file, ':p'))
    endif
    win_execute(wid, 'norm! ' .. lnum .. 'G')
    win_execute(wid, 'norm! zz')
    clearmatches(wid)
    if col == 0
        col = 1
    endif
    matchaddpos('fuzzboxPreviewMatch', [[lnum, col]], 9999, -1,  {window: wid})
enddef

def OpenFileTab(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [bufnr, lnum, col] = ParseResult(result)
    exe 'tabnew'
    exe 'buffer ' .. bufnr
    cursor(lnum, col)
    exe 'norm! zz'
enddef

def OpenFileVSplit(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [bufnr, lnum, col] = ParseResult(result)
    exe 'vsplit'
    exe 'buffer ' .. bufnr
    cursor(lnum, col)
    exe 'norm! zz'
enddef

def OpenFileSplit(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [bufnr, lnum, col] = ParseResult(result)
    exe 'split'
    exe 'buffer ' .. bufnr
    cursor(lnum, col)
    exe 'norm! zz'
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
        var text: string
        if bufloaded(jump.bufnr)
            # note: getbufoneline() only added in vim 9.1.0916
            text = getbufline(jump.bufnr, jump.lnum)[0]
        endif
        return printf($"{fmt}%s:%d:%d:%s", idx + 1, fname, jump.lnum, jump.col, text)
    })
    reverse(lines) # Reverse list so we start at the end of the jumplist

    var wins = selector.Start(lines, extend(opts, {
        prompt_title: 'Jumps',
        select_cb: function('Select'),
        preview_cb: function('Preview'),
        actions: {
            "\<c-v>": function('OpenFileVSplit'),
            "\<c-s>": function('OpenFileSplit'),
            "\<c-t>": function('OpenFileTab'),
        }
    }))

    # Move cursor to the current item in the jump list
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
