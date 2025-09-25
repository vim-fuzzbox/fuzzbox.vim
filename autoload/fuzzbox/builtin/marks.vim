vim9script

import autoload '../utils/selector.vim'
import autoload '../utils/previewer.vim'

var bufnr: number

def Select(wid: number, result: string)
    if empty(result)
        return
    endif
    var mark = result->matchstr('\v^\s*\zs\S+')
    exe $"normal! '{mark}"
enddef

def ParseResult(result: string): list<any>
    var mark = result->matchstr('\v^\s*\zs\S+')
    var marklist = extend(getmarklist(), getmarklist(bufnr))
    var markdata = marklist->filter((_, dict) => {
       return dict.mark == "'" .. mark
    })[0]
    var file = fnamemodify(get(markdata, 'file', bufname(bufnr)), ':p')
    var lnum = markdata.pos[1]
    return [file, lnum]
enddef

def Preview(wid: number, result: string)
    if wid == -1
        return
    endif
    if empty(result)
        previewer.PreviewText(wid, '')
        return
    endif
    var [file, lnum] = ParseResult(result)
    if !filereadable(file)
        previewer.PreviewText(wid, 'File not found: ' .. file)
        return
    endif
    previewer.PreviewFile(wid, file)
    win_execute(wid, 'norm! ' .. lnum .. 'G')
    win_execute(wid, 'norm! zz')
    clearmatches(wid)
    matchaddpos('fuzzboxPreviewLine', [lnum], 9999, -1,  {window: wid})
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

export def Start(opts: dict<any> = {})
    var marks = execute('marks')->split("\n")->slice(1)
    bufnr = bufnr()

    selector.Start(marks, extend(opts, {
        prompt_title: 'Mark (mark|line|col|file/text)',
        select_cb: function('Select'),
        preview_cb: function('Preview'),
        actions: {
            "\<c-v>": function('OpenFileVSplit'),
            "\<c-s>": function('OpenFileSplit'),
            "\<c-t>": function('OpenFileTab'),
        }
    }))
enddef
