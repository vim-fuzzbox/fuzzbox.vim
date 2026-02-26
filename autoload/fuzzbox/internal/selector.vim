vim9script

import autoload './popup.vim'
import autoload './devicons.vim'
import autoload './helpers.vim'
import autoload './actions.vim'

var raw_list: list<string>
var total_count: number
var cwd: string
var menu_wid: number
var prompt_str: string
var default_actions: dict<any>
var async_limit = g:fuzzbox_async_limit
var async_step = exists('g:fuzzbox_async_step')
    && type(g:fuzzbox_async_step) == v:t_number ?
    g:fuzzbox_async_step : 10000
var prompt_prefix = exists('g:fuzzbox_prompt_prefix')
    && type(g:fuzzbox_prompt_prefix) == v:t_string ?
    g:fuzzbox_prompt_prefix : '> '
var menu_wrap = exists('g:fuzzbox_menu_wrap') ? g:fuzzbox_menu_wrap : false
var preview_wrap = exists('g:fuzzbox_preview_wrap') ? g:fuzzbox_preview_wrap : true

# track whether options are endbled for the current selector
var has_devicons: bool
var has_counter: bool

# render the menu window with list of items and fuzzy matched positions
export def UpdateMenu(str_list: list<string>, hl_list: list<list<any>>)
    if has_devicons
        # avoid modifying source/raw list when adding devicons
        var new_list = copy(str_list)
        var hl_offset = devicons.GetDeviconOffset()
        var new_hl_list = reduce(hl_list, (a, v) => {
            v[1] += hl_offset
            return add(a, v)
        }, [])
        devicons.AddDevicons(new_list)
        popup.MenuSetText(new_list)
        popup.MenuSetHl(new_hl_list)
        devicons.AddColor(menu_wid)
    else
        popup.MenuSetText(str_list)
        popup.MenuSetHl(hl_list)
    endif
enddef

# Take results list from matchfuzzypos() and convert to sortable list
# e.g. [[v1, v2], [p1, p2], [s1, s2]] -> [[v1, p1, s1], [v2, p2, s2]]
# Necessary to combine and sort results when processing asynchronously
def ProcessResults(results: list<list<any>>): list<list<any>>
    var processed_results: list<list<any>>
    var strs = results[0]
    var poss = results[1]
    var scores = results[2]

    for idx in range(len(strs))
        add(processed_results, [strs[idx], poss[idx], scores[idx]])
    endfor

    return processed_results
enddef

# Take positions from matchfuzzypos() and transform for use with matchaddpos()
# Merges continuous numbers to ranges, change list indexes to column positions
# e.g. [1,2,3,4,5,7,9] -> [[2,5], [8], [10]]
def TransformPositions(li: list<number>): list<any>
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

# Take processed results and convert to list of strings and highlight positions
# with line numbers that can be used to update the menu content and highlighting
# e.g. [['bar.vim', [4, 6], 540], ['foo.vim', [4, 6], 540]]
#  ->  [['bar.vim', 'foo.vim'], [[1, 5], [1, 7], [2, 5], [2, 7]]]
export def TransformResults(processed_results: list<list<any>>): list<list<any>>
    var str_list = []
    var hl_list = []
    var idx = 1
    for item in processed_results
        add(str_list, item[0])

        var positions = TransformPositions(item[1])

        # convert char index to byte index for highlighting
        for idx2 in range(len(positions))
            var temp = []
            var r = positions[idx2]
            add(temp, byteidx(item[0], r[0] - 1) + 1)
            if len(positions[idx2]) == 2
                add(temp, byteidx(item[0], r[0] - 1 + r[1]) + 1 - temp[0])
            endif
            positions[idx2] = temp
        endfor

        hl_list += reduce(positions, (acc, val) => {
            add(acc, [idx] + val)
            return acc
        }, [])
        idx += 1
    endfor

    return [str_list, hl_list]
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
export def FuzzySearch(li: list<string>, pattern: string): list<any>
    if empty(pattern)
        return [li, [], total_count]
    endif
    var results: list<any> = matchfuzzypos(li, pattern)

    var match_count = len(results[0])

    var processed_results = ProcessResults(results)

    var [str_list, hl_list] = TransformResults(processed_results)
    return [str_list, hl_list, match_count]
enddef

var async_list: list<string>
var async_pattern: string
var async_results: list<any>
var async_count: number
var async_tid: number
var AsyncCb: func

def InputAsyncCb(str_list: list<string>, hl_list: list<list<any>>, match_count: number)
    UpdateMenu(str_list, hl_list)
    if has_counter
        popup.SetCounter(match_count, total_count)
    endif
enddef

def InputAsync(wid: number, result: string)
    async_tid = FuzzySearchAsync(raw_list, result, function('InputAsyncCb'))
enddef

