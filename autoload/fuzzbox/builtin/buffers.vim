vim9script

import autoload '../internal/selector.vim'
import autoload '../internal/previewer.vim'
import autoload '../internal/popup.vim'
import autoload '../internal/devicons.vim'
import autoload '../internal/helpers.vim'
import autoload '../internal/actions.vim'

# Options
var exclude_buffers = exists('g:fuzzbox_buffers_exclude') ?
    g:fuzzbox_buffers_exclude : []

var separator = g:fuzzbox_menu_separator

def ParseResult(result: string): list<any>
    var bufnr = result->matchstr('\v^\s*\zs\S+')->str2nr()
    var binfo = getbufinfo(bufnr)[0]
    return [binfo.name, binfo.bufnr, binfo.lnum]
enddef

def Select(wid: number, result: string)
    if empty(result)
        return
    endif
    var [file, bufnr, lnum] = ParseResult(result)
    # for special buffers, jump to window if visible in current tab
    if !empty(getbufvar(bufnr, '&buftype')) && bufwinnr(bufnr) != -1
        execute ':' .. bufwinnr(bufnr) .. 'wincmd w'
    else
        execute 'buffer ' .. bufnr
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
    var [file, bufnr, lnum] = ParseResult(result)
    if empty(file)
        previewer.PreviewText(wid, '')
        popup_settext(wid, getbufline(bufnr, 1, '$'))
    else
        previewer.PreviewFile(wid, file)
    endif
    win_execute(wid, 'norm! ' .. lnum .. 'G')
    win_execute(wid, 'norm! zz')
enddef

def OpenBufTab(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [file, bufnr, lnum] = ParseResult(result)
    execute 'tabnew'
    execute 'buffer ' .. bufnr
enddef

def OpenBufSplit(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [file, bufnr, lnum] = ParseResult(result)
    execute 'split'
    execute 'buffer ' .. bufnr
enddef

def OpenBufVSplit(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [file, bufnr, lnum] = ParseResult(result)
    execute 'vsplit'
    execute 'buffer ' .. bufnr
enddef

def GetBufList(): list<string>
    var buf_data: list<any>
    buf_data = getbufinfo({buflisted: 1, bufloaded: 0})

    # skip excluded buffers - case-sensitive match on buftype or tail of file name
    if !empty(exclude_buffers)
        filter(buf_data, (_, buf) => {
            return index(exclude_buffers, fnamemodify(buf.name, ':t')) == -1
                && index(exclude_buffers, getbufvar(buf.bufnr, "&buftype")) == -1
        })
    endif

    sort(buf_data, (a, b) => {
        return a.lastused == b.lastused ? 0 :
               a.lastused <  b.lastused ? 1 : -1
    })

    var fmt = ' %' .. len(string(bufnr('$'))) .. 'd %s' .. separator .. ' %s'
    return buf_data->map((_, val) => {
        var file = empty(val.name) ? '[No Name]' : fnamemodify(val.name, ":~:.")
        var bufnr = val.bufnr
        var flags = val.listed ? ' ' : 'u' # allow for possible toggle to include unlisted
        flags ..= bufnr == bufnr('')  ? '%' : (bufnr == bufnr('#') ? '#' : ' ')
        flags ..= val.hidden ? 'h' : 'a'
        flags ..= val.changed ? '+' : ' '

        # note: separator included for consistency with other selectors
        return printf(fmt, bufnr, flags, file)
    })
enddef

def DeleteBuffer(wid: number, result: string)
    if empty(result)
        return
    endif
    var [file, bufnr, lnum] = ParseResult(result)
    execute ':bdelete ' .. bufnr
    var li = GetBufList()
    selector.UpdateMenu(li, [])
    selector.UpdateList(li)
    selector.RefreshMenu()
enddef

export def Start(opts: dict<any> = {})
    opts.title = has_key(opts, 'title') ? opts.title : 'Buffers'

    var wids = selector.Start(GetBufList(), extend(opts, {
        select_cb: function('Select'),
        preview_cb: function('Preview'),
        actions: {
            "\<c-l>": function('DeleteBuffer'),
            "\<c-v>": function('OpenBufVSplit'),
            "\<c-s>": function('OpenBufSplit'),
            "\<c-t>": function('OpenBufTab'),
        }
    }))
enddef
