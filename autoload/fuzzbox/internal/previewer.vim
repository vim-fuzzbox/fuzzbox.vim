vim9script

import autoload './popup.vim'
import './filetype.vim'

var preview_image = exists('g:fuzzbox_preview_image') ? g:fuzzbox_preview_image : false

const PDF_SIGNATURE = '%PDF-'
# note: str2blob() only added in vim 9.1.1016
const PDF_SIGNATURE_BLOB = list2blob(str2list(PDF_SIGNATURE))

def IsBinary(path: string): bool
    # NUL byte check for binary files, used to avoid showing preview
    # Assumes a file encoding that does not allow NUL bytes, so will
    # generate false positives for UTF-16 and UTF-32, but the preview
    # window doesn't work for these encodings anyway, even with a BOM
    if !has('patch-9.0.0810')
        # Workaround for earlier versions of Vim with limited readblob()
        # Option to read only part of file finalised in patch 9.0.0810
        var lines = readfile(path, '', 10)
        if !empty(lines) && type(lines[0]) == v:t_string
             if lines[0][0 : len(PDF_SIGNATURE) - 1] == PDF_SIGNATURE
                 return true
             endif
        endif
        return match(lines, '\%x00') != -1
    endif
    return IsBinaryBlob(path)
enddef

# Note: use of legacy function a workaround for compilation failing when
# readblob() would be called with invalid args on earlier Vim versions
# Check first 2048 bytes as some binary formats have a long text header
# Specific check for PDF file signature because PDF headers can be huge
function IsBinaryBlob(path)
    let blob = readblob(a:path, 0, 2048)
    if blob[0 : len(s:PDF_SIGNATURE) - 1] == s:PDF_SIGNATURE_BLOB
        return v:true
    endif
    return index(blob, 0) != -1
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
        var pattern = '\M\C^\.\{-,10}\s\?\(Vim\|vim\|vi\| ex\):\.\{-,50}\(ft\|filetype\)=\w\+'
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
    win_execute(wid, 'norm! gg')
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

# Note: text can be any type to allow array of lines or string
export def PreviewText(wid: number, text: any, lnum: number = 0, col: number = 0, end_col: number = 0)
    Reset(wid)
    popup.SetTitle(wid, '')
    popup_settext(wid, text)
    if lnum > 0
        win_execute(wid, 'norm! ' .. lnum .. 'G')
        win_execute(wid, 'norm! zz')
        clearmatches(wid)
        if end_col > col
            matchaddpos('fuzzboxPreviewMatch', [[lnum, col, end_col - col]], 999, -1,  {window: wid})
        else
            matchaddpos('fuzzboxPreviewLine', [lnum], 999, -1,  {window: wid})
            if col > 0
                matchaddpos('fuzzboxPreviewCol', [[lnum, col]], 9999, -1,  {window: wid})
            endif
        endif
    else
        win_execute(wid, 'norm! gg')
    endif
enddef

# Actually detect if the terminal has sixel support by sending a primary device
# attributes (DA1) query to check, just because $TERM is set to some xterm does
# not mean the terminal program supports sixel, e.g. Apple Terminal, Alacritty
# See https://vt100.net/docs/vt510-rm/DA1.html
# FIXME: I have no idea if this works or blows up on Windows, to be tested!
var term_has_sixel: bool
def SetTermHasSixel()
    if !has('gui_running') && has('image_popup') && exists_compiled('v:imagebackend') && v:imagebackend == 'sixel'
        augroup FuzzboxTermHasSixel
            autocmd!
            autocmd TermResponseAll da1 {
                term_has_sixel = v:termda1->matchstr('\[?\zs[0-9;]*\zec')->split(';')->index('4') >= 0
            }
        augroup END
        echoraw("\<Esc>[c")
    endif
enddef
SetTermHasSixel()