def AsyncWorker(tid: number)
    var li = async_list[: async_step]
    var results: list<any> = matchfuzzypos(li, async_pattern)

    var strs = results[0]
    var poss = results[1]
    var scores = results[2]

    async_count += len(strs)

    async_results += ProcessResults(results)
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
        async_results = async_results->slice(0, async_limit)
    endif

    var [str_list, hl_list] = TransformResults(async_results)
    AsyncCb(str_list, hl_list, async_count)

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
#  - Cb: callback function
# return:
#  timer id
export def FuzzySearchAsync(li: list<string>, pattern: string, Cb: func): number
    # only one outstanding call at a time
    timer_stop(async_tid)
    if empty(pattern)
        Cb(raw_list->slice(0, async_limit), [], total_count)
        return -1
    endif
    async_list = li
    async_pattern = pattern
    async_results = []
    async_count = 0
    AsyncCb = Cb
    async_tid = timer_start(50, function('AsyncWorker'), {repeat: -1})
    AsyncWorker(async_tid)
    return async_tid
enddef

export def UpdateList(li: list<string>)
    raw_list = li
enddef

def Input(wid: number, pattern: string)
    prompt_str = pattern # required for RefreshMenu()
    var [str_list, hl_list, match_count] = FuzzySearch(raw_list, pattern)

    UpdateMenu(str_list, hl_list)
    if has_counter
        popup.SetCounter(match_count, total_count)
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

def GetDefaultOpts(): dict<any>
    var global_defaults: dict<any>
    global_defaults.dropdown = exists('g:fuzzbox_dropdown') ? g:fuzzbox_dropdown : false
    global_defaults.counter = exists('g:fuzzbox_counter') ? g:fuzzbox_counter : true
    global_defaults.preview = exists('g:fuzzbox_preview') ? g:fuzzbox_preview : true
    global_defaults.compact = exists('g:fuzzbox_compact') ? g:fuzzbox_compact : false
    global_defaults.scrollbar = exists('g:fuzzbox_scrollbar') ? g:fuzzbox_scrollbar : false

    var window_defaults = exists('g:fuzzbox_window_defaults') ? g:fuzzbox_window_defaults : {}
    return extendnew(global_defaults, window_defaults)
enddef

# This function spawn a popup picker for user to select an item from a list.
# params:
#   - list: list of string to be selected, can be empty
#   - opts: dict of options, mostly for popup.PopupSelection()
# return:
#   A dictionary of window ids:
#    {
#       menu: menu_wid,
#       prompt: prompt_wid,
#       preview: preview_wid,
#    }
export def Start(li_raw: list<string>, opts: dict<any> = {}): dict<any>
    if popup.active
        return { menu: -1, prompt: -1, preview: -1 }
    endif
    cwd = len(get(opts, 'cwd', '')) > 0 ? opts.cwd : getcwd()
    prompt_str = ''

    var defaults = GetDefaultOpts()

    has_devicons = has_key(opts, 'devicons') && opts.devicons && devicons.Enabled()
    has_counter = has_key(opts, 'counter') ? opts.counter : defaults.counter

    opts.preview_cb = has_key(opts, 'preview_cb') ? opts.preview_cb : actions.PreviewFile
    opts.select_cb = has_key(opts, 'select_cb') ? opts.select_cb : actions.OpenFile
    opts.input_cb = has_key(opts, 'input_cb') ? opts.input_cb : (
        has_key(opts, 'async') && opts.async ? function('InputAsync') : function('Input')
    )
    opts.dropdown = has_key(opts, 'dropdown') ? opts.dropdown : defaults.dropdown
    opts.preview = has_key(opts, 'preview') ? opts.preview : defaults.preview
    opts.compact = has_key(opts, 'compact') ? opts.compact : defaults.compact
    opts.scrollbar = has_key(opts, 'scrollbar') ? opts.scrollbar : defaults.scrollbar
    opts.prompt_prefix = has_key(opts, 'prompt_prefix') ? opts.prompt_prefix : prompt_prefix
    opts.menu_wrap = has_key(opts, 'menu_wrap') ? opts.menu_wrap : menu_wrap
    opts.preview_wrap = has_key(opts, 'preview_wrap') ? opts.preview_wrap : preview_wrap

    opts.actions = has_key(opts, 'actions') ? extendnew(default_actions, opts.actions) : default_actions

    var wids = popup.PopupSelection(extendnew(defaults, opts))
    menu_wid = wids.menu
    raw_list = li_raw
    total_count = len(raw_list)

    if opts.input_cb == function('InputAsync')
        UpdateMenu(raw_list, [])
    else
        UpdateMenu(raw_list->slice(0, async_limit), [])
    endif

    if has_counter
        popup.SetCounter(total_count, total_count)
    endif

    # User autocmd triggered when closing popups to clean up any running timers
    # Note: calling timer_stop() from a lambda expression does not work here
    autocmd User __FuzzboxCleanup ++once Cleanup()
    return wids
enddef

def Cleanup()
    timer_stop(async_tid)
enddef
