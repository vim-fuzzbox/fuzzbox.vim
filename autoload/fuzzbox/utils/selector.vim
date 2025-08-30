vim9script

import autoload './popup.vim'
import autoload './devicons.vim'
import autoload './helpers.vim'
import autoload './actions.vim'

var raw_list: list<string>
var len_list: number
var cwd: string
var menu_wid: number
var prompt_str: string
var menu_hl_list: list<any>
var default_actions: dict<any>
var async_step = exists('g:fuzzbox_async_step')
    && type(g:fuzzbox_async_step) == v:t_number ?
    g:fuzzbox_async_step : 10000
var prompt_prefix = exists('g:fuzzbox_prompt_prefix')
    && type(g:fuzzbox_prompt_prefix) == v:t_string ?
    g:fuzzbox_prompt_prefix : '> '

var wins: dict<any>

var enable_devicons = devicons.Enabled()
var enable_dropdown = exists('g:fuzzbox_dropdown') ? g:fuzzbox_dropdown : false
var enable_counter = exists('g:fuzzbox_counter') ? g:fuzzbox_counter : true
var enable_preview = exists('g:fuzzbox_preview') ? g:fuzzbox_preview : true

# track whether options are endbled for the current selector
var has_devicons: bool
var has_counter: bool

# Experimental: export count of results/matches for the current search
# Can be used to to call popup.SetCounter
export var len_results: number

# render the menu window with list of items and fuzzy matched positions
export def UpdateMenu(str_list: list<string>, hl_list: list<list<any>>)
    var new_list = copy(str_list)
    if has_devicons
        devicons.AddDevicons(new_list)
        popup.MenuSetText(new_list)
        popup.MenuSetHl('select', hl_list)
        devicons.AddColor(menu_wid)
    else
        popup.MenuSetText(new_list)
        popup.MenuSetHl('select', hl_list)
    endif
enddef

# get the line under the cursor in the menu window
export def GetCursorItem(): string
    var bufnr = winbufnr(wins.menu)
    var cursorlinepos = line('.', wins.menu)
    var bufline = getbufline(bufnr, cursorlinepos, cursorlinepos)[0]
    if has_devicons
        bufline = devicons.RemoveDevicon(bufline)
    endif
    return bufline
enddef

# Search pattern @pattern in a list of strings @li
# if pattern is empty, return [li, []]
# params:
#  - li: list of string to be searched
#  - pattern: string to be searched
#  - args: dict of options
#      - limit: max number of results
# return:
# - a list [str_list, hl_list]
#   - str_list: list of search results
#   - hl_list: list of highlight positions
#       - [[line1, col1], [line1, col2], [line2, col1], ...]
export def FuzzySearch(li: list<string>, pattern: string, ...args: list<any>): list<any>
    if pattern == ''
        len_results = len(raw_list)
        return [copy(li), []]
    endif
    var opts = {}
    if len(args) > 0 && args[0] > 0
        opts['limit'] = args[0]
    endif
    var results: list<any> = matchfuzzypos(li, pattern, opts)
    var strs = results[0]
    var poss = results[1]
    var scores = results[2]

    len_results = len(strs)

    var str_list = []
    var hl_list = []
    for idx in range(0, len(strs) - 1)
        add(str_list, strs[idx])
        var poss_result = MergeContinusNumber(poss[idx])

        # convert char index to byte index for highlighting
        for idx2 in range(len(poss_result))
            var temp = []
            var r = poss_result[idx2]
            add(temp, byteidx(strs[idx], r[0] - 1) + 1)
            if len(poss_result[idx2]) == 2
                add(temp, byteidx(strs[idx], r[0] - 1 + r[1]) + 1 - temp[0])
            endif
            poss_result[idx2] = temp
        endfor

        hl_list += reduce(poss_result, (acc, val) => add(acc, [idx + 1] + val), [])
    endfor
    return [str_list, hl_list]
enddef

var async_list: list<string>
var async_limit: number
var async_pattern: string
var async_results: list<any>
var async_tid: number
var AsyncCb: func

