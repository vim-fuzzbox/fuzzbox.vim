vim9script

import autoload '../internal/selector.vim'
import autoload '../internal/previewer.vim'

var markdict: dict<any>

def Select(wid: number, result: string)
    if empty(result)
        return
    endif
    var mark = result->matchstr('\v^\s*\zs\S+')
    exe $"normal! `{mark}"
enddef

def ParseResult(result: string): list<any>
    var mark = result->matchstr('\v^\s*\zs\S+')
    var [file, bufnr, lnum, col] = markdict[mark]
    return [file, bufnr, lnum, col]
enddef

def Preview(wid: number, result: string)
    if wid == -1
        return
    endif
    if empty(result)
        previewer.PreviewText(wid, '')
        return
    endif
    var [file, bufnr, lnum, col] = ParseResult(result)
    if empty(file)
        previewer.PreviewText(wid, '')
        popup_settext(wid, getbufline(bufnr, 1, '$'))
    else
        previewer.PreviewFile(wid, fnamemodify(file, ':p'))
    endif
    win_execute(wid, 'norm! ' .. lnum .. 'G')
    win_execute(wid, 'norm! zz')
    clearmatches(wid)
    matchaddpos('fuzzboxPreviewMatch', [[lnum, col]], 9999, -1,  {window: wid})
enddef

def OpenFileTab(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [file, bufnr, lnum, col] = ParseResult(result)
    exe 'tabnew'
    if empty(file)
        exe 'buffer ' .. bufnr
    else
        exe 'edit ' .. fnameescape(file)
    endif
    cursor(lnum, col)
    exe 'norm! zz'
enddef

def OpenFileVSplit(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [file, bufnr, lnum, col] = ParseResult(result)
    exe 'vsplit'
    if empty(file)
        exe 'buffer ' .. bufnr
    else
        exe 'edit ' .. fnameescape(file)
    endif
    cursor(lnum, col)
    exe 'norm! zz'
enddef

def OpenFileSplit(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [file, bufnr, lnum, col] = ParseResult(result)
    exe 'split'
    if empty(file)
        exe 'buffer ' .. bufnr
    else
        exe 'edit ' .. fnameescape(file)
    endif
    cursor(lnum, col)
    exe 'norm! zz'
enddef

export def Start(opts: dict<any> = {})
    opts.title = has_key(opts, 'title') ? opts.title : 'Marks'

    var marklist = extend(getmarklist(), getmarklist(bufnr()))
    reduce(marklist, (acc, item) => {
        acc[item.mark[1]] = [
            get(item, 'file', bufname(item.pos[0])),
            item.pos[0],
            item.pos[1],
            item.pos[2],
        ]
        return acc
    }, markdict)

    var lines = execute('marks')->split("\n")->slice(1)->map((_, val) => {
        var mark = val->matchstr('\v^\s*\zs\S+')
        var [fname, bufnr, lnum, col] = markdict[mark]
        if empty(fname)
            fname = "[No Name]"
        endif
        var text = getbufoneline(bufnr, lnum)
        return printf($" %s │ %s:%d:%d:%s", mark, fname, lnum, col, text)
    })

    selector.Start(lines, extend(opts, {
        select_cb: function('Select'),
        preview_cb: function('Preview'),
        actions: {
            "\<c-v>": function('OpenFileVSplit'),
            "\<c-s>": function('OpenFileSplit'),
            "\<c-t>": function('OpenFileTab'),
        }
    }))
enddef
