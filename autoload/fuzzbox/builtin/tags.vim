vim9script

import autoload '../internal/selector.vim'
import autoload '../internal/previewer.vim'
import autoload '../internal/helpers.vim'

var tag_list: list<string>
var tag_files = []
var tag_dirs = []
var cwd: string
var fs = helpers.PathSep()
var menu_wid: number

def ParseResult(result: string): list<any>
    # Tags file format, see https://docs.ctags.io/en/latest/man/tags.5.html
    # {tagname}<Tab>{tagfile}<Tab>{tagaddress}[;"<Tab>{tagfield}..]
    var parts = result->split("\t")
    var [tagname, tagfile] = parts[0 : 1]
    var rest = parts[2 : -1]->join("\t")
    var tagaddress = rest->split(';"\t')[0]
    return [tagname, tagfile, tagaddress]
enddef

def EscQuotes(str: string): string
    return substitute(str, "'", "''", 'g')
enddef

# Find the first readable path relative to tagfiles locations. Can potentially
# expand to the wrong path if there is more than one match, but should be rare.
def ExpandPath(path: string): string
    for tag_dir in tag_dirs
        if filereadable(tag_dir .. fs .. path)
            return tag_dir .. fs .. path
        endif
    endfor
    return path
enddef

def JumpToAddress(tagaddress: string)
    for excmd in tagaddress->split(";")
        if trim(excmd) =~ '^\d\+$'
            execute("silent! cursor(" .. excmd .. ", 1)")
        else
            var pattern = excmd->substitute('^\/', '', '')->substitute('\M\/;\?"\?$', '', '')
            execute("silent! search('\\M" .. EscQuotes(pattern) .. "', 'cw')")
        endif
    endfor
    execute('norm! zz')
enddef

def Select(wid: number, result: string)
    if empty(result)
        return
    endif
    var [tagname, tagfile, tagaddress] = ParseResult(result)
    var path = ExpandPath(tagfile)
    if filereadable(path)
        helpers.MoveToUsableWindow()
        exe 'edit ' .. fnameescape(path)
        JumpToAddress(tagaddress)
    endif
enddef

def Preview(wid: number, result: string)
    if wid == -1
        return
    endif
    if empty(result)
        previewer.PreviewText(wid, '')
        return
    endif
    var [tagname, tagfile, tagaddress] = ParseResult(result)
    var path = ExpandPath(tagfile)
    previewer.PreviewFile(wid, path)
    for excmd in tagaddress->split(";")
        if trim(excmd) =~ '^\d\+$'
            win_execute(wid, "silent! cursor(" .. excmd .. ", 1)")
        else
            var pattern = excmd->substitute('^\/', '', '')->substitute('\M\/;\?"\?$', '', '')
            win_execute(wid, "silent! search('\\M" .. EscQuotes(pattern) .. "', 'cw')")
            clearmatches(wid)
            win_execute(wid, "silent! matchadd('fuzzboxPreviewMatch', '\\M" .. EscQuotes(pattern) .. "')")
        endif
    endfor
    win_execute(wid, 'norm! zz')
enddef

def OpenFileTab(wid: number, result: string, opts: dict<any>)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [tagname, tagfile, tagaddress] = ParseResult(result)
    var path = ExpandPath(tagfile)
    if filereadable(path)
        exe 'tabnew ' .. fnameescape(path)
        JumpToAddress(tagaddress)
    endif
enddef

def OpenFileVSplit(wid: number, result: string, opts: dict<any>)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [tagname, tagfile, tagaddress] = ParseResult(result)
    var path = ExpandPath(tagfile)
    if filereadable(path)
        exe 'vsplit ' .. fnameescape(path)
        JumpToAddress(tagaddress)
    endif
enddef

def OpenFileSplit(wid: number, result: string, opts: dict<any>)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [tagname, tagfile, tagaddress] = ParseResult(result)
    var path = ExpandPath(tagfile)
    if filereadable(path)
        exe 'split ' .. fnameescape(path)
        JumpToAddress(tagaddress)
    endif
enddef

export def Start(opts: dict<any> = {})
    cwd = len(get(opts, 'cwd', '')) > 0 ? opts.cwd : getcwd()
    var original_cwd = getcwd()
    exe 'silent lcd ' .. cwd
    try
        tag_files = tagfiles()
        if empty(tag_files)
            # copied from fzf.vim, thanks @junegunn
            inputsave()
            echohl WarningMsg
            var gen = input('No tags file in ' .. fnamemodify(cwd, ':~') .. ', generate? (y/N) ')
            echohl None
            inputrestore()
            redraw
            if gen =~? '^y'
                if ! executable('ctags')
                    throw "Missing executable ctags, please install Universal Ctags"
                else
                    var ver = system('ctags --version')
                    if ver !~? "Universal"
                        throw "Incompatible ctags version, please install Universal Ctags"
                    endif
                endif
                var out = system('ctags -R')
                tag_files = tagfiles()
                if empty(tag_files)
                    throw 'Failed to create tags file: ' .. out
                else
                    echo 'Created tags file'
                endif
            endif
        endif

        tag_list = []
        # Possible TODO: use readtags program here, would remove additional info
        # and could also be used to format the lines nicely (fzf.vim does this)
        for path in tag_files
            var lines = readfile(path)
            tag_list += lines[match(lines, '^[^!]') : -1]
        endfor

        tag_dirs = tag_files->map((_, val) => {
            return fnamemodify(stridx(val, fs) == 0 ? val : cwd .. fs .. val, ':h')
        })
    catch
        echoerr v:exception
    finally
        exe 'silent lcd ' .. original_cwd
    endtry

    if empty(tag_list)
        echo "No tags found"
        return
    endif

    var wids = selector.Start(tag_list, extend(opts, {
        async: true,
        counter: true,
        select_cb: function('Select'),
        preview_cb: function('Preview'),
        actions: {
            "\<c-v>": function('OpenFileVSplit'),
            "\<c-s>": function('OpenFileSplit'),
            "\<c-t>": function('OpenFileTab'),
        }
    }))
    menu_wid = wids.menu
enddef
