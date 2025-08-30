vim9script

import autoload './devicons.vim'
import autoload './popup.vim'
import autoload './helpers.vim'

var enable_devicons = devicons.Enabled()

export def OpenFile(wid: number, result: string, opts: dict<any>)
    if empty(result)
        return
    endif
    popup_close(wid)
    var cwd = len(get(opts, 'cwd', '')) > 0 ? opts.cwd : getcwd()
    var [buf, line, col] = split(result .. ':0:0', ':')[0 : 2]
    var bufnr = bufnr(buf)
    helpers.MoveToUsableWindow()
    if bufnr > 0 && !filereadable(buf)
        # for special buffers that cannot be edited
        execute 'buffer ' .. bufnr
    elseif cwd ==# getcwd()
        execute 'edit ' .. fnameescape(buf)
    else
        var path = cwd .. '/' .. buf
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

export def OpenFileTab(wid: number, result: string, opts: dict<any>)
    if empty(result)
        return
    endif
    popup_close(wid)
    var cwd = len(get(opts, 'cwd', '')) > 0 ? opts.cwd : getcwd()
    var [buf, line, col] = split(result .. ':0:0', ':')[0 : 2]
    var bufnr = bufnr(buf)
    if bufnr > 0 && !filereadable(buf)
        # for special buffers that cannot be edited
        execute 'tabnew'
        execute 'buffer ' .. bufnr
    elseif cwd ==# getcwd()
        execute 'tabnew ' .. fnameescape(buf)
    else
        var path = cwd .. '/' .. buf
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

export def OpenFileVSplit(wid: number, result: string, opts: dict<any>)
    if empty(result)
        return
    endif
    popup_close(wid)
    var cwd = len(get(opts, 'cwd', '')) > 0 ? opts.cwd : getcwd()
    var [buf, line, col] = split(result .. ':0:0', ':')[0 : 2]
    var bufnr = bufnr(buf)
    if bufnr > 0 && !filereadable(buf)
        # for special buffers that cannot be edited
        # avoid :sbuffer to bypass 'switchbuf=useopen'
        execute 'vnew'
        execute 'buffer ' .. bufnr
    elseif cwd ==# getcwd()
        execute 'vsp ' .. fnameescape(buf)
    else
        var path = cwd .. '/' .. buf
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

export def OpenFileSplit(wid: number, result: string, opts: dict<any>)
    if empty(result)
        return
    endif
    popup_close(wid)
    var cwd = len(get(opts, 'cwd', '')) > 0 ? opts.cwd : getcwd()
    var [buf, line, col] = split(result .. ':0:0', ':')[0 : 2]
    var bufnr = bufnr(buf)
    if bufnr > 0 && !filereadable(buf)
        # for special buffers that cannot be edited
        # avoid :sbuffer to bypass 'switchbuf=useopen'
        execute 'new'
        execute 'buffer ' .. bufnr
    elseif cwd ==# getcwd()
        execute 'sp ' .. fnameescape(buf)
    else
        var path = cwd .. '/' .. buf
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
