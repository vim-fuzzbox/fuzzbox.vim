vim9script

scriptencoding utf-8

import autoload '../internal/selector.vim'
import autoload '../internal/previewer.vim'
import autoload '../internal/popup.vim'
import autoload '../internal/helpers.vim'

var loclist: list<any>

var separator = g:fuzzbox_menu_separator

def Select(wid: number, result: string)
    if empty(result)
        return
    endif
    var nr = str2nr(split(result, separator)[0])
    echo '' # clear loclist title message
    exe 'll!' .. nr
enddef

def ParseResult(result: string): list<any>
    var idx = str2nr(split(result, separator)[0]) - 1
    var item = loclist[idx]
    var fname: string
    var bufnr = item->get('bufnr', 0)
    if bufnr == 0
        fname = "[No Name]"
    else
        fname = bufname(bufnr)
    endif
    var lnum = item->get('lnum', 0)
    return [fname, lnum]
enddef

def Preview(wid: number, result: string)
    if wid == -1
        return
    endif
    if empty(result)
        previewer.PreviewText(wid, '')
        return
    endif
    var [fname, lnum] = ParseResult(result)
    previewer.PreviewFile(wid, fname)
    win_execute(wid, 'norm! ' ..  lnum .. 'G')
    win_execute(wid, 'norm! zz')
    clearmatches(wid)
    matchaddpos('fuzzboxPreviewLine', [lnum], 999, -1,  {window: wid})
enddef

def OpenTab(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [fname, lnum] = ParseResult(result)
    exe 'tabnew ' .. fnameescape(fname)
    exe 'norm! ' .. lnum .. 'G'
    exe 'norm! zz'
enddef

def OpenSplit(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [fname, lnum] = ParseResult(result)
    helpers.MoveToUsableWindow()
    exe 'split ' .. fnameescape(fname)
    exe 'norm! ' .. lnum .. 'G'
    exe 'norm! zz'
enddef

def OpenVSplit(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [fname, lnum] = ParseResult(result)
    helpers.MoveToUsableWindow()
    exe 'vsplit ' .. fnameescape(fname)
    exe 'norm! ' .. lnum .. 'G'
    exe 'norm! zz'
enddef

export def Start(opts: dict<any> = {})
    opts.title = has_key(opts, 'title') ? opts.title : 'Loclist'

    loclist = getloclist(winnr())

    if empty(loclist)
        echohl ErrorMsg | echo "Location list is empty" | echohl None
        return
    endif

    # mostly copied from scope.vim, thanks @girishji
    var size = getloclist(winnr(), {size: 0}).size
    var fmt = ' %' ..  len(string(size)) .. 'd ' .. separator .. ' '
    var lines = loclist->mapnew((idx, v) => {
        var fname: string
        var bufnr = v->get('bufnr', 0)
        if bufnr == 0
            fname = "[No Name]"
        else
            fname = bufname(bufnr)
        endif
        var text = v->get('text', '')
        var lnum = v->get('lnum', 0)
        if lnum > 0
            var col = v->get('col', 0)
            if col > 0
                return printf($"{fmt}%s:%d:%d:%s", idx + 1, fname, lnum, col, text)
            else
                return printf($"{fmt}%s:%d:%s", idx + 1, fname, lnum, text)
            endif
        endif
        return printf($"{fmt}%s:%s", idx + 1, fname, text)
    })

    echo getloclist(winnr(), {title: 0}).title

    var opener = winnr()

    var wins = selector.Start(lines, extend(opts, {
        select_cb: function('Select'),
        preview_cb: function('Preview'),
        actions: {
            "\<c-v>": function('OpenVSplit'),
            "\<c-s>": function('OpenSplit'),
            "\<c-t>": function('OpenTab'),
            "\<c-q>": null_function,
        }
    }))

    # Move cursor to the current item in the location list
    var nr = getloclist(opener, {idx: 0}).idx
    var move = nr - 1
    if move > 0
        if opts.dropdown
            win_execute(wins.menu, "norm! " .. move .. "j")
        else
            win_execute(wins.menu, "norm! " .. move .. "k")
        endif
    endif
enddef
