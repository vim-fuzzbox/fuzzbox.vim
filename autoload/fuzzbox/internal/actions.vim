vim9script

import autoload './devicons.vim'
import autoload './popup.vim'
import autoload './previewer.vim'
import autoload './helpers.vim'

var enable_devicons = devicons.Enabled()

export def PreviewFile(wid: number, result: string, opts: dict<any> = {})
    if wid == -1
        return
    endif
    if empty(result)
        previewer.PreviewText(wid, '')
        return
    endif
    var cwd = len(get(opts, 'cwd', '')) > 0 ? opts.cwd : getcwd()
    var [file, line, col] = split(result .. ':0:0', ':')[0 : 2]
    var path = cwd ==# getcwd() ? file : cwd .. '/' .. file
    previewer.PreviewFile(wid, fnamemodify(path, ':p'))
    if str2nr(line) > 0
        win_execute(wid, 'norm! ' .. line .. 'G')
        win_execute(wid, 'norm! zz')
    else
        win_execute(wid, 'norm! gg')
    endif
enddef

export def OpenFile(wid: number, result: string, opts: dict<any> = {})
    if empty(result)
        return
    endif
    popup_close(wid)
    var cwd = len(get(opts, 'cwd', '')) > 0 ? opts.cwd : getcwd()
    var [file, line, col] = split(result .. ':0:0', ':')[0 : 2]
    helpers.MoveToUsableWindow()
    if cwd ==# getcwd()
        execute 'edit ' .. fnameescape(file)
    else
        var path = cwd .. '/' .. file
        execute 'edit ' .. fnameescape(path)
    endif
    if str2nr(line) > 0
        if str2nr(col) > 0
            cursor(str2nr(line), str2nr(col))
        else
            exe 'norm! ' .. line .. 'G'
        endif
        exe 'norm! zz'
    endif
enddef

export def OpenFileTab(wid: number, result: string, opts: dict<any> = {})
    if empty(result)
        return
    endif
    popup_close(wid)
    var cwd = len(get(opts, 'cwd', '')) > 0 ? opts.cwd : getcwd()
    var [file, line, col] = split(result .. ':0:0', ':')[0 : 2]
    if cwd ==# getcwd()
        execute 'tabnew ' .. fnameescape(file)
    else
        var path = cwd .. '/' .. file
        execute 'tabnew ' .. fnameescape(path)
    endif
    if str2nr(line) > 0
        if str2nr(col) > 0
            cursor(str2nr(line), str2nr(col))
        else
            exe 'norm! ' .. line .. 'G'
        endif
        exe 'norm! zz'
    endif
enddef

export def OpenFileVSplit(wid: number, result: string, opts: dict<any> = {})
    if empty(result)
        return
    endif
    popup_close(wid)
    var cwd = len(get(opts, 'cwd', '')) > 0 ? opts.cwd : getcwd()
    var [file, line, col] = split(result .. ':0:0', ':')[0 : 2]
    if cwd ==# getcwd()
        execute 'vsp ' .. fnameescape(file)
    else
        var path = cwd .. '/' .. file
        execute 'vsp ' .. fnameescape(path)
    endif
    if str2nr(line) > 0
        if str2nr(col) > 0
            cursor(str2nr(line), str2nr(col))
        else
            exe 'norm! ' .. line .. 'G'
        endif
        exe 'norm! zz'
    endif
enddef

export def OpenFileSplit(wid: number, result: string, opts: dict<any> = {})
    if empty(result)
        return
    endif
    popup_close(wid)
    var cwd = len(get(opts, 'cwd', '')) > 0 ? opts.cwd : getcwd()
    var [file, line, col] = split(result .. ':0:0', ':')[0 : 2]
    if cwd ==# getcwd()
        execute 'sp ' .. fnameescape(file)
    else
        var path = cwd .. '/' .. file
        execute 'sp ' .. fnameescape(path)
    endif
    if str2nr(line) > 0
        if str2nr(col) > 0
            cursor(str2nr(line), str2nr(col))
        else
            exe 'norm! ' .. line .. 'G'
        endif
        exe 'norm! zz'
    endif
enddef

export def SendToQuickfix(wid: number, result: string, opts: dict<any>)
    var has_devicons = enable_devicons && has_key(opts, 'devicons') && opts.devicons
    var bufnr = winbufnr(wid)
    var lines: list<any>
    lines = reverse(getbufline(bufnr, 1, "$"))
    filter(lines, (_, val) => !empty(val))
    setqflist(map(lines, (_, val) => {
        var [path, line, col] = split(val .. ':1:1', ':')[0 : 2]
        var text = split(val, ':' .. line .. ':' .. col .. ':')[-1]
        if has_devicons
            if path == text
                text = devicons.RemoveDevicon(text)
            endif
            path = devicons.RemoveDevicon(path)
        endif
        var dict = {
            filename: path,
            lnum: str2nr(line),
            col: str2nr(col),
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

export def MenuToggleWrap(wid: number, result: string, opts: dict<any>)
    var linenr = line('.', wid)
    win_execute(wid, 'set wrap!')
    if opts.dropdown
        win_execute(wid, 'norm! G')
        win_execute(wid, 'norm! gg')
    else
        win_execute(wid, 'norm! gg')
        win_execute(wid, 'norm! G')
    endif
    win_execute(wid, 'norm! ' .. linenr .. 'G')
enddef
