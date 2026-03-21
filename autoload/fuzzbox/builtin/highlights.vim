
vim9script

import autoload '../internal/selector.vim'

var preview_wid: number
var preview_mid: number

def Preview(wid: number, result: string)
    if wid == -1
        return
    endif
    win_execute(wid, "silent! search('\\M\^" .. result .. "\\s\\+xxx', 'cw')")
    win_execute(wid, 'norm! zz')
    if preview_mid > 0
        matchdelete(preview_mid, wid)
    endif
    var lnum = getcurpos(wid)[1]
    preview_mid = matchaddpos('fuzzboxPreviewMatch', [[lnum, 1, len(result)]], 999, -1,  {window: wid})
enddef

def Select(wid: number, result: string)
    setreg('*', result)
enddef

def TogglePreviewBg()
    var old = getwinvar(preview_wid, '&wincolor')
    if old == 'fuzzboxHighlights_whitebg'
        setwinvar(preview_wid, '&wincolor', 'Normal')
    else
        setwinvar(preview_wid, '&wincolor', 'fuzzboxHighlights_whitebg')
    endif
enddef

hi fuzzboxHighlights_whitebg ctermbg=white ctermfg=black guibg=white guifg=black

export def Start(opts: dict<any> = {})
    opts.title = has_key(opts, 'title') ? opts.title : 'Highlight Groups'
    opts.preview_ratio = has_key(opts, 'preview_ratio') ? opts.preview_ratio : 0.7

    # var highlights = execute('hi')->substitute('\v\n\s+', ' ', 'g')->split("\n")
    var highlights = execute('hi')->split("\n")

    var li: list<string> = getcompletion('', 'highlight')
    var wids = selector.Start(li, extend(opts, {
        preview_cb: function('Preview'),
        select_cb: function('Select'),
        actions: {
            "\<c-k>": function('TogglePreviewBg'),
        }
    }))

    preview_wid = wids.preview
    preview_mid = 0 # always reset to 0 to avoid clearing invalid match ids

    # set preview buffer's content
    setwinvar(preview_wid, '&number', 0)
    popup_settext(preview_wid, highlights)

    # add highlight to preview buffer
    var lnum: number
    for line in getbufline(winbufnr(preview_wid), 1, '$')
        lnum += 1
        var xxxidx = line->match('xxx')
        if xxxidx == -1
            continue
        endif
        var hlgroup = line->matchstr('\v^\zs\S+')
        matchaddpos(hlgroup, [[lnum, xxxidx + 1, 3]], 99, -1,  {window: preview_wid})
    endfor
enddef
