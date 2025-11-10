vim9script

import autoload '../internal/selector.vim'
import autoload '../internal/previewer.vim'
import autoload '../internal/popup.vim'
import autoload '../internal/devicons.vim'
import autoload '../internal/helpers.vim'
import autoload '../internal/actions.vim'

var buf_dict: dict<any>

# Options
var exclude_buffers = exists('g:fuzzbox_buffers_exclude') ?
    g:fuzzbox_buffers_exclude : []

def Select(wid: number, result: string)
    if empty(result)
        return
    endif
    var [bufnr, lnum] = buf_dict[result][1 : 2]
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
    var [file, bufnr, lnum] = buf_dict[result][0 : 2]
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
    var [bufnr, lnum] = buf_dict[result][1 : 2]
    execute 'split'
    execute 'buffer ' .. bufnr
enddef

def OpenBufSplit(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [bufnr, lnum] = buf_dict[result][1 : 2]
    execute 'split'
    execute 'buffer ' .. bufnr
enddef

def OpenBufVSplit(wid: number, result: string)
    if empty(result)
        return
    endif
    popup_close(wid)
    var [bufnr, lnum] = buf_dict[result][1 : 2]
    execute 'vsplit'
    execute 'buffer ' .. bufnr
enddef

def GetBufList(): list<string>
    var buf_data = getbufinfo({buflisted: 1, bufloaded: 0})
    buf_dict = {}

    # skip excluded buffers - case-sensitive match on buftype or tail of file name
    if !empty(exclude_buffers)
        filter(buf_data, (_, buf) => {
            return index(exclude_buffers, fnamemodify(buf.name, ':t')) == -1
                && index(exclude_buffers, getbufvar(buf.bufnr, "&buftype")) == -1
        })
    endif

    reduce(buf_data, (acc, buf) => {
        var file = empty(buf.name) ? $"{buf.bufnr} [No Name]" : fnamemodify(buf.name, ":~:.")
        acc[file] = [buf.name, buf.bufnr, buf.lnum, buf.lastused]
        return acc
    }, buf_dict)

    return keys(buf_dict)->sort((a, b) => {
        return buf_dict[a][3] == buf_dict[b][3] ? 0 :
               buf_dict[a][3] <  buf_dict[b][3] ? 1 : -1
    })
enddef

def DeleteBuffer(wid: number, result: string)
    if empty(result)
        return
    endif
    var bufnr = buf_dict[result][1]
    execute ':bdelete ' .. bufnr
    var li = GetBufList()
    selector.UpdateMenu(li, [])
    selector.UpdateList(li)
    selector.RefreshMenu()
enddef

export def Start(opts: dict<any> = {})
    opts.title = has_key(opts, 'title') ? opts.title : 'Buffers'

    var wids = selector.Start(GetBufList(), extend(opts, {
        devicons: true,
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
