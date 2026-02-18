vim9script

import autoload '../internal/selector.vim'
import autoload '../internal/popup.vim'

var tag_table: dict<any>
var tag_files: list<string>

def Select(wid: number, result: string)
    if result =~# '^[A-Z]'
        # User-defined command, check for nargs, send <CR> if no nargs
        var info = split(execute(':filter /\<' .. result .. '\>/ command ' .. result), '\n')[-1]
        var nargs = split(matchstr(info, '\<' .. result .. '\>\s\+\S'), '\s\+')[-1]
        feedkeys(':' .. result .. ' ', 'n')
        if nargs == "0"
            feedkeys("\<CR>", 'n')
        endif
    elseif !empty(result)
        # Built-in command, no check for nargs, just feed to cmdline
        feedkeys(':' .. result .. ' ', 'n')
    endif
enddef

def Preview(wid: number, result: string)
    if wid == -1
        return
    endif
    if empty(result)
        popup_settext(wid, '')
        popup_setoptions(wid, {title: ''})
        return
    endif
    var bufnr = winbufnr(wid)
    setbufvar(bufnr, '&syntax', 'help')
    var completions = getcompletion(':' .. result, 'help')
    if empty(completions)
        var definition = execute('verbose command ' .. result, 'silent!')->split("\n")
        if empty(definition)
            popup_settext(wid, 'No information available for command :' .. result)
        else
            definition = len(definition) > 3 ? definition->slice(0, 3) : definition
            popup_settext(wid, definition)
        endif
        win_execute(wid, 'norm! gg')
        popup_setoptions(wid, {title: ''})
        return
    endif
    var helptag = completions[0]
    var tag_file = tag_files[tag_table[helptag][2]]
    # Note: forward slash path separator tested on Windows, works fine
    var doc_file = fnamemodify(tag_file, ':h') .. '/' .. tag_table[helptag][0]
    popup_settext(wid, readfile(doc_file))
    popup.SetTitle(wid, fnamemodify(doc_file, ':t'))
    var tag_name = substitute(tag_table[helptag][1], '\v^(\/\*)(.*)(\*)$', '\2', '')
    win_execute(wid, "exec 'norm! ' .. search('\\V*" .. tag_name .. "*', 'w')")
    win_execute(wid, 'norm! zz')
enddef

export def Start(opts: dict<any> = {})
    opts.title = has_key(opts, 'title') ? opts.title : 'Commands'
    opts.preview_ratio = has_key(opts, 'preview_ratio') ? opts.preview_ratio : 0.6

    tag_files = reverse(split(globpath(&runtimepath, 'doc/tags', 1), '\n'))
    var file_index = 0
    for file in tag_files
        for line in readfile(file)
            var li = split(line)
            tag_table[li[0]] = [li[1], li[2], file_index]
        endfor
        file_index += 1
    endfor

    var li: list<string> = getcompletion('', 'command')
    var wids = selector.Start(li, extend(opts, {
        select_cb: function('Select'),
        preview_cb: function('Preview'),
    }))
enddef