def InputAsyncCb(result: list<any>)
    var strs = []
    var hl_list = []
    var hl_offset = has_devicons ? devicons.GetDeviconOffset() : 0
    var idx = 1
    for item in result
        add(strs, item[0])
        hl_list += reduce(item[1], (acc, val) => {
            var pos = copy(val)
            pos[0] += hl_offset
            add(acc, [idx] + pos)
            return acc
        }, [])
        idx += 1
    endfor
    UpdateMenu(strs, hl_list)
    if has_counter
        popup.SetCounter(len_results, len_list)
    endif
enddef

def InputAsync(wid: number, result: string)
    if result != ''
        async_tid = FuzzySearchAsync(raw_list, result, 200, function('InputAsyncCb'))
    else
        timer_stop(async_tid)
        var strs = raw_list[: 100]
        UpdateMenu(strs, [])
        if has_counter
            popup.SetCounter(len_list, len_list)
        endif
    endif
enddef

# merge continus numbers and convert them from string index to vim column
# [1,3] means [start index, length
# eg. [1,2,3,4,5,7,9] -> [[1,5], [7], [9]]
# eg. [2,3,4,5,6,8,10] -> [[2,5], [8], [10]]
def MergeContinusNumber(li: list<number>): list<any>
    var last_pos = li[0]
    var start_pos = li[0]
    var pos_len = 1
    var poss_result = []
    for idx in range(1, len(li) - 1)
        var pos = li[idx]
        if pos == last_pos + 1
            pos_len += 1
        else
            # add 1 because vim column starts from 1 and string index starts from 0
            if pos_len > 1
                add(poss_result, [start_pos + 1, pos_len])
            else
                add(poss_result, [start_pos + 1])
            endif
            start_pos = pos
            last_pos = pos
            pos_len = 1
        endif
        last_pos = pos
    endfor
    if pos_len > 1
        add(poss_result, [start_pos + 1, pos_len])
    else
        add(poss_result, [start_pos + 1])
    endif
    return poss_result
enddef

def Worker(tid: number)
    var li = async_list[: async_step]
    var results: list<any> = matchfuzzypos(li, async_pattern)
    var processed_results = []

    var strs = results[0]
    var poss = results[1]
    var scores = results[2]

    len_results += len(strs)

    for idx in range(len(strs))
        # merge continus number
        var poss_result = MergeContinusNumber(poss[idx])

        # convert char index to byte index for highlighting
        for idx2 in range(len(poss_result))
            var temp = []
            var r = poss_result[idx2]
            add(temp, byteidx(strs[idx], r[0] - 1) + 1)
            if len(poss_result[idx2]) == 2
                add(temp, byteidx(strs[idx], r[0] - 1 + r[1]) + 1 - temp[0])
            endif
            poss_result[idx2] = temp
        endfor

        add(processed_results, [strs[idx], poss_result, scores[idx]])
    endfor
    async_results += processed_results
    sort(async_results, (a, b) => {
        if a[2] < b[2]
            return 1
        elseif a[2] > b[2]
            return -1
        else
            return a[0] > b[0] ? 1 : -1
        endif
    })

    if len(async_results) >= async_limit
        async_results = async_results[: async_limit]
    endif
    AsyncCb(async_results)

    async_list = async_list[async_step + 1 :]
    if len(async_list) == 0
        timer_stop(tid)
        return
    endif
enddef

# Using timer to mimic async search. This is a workaround for the lack of async
# support in vim. It uses timer to do the search in the background, and calls
# the callback function when part of the results are ready.
# This function only allows one outstanding call at a time. If a new call is
# made before the previous one finishes, the previous one will be canceled.
# params:
#  - li: list of string to be searched
#  - pattern: string to be searched
#  - limit: max number of results
#  - Cb: callback function
# return:
#  timer id
export def FuzzySearchAsync(li: list<string>, pattern: string, limit: number, Cb: func): number
    # only one outstanding call at a time
    timer_stop(async_tid)
    if pattern == ''
        return -1
    endif
    async_list = li
    async_limit = limit
    async_pattern = pattern
    async_results = []
    len_results = 0
    AsyncCb = Cb
    async_tid = timer_start(50, function('Worker'), {repeat: -1})
    Worker(async_tid)
    return async_tid
enddef

