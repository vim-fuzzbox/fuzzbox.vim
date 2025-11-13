vim9script

import autoload './devicons.vim'
import autoload './popup.vim'
import autoload './previewer.vim'
import autoload './helpers.vim'

var enable_devicons = devicons.Enabled()
var iswin = helpers.IsWin()

# Note: for actions that open or preview files, fnamemodify() is used to ensure
# a readable path. On Unix emulation envinronments like Git-Bash / Mingw-w64,
# external programs like rg may return file paths with Windows file separators,
# but Vim thinks it has Unix so needs a Unix file separator to read the file.
# FIXME: might also be addressed using --path-separator option with rg and fd

# Parse result and return a list with file, line number and column number
# Line and column are set to 0 when they are not included in the result
# Do not change these defaults without updating any callers relying on them
def ParseResult(result: string): list<any>
    if iswin && result =~ '^\a:'
        var [drive, path, line, col] = split(result .. ':0:0', ':')[0 : 3]
        return [drive .. ':' .. path, str2nr(line), str2nr(col)]
    endif
    var [file, line, col] = split(result .. ':0:0', ':')[0 : 2]
    return [file, str2nr(line), str2nr(col)]
enddef

export def PreviewFile(wid: number, result: string, opts: dict<any> = {})
    if wid == -1
        return
    endif
    if empty(result)
        previewer.PreviewText(wid, '')
        return
    endif
    var cwd = len(get(opts, 'cwd', '')) > 0 ? opts.cwd : getcwd()
    var [file, line, col] = ParseResult(result)
    var path = cwd ==# getcwd() ? file : cwd .. '/' .. file
    previewer.PreviewFile(wid, fnamemodify(path, ':p'))
    if !previewer.IsTextFile(wid)
        win_execute(wid, 'norm! gg')
        return
    endif
    if line > 0
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
    var [file, line, col] = ParseResult(result)
    var path = cwd ==# getcwd() ? file : cwd .. '/' .. file
    helpers.MoveToUsableWindow()
    execute 'edit ' .. fnameescape(fnamemodify(path, ':p:~:.'))
    if line > 0
        if col > 0
            cursor(line, col)
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
    var [file, line, col] = ParseResult(result)
    var path = cwd ==# getcwd() ? file : cwd .. '/' .. file
    execute 'tabnew ' .. fnameescape(fnamemodify(path, ':p:~:.'))
    if line > 0
        if col > 0
            cursor(line, col)
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
    var [file, line, col] = ParseResult(result)
    var path = cwd ==# getcwd() ? file : cwd .. '/' .. file
    execute 'vsplit ' .. fnameescape(fnamemodify(path, ':p:~:.'))
    if line > 0
        if col > 0
            cursor(line, col)
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
    var [file, line, col] = ParseResult(result)
    var path = cwd ==# getcwd() ? file : cwd .. '/' .. file
    execute 'split ' .. fnameescape(fnamemodify(path, ':p:~:.'))
    if line > 0
        if col > 0
            cursor(line, col)
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
    setqflist([], ' ', {nr: '$'})

    setqflist(map(lines, (_, val) => {
        var [file, line, col] = ParseResult(val)
        line = line > 0 ? line : 1
        col = col > 0 ? col : 1
        var text = split(val, ':' .. line .. ':' .. col .. ':')[-1]
        if has_devicons
            if file == text
                text = devicons.RemoveDevicon(text)
            endif
            file = devicons.RemoveDevicon(file)
        endif
        var dict = {
            filename: file,
            lnum: line,
            col: col,
            text: text }
        return dict
    }), 'r')

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
