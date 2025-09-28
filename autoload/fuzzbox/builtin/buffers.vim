vim9script

import autoload '../internal/selector.vim'
import autoload '../internal/previewer.vim'
import autoload '../internal/popup.vim'
import autoload '../internal/devicons.vim'
import autoload '../internal/helpers.vim'
import autoload '../internal/actions.vim'

var buf_dict: dict<any>
var _actions: dict<any>
var _window_width: float

# Options
var exclude_buffers = exists('g:fuzzbox_buffers_exclude') ?
    g:fuzzbox_buffers_exclude : []

var keymaps = {
    'delete_file': "",
    'wipe_buffer': "",
    'close_buffer': "\<c-l>",
}
if exists('g:fuzzbox_buffers_keymap')
    keymaps->extend(g:fuzzbox_buffers_keymap, 'force')
endif

# deprecated delete_buffer keymap, renamed to delete_file, that's what is does
if has_key(keymaps, "delete_buffer") && !empty(keymaps.delete_buffer) && empty(keymaps.delete_file)
    keymaps.delete_file = keymaps.delete_buffer
endif

def Preview(wid: number, result: string)
    if wid == -1
        return
    endif
    if empty(result)
        previewer.PreviewText(wid, '')
        return
    endif
    var file: string
    var lnum: number
    file = buf_dict[result][0]
    lnum = buf_dict[result][2]
    previewer.PreviewFile(wid, file)
    win_execute(wid, 'norm! ' .. lnum .. 'G')
    win_execute(wid, 'norm! zz')
enddef

def GetBufList(): list<string>
    var buf_data = getbufinfo({buflisted: 1, bufloaded: 0})
    buf_dict = {}

    # skip [No Name] buffers
    filter(buf_data, (_, buf) => !empty(buf.name))

    # skip excluded buffers - case-sensitive match on buftype or tail of file name
    if !empty(exclude_buffers)
        filter(buf_data, (_, buf) => {
            return index(exclude_buffers, fnamemodify(buf.name, ':t')) == -1
                && index(exclude_buffers, getbufvar(buf.bufnr, "&buftype")) == -1
        })
    endif

    reduce(buf_data, (acc, buf) => {
        var file = fnamemodify(buf.name, ":~:.")
        acc[file] = [buf.name, buf.bufnr, buf.lnum, buf.lastused]
        return acc
    }, buf_dict)

    var bufs = keys(buf_dict)->sort((a, b) => {
        return buf_dict[a][3] == buf_dict[b][3] ? 0 :
               buf_dict[a][3] <  buf_dict[b][3] ? 1 : -1
    })
    return bufs
enddef

def DeleteSelectedBuffer(wipe: bool)
    var buf = popup.GetCursorItem()
    if buf == ''
        return
    endif
    if wipe
        execute(':bwipeout ' .. buf)
    else
        execute(':bdelete ' .. buf)
    endif
    var li = GetBufList()
    selector.UpdateMenu(li, [])
    selector.UpdateList(li)
    selector.RefreshMenu()
enddef

def WipeSelectedBuffer(wid: number, result: string, opts: dict<any>)
    DeleteSelectedBuffer(true)
enddef

def CloseSelectedBuffer(wid: number, result: string, opts: dict<any>)
    DeleteSelectedBuffer(false)
enddef

def DeleteSelectedFile(wid: number, result: string, opts: dict<any>)
    var buf = popup.GetCursorItem()
    var choice = confirm('Delete file ' .. buf .. '. Are you sure?', "&Yes\n&No")
    if choice != 1
        return
    endif
    delete(buf)
    DeleteSelectedBuffer(true)
enddef

_actions[keymaps.delete_file] = function("DeleteSelectedFile")
_actions[keymaps.wipe_buffer] = function("WipeSelectedBuffer")
_actions[keymaps.close_buffer] = function("CloseSelectedBuffer")

export def Start(opts: dict<any> = {})
    # FIXME: allows the file path to be shortened to fit in the results window
    # without wrapping. Other file selectors do not do this, maybe remove it.
    _window_width = get(opts, 'width', 0.8)

    var wids = selector.Start(GetBufList(), extend(opts, {
        devicons: true,
        select_cb: actions.OpenFile,
        preview_cb: function('Preview'),
        actions: _actions
    }))
enddef