var has_magick: any
def PreviewImage(wid: number, path: string)
    if empty(has_magick)
        has_magick = executable('magick')
    endif
    if !has('image_popup') || !has_magick
        PreviewMessage(wid, 'Image preview not supported')
        return
    endif

    var cmd: string
    var width: number
    var height: number
    var tmpname = tempname() .. '.rgb'
    var cell_px = exists_compiled('*getcellpixels') ? getcellpixels() : []
    if !empty(cell_px) # getcellpixels() returns [] on failure
        var size_pop = popup_getpos(wid)
        width = (size_pop.core_width) * cell_px[0]
        height = (size_pop.core_height) * cell_px[1]
        # FIXME: No allowance for GUI Vim
        if exists_compiled('v:imagebackend') && v:imagebackend == 'kitty'
            cmd = $'magick {shellescape(path .. "[0]")} -background "transparent" +repage -resize "{width}x{height}>" -gravity center -extent {width}x{height} -depth 8 rgba:{shellescape(tmpname)}'
        elseif exists_compiled('v:imagebackend') && v:imagebackend == 'sixel' && term_has_sixel
            # transparent background not supported, remove alpha channel and set
            # background to match the bg color reported by Vim, if possible
            var rgb = exists_compiled('*getbgcolor') ? getbgcolor() : []
            var bg = empty(rgb) ? 'gray' : printf('#%02x%02x%02x', rgb[0], rgb[1], rgb[2])
            cmd = $'magick {shellescape(path .. "[0]")} -background "{bg}" -alpha remove -alpha off +repage -resize "{width}x{height}>" -gravity center -extent {width}x{height} -depth 8 rgb:{shellescape(tmpname)}'
        endif
    endif
    if empty(cmd)
        PreviewMessage(wid, 'Image preview not supported')
        return
    endif

    setwinvar(wid, '&number', 0)
    setwinvar(wid, '&cursorline', 0)
    popup_settext(wid, '')

    # Use silent to avoid stray characters showing on screen, see :h system()
    silent var output = system(cmd)

    if v:shell_error != 0
        echohl ErrorMsg | echom output | echohl None
        delete(tmpname)
        return
    endif

    try
        var blob = readblob(tmpname)
        popup_setoptions(wid, {
            image: {
                data: blob,
                width: width,
                height: height,
            },
        })
    catch
        echohl ErrorMsg
        echom v:exception .. ' ' .. v:throwpoint
        echohl None
    finally
        delete(tmpname)
    endtry
enddef

export def PreviewFile(wid: number, path: string, lnum: number = 0, col: number = 0, end_col: number = 0)
    Reset(wid)
    popup.SetTitle(wid, fnamemodify(path, ':t'))
    if !filereadable(path)
        PreviewText(wid, 'File not found: ' .. path)
        return
    endif
    if getfsize(path) / pow(1024, 2) > 5 # hard-coded 5MiB limit for now
        PreviewMessage(wid, 'File exceeds preview size limit')
        return
    endif
    if IsBinary(path)
        const ext = fnamemodify(path, ':e')->tolower()
        if preview_image && index(['png', 'jpg', 'jpeg', 'bmp', 'gif'], ext) != -1
            PreviewImage(wid, path)
            return
        endif
        PreviewMessage(wid, 'Binary cannot be previewed')
        return
    endif
    var content = readfile(path)
    popup_settext(wid, content)
    setwinvar(wid, '&number', 1)
    setwinvar(wid, '&cursorline', 1)
    setwinvar(wid, '&synmaxcol', 1000) # no syntax highlighting very long lines
    if getfsize(path) / pow(1024, 2) > 2 # no syntax highlighting files > 2 MiB
        if lnum > 0
            win_execute(wid, 'norm! ' .. lnum .. 'G')
            win_execute(wid, 'norm! zz')
        else
            win_execute(wid, 'norm! gg')
        endif
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

    var re = &re
    try
        &re = 2 # workaround for E363: Pattern uses more memory than 'maxmempattern'
        win_execute(wid, 'setlocal syntax=' .. getwinvar(wid, '&filetype'))
    catch
        echohl ErrorMsg
        echom 'fuzzbox:' v:exception .. ' ' .. v:throwpoint
        echohl None
    finally
        &re = re
    endtry

    if lnum > 0
        win_execute(wid, 'norm! ' .. lnum .. 'G')
        win_execute(wid, 'norm! zz')
        clearmatches(wid)
        if end_col > col
            matchaddpos('fuzzboxPreviewMatch', [[lnum, col, end_col - col]], 999, -1,  {window: wid})
        else
            matchaddpos('fuzzboxPreviewLine', [lnum], 999, -1,  {window: wid})
            if col > 0
                matchaddpos('fuzzboxPreviewCol', [[lnum, col]], 9999, -1,  {window: wid})
            endif
        endif
    else
        win_execute(wid, 'norm! gg')
    endif
enddef
