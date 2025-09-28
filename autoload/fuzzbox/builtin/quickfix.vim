vim9script

scriptencoding utf-8

import autoload '../internal/selector.vim'
import autoload '../internal/previewer.vim'
import autoload '../internal/popup.vim'
import autoload '../internal/helpers.vim'

def Select(wid: number, result: string)
    var nr = str2nr(split(result, '│')[0])
    helpers.MoveToUsableWindow()
    exe 'cc!' .. nr
enddef

def ParseResult(result: string): list<any>
    var idx = str2nr(split(result, '│')[0]) - 1
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

def OpenFileTab(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [fname, lnum] = ParseResult(result)
    exe 'tabnew ' .. fnameescape(fname)
    exe 'norm! ' .. lnum .. 'G'
    exe 'norm! zz'
enddef

def OpenFileVSplit(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [fname, lnum] = ParseResult(result)
    exe 'vsplit ' .. fnameescape(fname)
    exe 'norm! ' .. lnum .. 'G'
    exe 'norm! zz'
enddef

def OpenFileSplit(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [fname, lnum] = ParseResult(result)
    exe 'split ' .. fnameescape(fname)
    exe 'norm! ' .. lnum .. 'G'
    exe 'norm! zz'
enddef

def SendToQuickfix(wid: number, result: string, opts: dict<any>)
    var bufnr = winbufnr(wid)
    var lines: list<any>
    lines = reverse(getbufline(bufnr, 1, "$"))
    filter(lines, (_, val) => !empty(val))
    setqflist(map(lines, (_, val) => {
        var idx = str2nr(split(val, '│')[0]) - 1
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
    if getqflist({nr: '$'}).nr == 0
        echohl ErrorMsg | echo "Quickfix list is empty" | echohl None
        return
    endif

    # mostly copied from scope.vim, thanks @girishji
    var size = getqflist({size: 0}).size
    var fmt = ' %' ..  len(string(size)) .. 'd │ '
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

    selector.Start(lines, extend(opts, {
        select_cb: function('Select'),
        preview_cb: function('Preview'),
        actions: {
            "\<c-v>": function('OpenFileVSplit'),
            "\<c-s>": function('OpenFileSplit'),
            "\<c-t>": function('OpenFileTab'),
            "\<c-q>": function('SendToQuickfix'),
        }
    }))
enddef
