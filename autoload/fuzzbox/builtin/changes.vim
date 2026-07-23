vim9script

import autoload '../internal/selector.vim'
import autoload '../internal/previewer.vim'

var changelist: list<any>
var changelast: number
var bufnr: number

var separator = g:fuzzbox_menu_separator

def ParseResult(result: string): list<any>
    var idx = str2nr(split(result, separator)[0]) - 1
    var change = changelist[idx]
    return [change.lnum, change.col]
enddef

def Select(wid: number, result: string)
    if empty(result)
        return
    endif
    var [lnum, col] = ParseResult(result)
    cursor(lnum, col)
    exe 'norm! zz'
enddef

def Preview(wid: number, result: string)
    if empty(result)
        previewer.PreviewText(wid, '')
        return
    endif
    var [lnum, col] = ParseResult(result)
    var file = bufname(bufnr)
    if empty(file)
        previewer.PreviewText(wid, getbufline(bufnr, 1, '$'), lnum, col)
    else
        previewer.PreviewFile(wid, fnamemodify(file, ':p'), lnum, col)
    endif
enddef

def OpenFileTab(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [lnum, col] = ParseResult(result)
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
    var [lnum, col] = ParseResult(result)
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
    var [lnum, col] = ParseResult(result)
    exe 'split'
    exe 'buffer ' .. bufnr
    cursor(lnum, col)
    exe 'norm! zz'
enddef

export def Start(opts: dict<any> = {})
    changelist = getchangelist()[0]
    changelast = getchangelist()[1]

    bufnr = bufnr()

    var size = len(changelist)
    var fmt = ' %' ..  len(string(size)) .. 'd ' .. separator .. ' '
    var lines = changelist->mapnew((idx, change) => {
        var fname = bufname(bufnr)
        if empty(fname)
            fname = "[No Name]"
        endif
        var text: string
        # note: getbufoneline() only added in vim 9.1.0916
        var lines = getbufline(bufnr, change.lnum)
        if !empty(lines)
            text = lines[0]
        endif
        return printf($"{fmt}%s:%d:%d:%s", idx + 1, fname, change.lnum, change.col, text)
    })
    reverse(lines) # Reverse list so we start at the end of the changelist

    var wids = selector.Start(lines, extend(opts, {
        prompt_title: 'Changes',
        select_cb: function('Select'),
        preview_cb: function('Preview'),
        actions: {
            "\<c-v>": function('OpenFileVSplit'),
            "\<c-s>": function('OpenFileSplit'),
            "\<c-t>": function('OpenFileTab'),
        }
    }))

    if changelast != len(changelist)
        win_execute(wids.menu, $'syn match Number "^\s\+{changelast + 1}\s"')
    endif

    # Move cursor to the current item in the change list
    if changelast != len(changelist)
        var move = len(changelist) - changelast - 1
        if move > 0
            if opts.dropdown
                win_execute(wids.menu, "norm! " .. move .. "j")
            else
                win_execute(wids.menu, "norm! " .. move .. "k")
            endif
        endif
    endif
enddef
