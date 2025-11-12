vim9script

import autoload '../internal/selector.vim'
import autoload '../internal/previewer.vim'

var bufnr: number

def Select(wid: number, result: string)
    if empty(result)
        return
    endif
    var mark = result->matchstr('\v^\s*\zs\S+')
    exe $"normal! `{mark}"
enddef

def ParseResult(result: string): list<any>
    var mark = result->matchstr('\v^\s*\zs\S+')
    var marklist = extend(getmarklist(), getmarklist(bufnr))
    var markdata = marklist->filter((_, dict) => {
       return dict.mark == "'" .. mark
    })[0]
    var lnum = markdata.pos[1]
    var col = markdata.pos[2]
    var file = get(markdata, 'file', bufname(bufnr))
    if empty(file)
        return [bufnr, lnum, col]
    endif
    return [fnamemodify(file, ':p'), lnum, col]
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
    if type(file) == v:t_number
        previewer.PreviewText(wid, '')
        popup_settext(wid, getbufline(file, 1, '$'))
    elseif !filereadable(file)
        previewer.PreviewText(wid, 'File not found: ' .. file)
        return
    else
        previewer.PreviewFile(wid, file)
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
    var [file, lnum, col] = ParseResult(result)
    exe 'tabnew ' .. fnameescape(file)
    cursor(lnum, col)
    exe 'norm! zz'
enddef

def OpenFileVSplit(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [file, lnum, col] = ParseResult(result)
    exe 'vsplit ' .. fnameescape(file)
    cursor(lnum, col)
    exe 'norm! zz'
enddef

def OpenFileSplit(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [file, lnum, col] = ParseResult(result)
    exe 'split ' .. fnameescape(file)
    cursor(lnum, col)
    exe 'norm! zz'
enddef

export def Start(opts: dict<any> = {})
    opts.title = has_key(opts, 'title') ? opts.title : 'Marks'

    var marks = execute('marks')->split("\n")->slice(1)
    bufnr = bufnr()

    selector.Start(marks, extend(opts, {
        select_cb: function('Select'),
        preview_cb: function('Preview'),
        actions: {
            "\<c-v>": function('OpenFileVSplit'),
            "\<c-s>": function('OpenFileSplit'),
            "\<c-t>": function('OpenFileTab'),
        }
    }))
enddef
