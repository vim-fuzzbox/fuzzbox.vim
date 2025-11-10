
vim9script

import autoload '../internal/selector.vim'

var hl_meta: dict<any>
var preview_wid: number

def Preview(wid: number, result: string)
    if wid == -1
        return
    endif
    if !has_key(hl_meta, result)
        return
    endif
    var line = hl_meta[result][0]
    win_execute(wid, 'normal! ' .. line .. 'G')
    win_execute(wid, 'normal! zz')
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

    var highlights_raw = substitute(execute('hi'), "\n", " ", "g") .. ' fuzzbox_dummyy xxx'
    var highlights: list<any> = []
    def Helper(s: any): number
        highlights->add(s)
        return 1
    enddef
    substitute(highlights_raw, '\zs[a-zA-Z0-9_.-]\+\s\+xxx[[:alnum:][:blank:]=#,]\{-}\ze\s\+\w\+\s*xxx',
        '\=Helper(submatch(0))', 'g')

    hl_meta = {}
    for idx in range(len(highlights))
        var hl_raw = highlights[idx]
        var xxxidx = hl_raw->match('xxx')
        var name = split(hl_raw)[0]
        hl_meta[name] = [idx + 1, xxxidx]
    endfor

    var wids = selector.Start(keys(hl_meta), extend(opts, {
        preview_cb: function('Preview'),
        select_cb: function('Select'),
        actions: {
            "\<c-k>": function('TogglePreviewBg'),
        }
    }))

    preview_wid = wids.preview
    var menu_wid = wids.menu

    setwinvar(preview_wid, '&number', 0)
    # set preview buffer's content
    popup_settext(preview_wid, highlights)

    # add highlight to preview buffer
    for [hl, parts] in items(hl_meta)
        var line = parts[0]
        var xxxidx = parts[1]
        var mid = matchaddpos(hl, [[line, xxxidx + 1, 3]], 99, -1,  {window: preview_wid})
    endfor
enddef
