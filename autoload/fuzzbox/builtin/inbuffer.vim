vim9script

scriptencoding utf-8

import autoload '../utils/selector.vim'
import autoload '../utils/popup.vim'

var raw_lines: list<string>
var file_type: string
var file_name: string
var menu_wid: number

def Select(wid: number, result: string)
    if empty(result)
        return
    endif
    var linenr = str2nr(split(result, ':')[0])
    exe 'norm! ' .. linenr .. 'G'
    norm! zz
enddef

def Preview(wid: number, result: string)
    if wid == -1
        return
    endif
    if empty(result)
        popup_settext(wid, '')
        return
    endif
    var preview_bufnr = winbufnr(wid)
    var lnum = split(trim(result[0 : 10]), ' ')[0]
    if popup_getpos(wid).lastline == 1
        popup.SetTitle(wid, fnamemodify(file_name, ':t'))
        popup_settext(wid, raw_lines)
        setbufvar(preview_bufnr, '&syntax', file_type)
    endif
    win_execute(wid, 'norm! ' .. lnum .. 'G')
    win_execute(wid, 'norm! zz')
enddef

def OpenFileTab(wid: number, result: string, opts: dict<any>)
    if empty(result)
        return
    endif
    popup_close(wid)
    var line = str2nr(split(result, '│')[0])
    exe 'tabnew ' .. fnameescape(file_name)
    exe 'norm! ' .. line .. 'G'
    exe 'norm! zz'
enddef

def OpenFileVSplit(wid: number, result: string, opts: dict<any>)
    if empty(result)
        return
    endif
    popup_close(wid)
    var line = str2nr(split(result, '│')[0])
    exe 'vsplit ' .. fnameescape(file_name)
    exe 'norm! ' .. line .. 'G'
    exe 'norm! zz'
enddef

def OpenFileSplit(wid: number, result: string, opts: dict<any>)
    if empty(result)
        return
    endif
    popup_close(wid)
    var line = str2nr(split(result, '│')[0])
    exe 'split ' .. fnameescape(file_name)
    exe 'norm! ' .. line .. 'G'
    exe 'norm! zz'
enddef

def SendToQuickfix(wid: number, result: string, opts: dict<any>)
    var bufnr = winbufnr(wid)
    var lines: list<any>
    lines = reverse(getbufline(bufnr, 1, "$"))
    filter(lines, (_, val) => !empty(val))
    setqflist(map(lines, (_, val) => {
        var [line, text] = split(val, '│')
        var dict = {
            filename: file_name,
            lnum: str2nr(line),
            col: 1,
            text: text }
        return dict
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
    raw_lines = getline(1, '$')
    file_type = &filetype
    file_name = expand('%')
    var max_line_len = len(string(line('$')))
    var lines = reduce(raw_lines,
       (a, v) => add(a, printf(' %' .. max_line_len .. 'd │ %s', len(a) + 1,  v)), [])

    var wids = selector.Start(lines, extend(opts, {
        select_cb: function('Select'),
        preview_cb: function('Preview'),
        actions: {
            "\<c-v>": function('OpenFileVSplit'),
            "\<c-s>": function('OpenFileSplit'),
            "\<c-t>": function('OpenFileTab'),
            "\<c-q>": function('SendToQuickfix'),
        }
    }))
    menu_wid = wids.menu

    if len(get(opts, 'search', '')) > 0
        popup.SetPrompt(opts.search)
    endif
enddef