export def UpdateList(li: list<string>)
    raw_list = li
enddef

def Input(wid: number, result: string)
    prompt_str = result
    menu_hl_list = []
    var ret: list<string>
    [ret, menu_hl_list] = FuzzySearch(raw_list, prompt_str)

    if has_devicons
        devicons.AddDevicons(ret)
        var hl_offset = devicons.GetDeviconOffset()
         menu_hl_list = reduce(menu_hl_list, (a, v) => {
            v[1] += hl_offset
            return add(a, v)
         }, [])
    endif

    popup.MenuSetText(ret)
    popup.MenuSetHl('select', menu_hl_list)
    if has_devicons
        devicons.AddColor(menu_wid)
    endif
    if has_counter
        popup.SetCounter(len_results, len_list)
    endif
enddef

export def RefreshMenu()
    Input(menu_wid, prompt_str)
enddef

default_actions = {
    "\<c-v>": actions.OpenFileVSplit,
    "\<c-s>": actions.OpenFileSplit,
    "\<c-t>": actions.OpenFileTab,
    "\<c-q>": actions.SendToQuickfix,
    "\<c-\>": actions.MenuToggleWrap,
}

# This function spawn a popup picker for user to select an item from a list.
# params:
#   - list: list of string to be selected. can be empty at init state
#   - opts: dict of options
#       - select_cb: callback to be called when user select an item.
#           select_cb(menu_wid, result). result is a list like ['selected item']
#       - preview_cb: callback to be called when user move cursor on an item.
#           preview_cb(menu_wid, result). result is a list like ['selected item', opts]
#       - input_cb: callback to be called when user input something. If input_cb
#           is not set, then the input will be used as the pattern to filter the
#           list. If input_cb is set, then the input will be passed to given callback.
#           input_cb(menu_wid, result). the second argument result is a list ['input string', opts]
#       - preview: wheather to show preview window, default 1
#       - width: width of the popup window, default 80. If preview is enabled,
#           then width is the width of the total layout.
#       - xoffset: x offset of the popup window. The popup window is centered
#           by default.
#       - scrollbar: wheather to show scrollbar in the menu window.
#       - preview_ratio: ratio of the preview window. default 0.5
# return:
#   A dictionary:
#    {
#        menu: menu_wid,
#        prompt: prompt_wid,
#        preview: preview_wid,
#    }
export def Start(li_raw: list<string>, opts: dict<any> = {}): dict<any>
    if popup.active
        return { menu: -1, prompt: -1, preview: -1 }
    endif
    cwd = len(get(opts, 'cwd', '')) > 0 ? opts.cwd : getcwd()
    prompt_str = ''

    has_devicons = enable_devicons && has_key(opts, 'devicons') && opts.devicons
    has_counter = has_key(opts, 'counter') ? opts.counter : enable_counter

    opts.preview_cb = has_key(opts, 'preview_cb') ? opts.preview_cb : null
    opts.select_cb = has_key(opts, 'select_cb') ? opts.select_cb : null
    opts.input_cb = has_key(opts, 'input_cb') ? opts.input_cb : (
        has_key(opts, 'async') && opts.async ? function('InputAsync') : function('Input')
    )
    opts.dropdown = has_key(opts, 'dropdown') ? opts.dropdown : enable_dropdown
    opts.preview = has_key(opts, 'preview') ? opts.preview : enable_preview
    opts.prompt_prefix = has_key(opts, 'prompt_prefix') ? opts.prompt_prefix : prompt_prefix

    opts.actions = has_key(opts, 'actions') ? extend(default_actions, opts.actions) : default_actions

    wins = popup.PopupSelection(opts)
    menu_wid = wins.menu
    raw_list = li_raw
    len_list = len(raw_list)
    var li = copy(li_raw)
    if opts.input_cb == function('InputAsync')
        li = li[: 100]
    endif
    if has_devicons
         devicons.AddDevicons(li)
    endif
    popup.MenuSetText(li)
    if has_devicons
        devicons.AddColor(menu_wid)
    endif

    if has_counter
        popup.SetCounter(len_list, len_list)
    endif

    autocmd User PopupClosed ++once () => { timer_stop(async_tid) }
    return wins
enddef
