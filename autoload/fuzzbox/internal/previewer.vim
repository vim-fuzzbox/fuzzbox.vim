vim9script

import autoload './popup.vim'
import './filetype.vim'

def IsBinary(path: string): bool
    # NUL byte check for binary files, used to avoid showing preview
    # Assumes a file encoding that does not allow NUL bytes, so will
    # generate false positives for UTF-16 and UTF-32, but the preview
    # window doesn't work for these encodings anyway, even with a BOM
    if !has('patch-9.0.0810')
        # Workaround for earlier versions of Vim with limited readblob()
        # Option to read only part of file finalised in patch 9.0.0810
        return match(readfile(path, '', 10), '\%x00') != -1
    endif
    return IsBinaryBlob(path)
enddef

# Note: use of legacy function a workaround for compilation failing when
# readblob() would be called with invalid args on earlier Vim versions
function IsBinaryBlob(path)
    for byte in readblob(a:path, 0, 128)
        if byte == 0 | return v:true | endif
    endfor
    return v:false
endfunction

def FTDetectModelines(content: list<string>): string
    if ( !&modeline || &modelines == 0 ) && !exists('g:loaded_securemodelines')
        return ''
    endif
    if empty(content)
        return ''
    endif
    try
        var modelines = len(content) >= &modelines ? &modelines : len(content)
        var pattern = '\M\C\s\?\(Vim\|vim\|vi\|ex\):\.\*\(ft\|filetype\)=\w\+'
        var matched = content[0 : modelines - 1]->matchstr(pattern)
        if empty(matched)
            matched = content[len(content) - modelines : -1]->matchstr(pattern)
        endif
        if !empty(matched)
            return matched->trim()->split('\M\(\s\+\|:\)')->filter((_, val) => {
                    return val =~# '^\M\C\(ft\|filetype\)=\w\+$'
                })[-1]->split('=')[-1]
        endif
    catch
        echohl ErrorMsg
        echom 'fuzzbox:' v:exception .. ' ' .. v:throwpoint
        echohl None
    endtry
    return ''
enddef

def PreviewMessage(wid: number, message: string)
    const pos = popup_getpos(wid)
    const line = repeat('╱', pos.width - 2)
    const len_message = len(message)
    const size_max = pos.width - 2 - len_message - 4
    const begin_line = repeat('╱', (size_max / 2))
    var end_line: string
    var lines = []

    if (size_max % 2) == 0
        end_line = begin_line
    else
        end_line = begin_line .. '╱'
    endif

    # Create the middle line with the message
    const line_message = begin_line ..  '  ' .. message .. '  ' .. end_line
    const line_space = begin_line ..  '  ' .. repeat(' ', len_message) .. '  ' .. end_line

    const height = pos.height - 6
    const middle = height / 2

    # Draw the top of the popup
    for i in range(0, middle)
        add(lines, line)
    endfor
    # Draw the message
    add(lines, line_space)
    add(lines, line_message)
    add(lines, line_space)
    # Draw the bottom of the popup
    for i in range(0, middle)
        add(lines, line)
    endfor
    setwinvar(wid, '&number', 0)
    setwinvar(wid, '&cursorline', 0)
    popup_settext(wid, lines)
enddef

def Reset(wid: number)
    win_execute(wid, 'syntax clear')
    setwinvar(wid, '&syntax', '')
    setwinvar(wid, '&filetype', '')
enddef

export def IsTextFile(wid: number): bool
    # Note: relies on PreviewFile() setting &filetype
    return !empty(getwinvar(wid, '&filetype'))
enddef

export def PreviewText(wid: number, text: string)
    Reset(wid)
    popup_setoptions(wid, {title: ''})
    popup_settext(wid, text)
enddef

export def PreviewFile(wid: number, path: string)
    Reset(wid)
    popup.SetTitle(wid, fnamemodify(path, ':t'))
    if !filereadable(path)
        PreviewText(wid, 'File not found: ' .. path)
        return
    endif
    if IsBinary(path)
        PreviewMessage(wid, 'Binary cannot be previewed')
        return
    endif
    if getfsize(path) / pow(1024, 2) > 5 # hard-coded 5MiB limit for now
        PreviewMessage(wid, 'File exceeds preview size limit')
        return
    endif
    var content = readfile(path)
    popup_settext(wid, content)
    setwinvar(wid, '&number', 1)
    setwinvar(wid, '&cursorline', 1)
    setwinvar(wid, '&synmaxcol', 1000) # no syntax highlighting very long lines
    if getfsize(path) / pow(1024, 2) > 2 # no syntax highlighting files > 2 MiB
        return
    endif
    var modelineft = FTDetectModelines(content)
    if empty(modelineft)
        win_execute(wid, 'silent! doautocmd fuzzboxFiletypeDetect User ' .. path)
    else
        win_execute(wid, 'noautocmd setlocal filetype=' .. modelineft)
    endif
    if empty(getwinvar(wid, '&filetype'))
        win_execute(wid, 'noautocmd setlocal filetype=text')
    endif
    win_execute(wid, 'setlocal syntax=' .. getwinvar(wid, '&filetype'))

    var re = &re
    try
        &re = 2 # workaround for E363: Pattern uses more memory than 'maxmempattern'
        win_execute(wid, 'setlocal syntax=' .. getwinvar(wid, '&filetype'))
    finally
        &re = re
    endtry
enddef
