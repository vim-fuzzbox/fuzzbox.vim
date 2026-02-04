vim9script

scriptencoding utf-8

import autoload '../internal/selector.vim'
import autoload '../internal/popup.vim'

var raw_lines: list<string>
var file_type: string
var file_name: string
var menu_wid: number

var separator = g:fuzzbox_menu_separator

def Select(wid: number, result: string)
    if empty(result)
        return
    endif
    var lnum = str2nr(split(result, separator)[0])
    exe 'norm! ' .. lnum .. 'G'
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
    var lnum = str2nr(split(result, separator)[0])
    if popup_getpos(wid).lastline == 1
        popup.SetTitle(wid, fnamemodify(file_name, ':t'))
        popup_settext(wid, raw_lines)
        setbufvar(preview_bufnr, '&syntax', file_type)
    endif
    win_execute(wid, 'norm! ' .. lnum .. 'G')
    win_execute(wid, 'norm! zz')
    clearmatches(wid)
    matchaddpos('fuzzboxPreviewLine', [lnum], 999, -1,  {window: wid})
enddef

def OpenFileTab(wid: number, result: string, opts: dict<any>)
    if empty(result)
        return
    endif
    popup_close(wid)
    var lnum = str2nr(split(result, separator)[0])
    exe 'tabnew ' .. fnameescape(file_name)
    exe 'norm! ' .. lnum .. 'G'
    exe 'norm! zz'
enddef

def OpenFileVSplit(wid: number, result: string, opts: dict<any>)
    if empty(result)
        return
    endif
    popup_close(wid)
    var lnum = str2nr(split(result, separator)[0])
    exe 'vsplit ' .. fnameescape(file_name)
    exe 'norm! ' .. lnum .. 'G'
    exe 'norm! zz'
enddef

def OpenFileSplit(wid: number, result: string, opts: dict<any>)
    if empty(result)
        return
    endif
    popup_close(wid)
    var lnum = str2nr(split(result, separator)[0])
    exe 'split ' .. fnameescape(file_name)
    exe 'norm! ' .. lnum .. 'G'
    exe 'norm! zz'
enddef

def SendToQuickfix(wid: number, result: string, opts: dict<any>)
    var bufnr = winbufnr(wid)
    var lines: list<any>
    lines = reverse(getbufline(bufnr, 1, "$"))
    filter(lines, (_, val) => !empty(val))
    setqflist(map(lines, (_, val) => {
        var [lnum, text] = split(val, separator)
        var dict = {
            filename: file_name,
            lnum: str2nr(lnum),
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
    opts.title = has_key(opts, 'title') ? opts.title : 'Lines in Buffer'

    raw_lines = getline(1, '$')
    file_type = &filetype
    file_name = expand('%')
    var max_line_len = len(string(line('$')))
    var lines = reduce(raw_lines,
       (a, v) => add(a, printf(' %' .. max_line_len .. 'd ' .. separator .. ' %s', len(a) + 1,  v)), [])

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
