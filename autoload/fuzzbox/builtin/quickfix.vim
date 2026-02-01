vim9script

scriptencoding utf-8

import autoload '../internal/selector.vim'
import autoload '../internal/previewer.vim'
import autoload '../internal/popup.vim'
import autoload '../internal/helpers.vim'

var separator = g:fuzzbox_menu_separator

def Select(wid: number, result: string)
    if empty(result)
        return
    endif
    var nr = str2nr(split(result, separator)[0])
    helpers.MoveToUsableWindow()
    echo '' # clear qflist title message
    exe 'cc!' .. nr
enddef

def ParseResult(result: string): list<any>
    var idx = str2nr(split(result, separator)[0]) - 1
    var item = getqflist()[idx]
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
enddef

def OpenTab(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var nr = str2nr(split(result, separator)[0])
    execute 'tabnew'
    execute 'cc!' .. nr
enddef

def OpenSplit(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var nr = str2nr(split(result, separator)[0])
    helpers.MoveToUsableWindow()
    execute 'split'
    execute 'cc!' .. nr
enddef

def OpenVSplit(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var nr = str2nr(split(result, separator)[0])
    helpers.MoveToUsableWindow()
    execute 'vsplit'
    execute 'cc!' .. nr
enddef

def SendToQuickfix(wid: number, result: string, opts: dict<any>)
    var bufnr = winbufnr(wid)
    var lines: list<any>
    lines = reverse(getbufline(bufnr, 1, "$"))
    filter(lines, (_, val) => !empty(val))
    setqflist(map(lines, (_, val) => {
        var idx = str2nr(split(val, separator)[0]) - 1
        return getqflist()[idx]
    }))

    if has_key(opts, 'prompt_title') && !empty(opts.prompt_title)
        var title = opts.prompt_title
        var input = popup.GetPrompt()
        if !empty(input)
            title = title .. ' (' .. input .. ')'
        endif
        setqflist([], 'a', {title: title})
    endif

    popup_close(wid)
    exe 'copen'
enddef

export def Start(opts: dict<any> = {})
    opts.title = has_key(opts, 'title') ? opts.title : 'Quickfix'

    if getqflist({nr: '$'}).nr == 0
        echohl ErrorMsg | echo "Quickfix list is empty" | echohl None
        return
    endif

    # mostly copied from scope.vim, thanks @girishji
    var size = getqflist({size: 0}).size
    var fmt = ' %' ..  len(string(size)) .. 'd ' .. separator .. ' '
    var lines = getqflist()->mapnew((idx, v) => {
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

    echo getqflist({title: 0}).title

    var wins = selector.Start(lines, extend(opts, {
        select_cb: function('Select'),
        preview_cb: function('Preview'),
        actions: {
            "\<c-v>": function('OpenVSplit'),
            "\<c-s>": function('OpenSplit'),
            "\<c-t>": function('OpenTab'),
            "\<c-q>": function('SendToQuickfix'),
        }
    }))

    # Move cursor to the current item in the quickfix list
    var nr = getqflist({idx: 0}).idx
    var move = nr - 1
    if move > 0
        if opts.dropdown
            win_execute(wins.menu, "norm! " .. move .. "j")
        else
            win_execute(wins.menu, "norm! " .. move .. "k")
        endif
    endif
enddef
