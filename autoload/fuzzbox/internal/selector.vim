vim9script

import autoload './popup.vim'
import autoload './utils.vim'
import autoload './actions.vim'

var raw_list: list<string>
var len_list: number
var cwd: string
var cur_pattern: string
var default_actions: dict<any>
var async_limit = g:fuzzbox_async_limit
var async_step = g:fuzzbox_async_step
var async_wait = g:fuzzbox_async_wait
var max_results = g:fuzzbox_max_results

# track whether counter is endbled for the current selector
var has_counter: bool

export def UpdateResults(str_list: list<string>, hl_list: list<list<any>>,
        match_count: number, total_count: number)
    popup.UpdateMenu(str_list, hl_list)
    if has_counter
        if cur_pattern != '' && match_count > max_results
            popup.SetCounter('> ' .. max_results, total_count)
        else
            popup.SetCounter(match_count, total_count)
        endif
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

# Take positions from matchfuzzypos() and add them to hl_list for use with
# matchaddpos(). Merges continuous positions to ranges and changes char indexes
# to byte column positions, e.g. for line 1: [1,2,3,4,5,7,9]
#  ->  [[1, 2, 5], [1, 8], [1, 10]]
def AddHlPositions(str: string, poss: list<number>, lnum: number,
        hl_list: list<list<any>>)
    var n = len(poss)
    var i = 0
    while i < n
        var start = poss[i]
        var j = i + 1
        while j < n && poss[j] == poss[j - 1] + 1
            j += 1
        endwhile
        var run = j - i
        # add 1 because vim column starts from 1 and string index starts from 0
        var col = byteidx(str, start)
        add(hl_list, run > 1
            ? [lnum, col + 1, byteidx(str, start + run) - col]
            : [lnum, col + 1])
        i = j
    endwhile
enddef

# Take processed results and convert to list of strings and highlight positions
# with line numbers that can be used to update the menu content and highlighting
# e.g. [['bar.vim', [4, 6], 540], ['foo.vim', [4, 6], 540]]
#  ->  [['bar.vim', 'foo.vim'], [[1, 5], [1, 7], [2, 5], [2, 7]]]
def TransformResults(processed_results: list<list<any>>): list<list<any>>
    var str_list = []
    var hl_list = []
    var lnum = 1
    for item in processed_results
        add(str_list, item[0])
        AddHlPositions(item[0], item[1], lnum, hl_list)
        lnum += 1
    endfor
    return [str_list, hl_list]
enddef

# Returns the results, matchaddpos() positions, and the match count
export def FuzzySearch(li: list<string>, pattern: string): list<any>
    cur_pattern = pattern
    if empty(pattern)
        return [li, [], len_list]
    endif
    var results: list<any> = matchfuzzypos(li, pattern, {limit: max_results + 1})

    var match_count = len(results[0])

    var processed_results = ProcessResults(results)

    var [str_list, hl_list] = TransformResults(processed_results)
    return [str_list, hl_list, match_count]
enddef

def Input(wid: number, pattern: string)
    var [str_list, hl_list, match_count] = FuzzySearch(raw_list, pattern)
    UpdateResults(str_list, hl_list, match_count, len_list)
enddef

# Currently only used by FuzzyBuffers, to refresh after deleting a buffer
export def UpdateList(li: list<string>)
    raw_list = li
    len_list = len(li)
    popup.UpdateMenu(li, [])
    popup.SetPrompt(popup.GetPrompt())
enddef

var async_list: list<string>
var async_offset: number
var async_results: list<list<any>>
var async_transformed: list<list<any>>
var async_count: number
var async_tid: number
var AsyncCb: func

def InputAsyncCb(str_list: list<string>, hl_list: list<list<any>>, match_count: number)
    UpdateResults(str_list, hl_list, match_count, len_list)
enddef

def InputAsync(wid: number, result: string)
    async_tid = FuzzySearchAsync(raw_list, result, function('InputAsyncCb'))
enddef

# Sort by score descending, then alphabetically
def CompareResults(a: list<any>, b: list<any>): number
    if a[2] < b[2]
        return 1
    elseif a[2] > b[2]
        return -1
    endif
    return a[0] > b[0] ? 1 : -1
enddef

# Merge results from matchfuzzypos() into the sorted results list, keeping only
# the top limit items. matchfuzzypos() results are already sorted by score, so
# only the top limit of them (plus any tied with the last one) need sorting,
# then the two sorted lists are merged in linear time.
# Returns the same list unchanged when no new item makes the top limit.
def MergeResults(results: list<list<any>>, new_results: list<any>,
        limit: number): list<list<any>>
    var strs = new_results[0]
    var poss = new_results[1]
    var scores = new_results[2]
    var len_old = len(results)
    if empty(strs) || (len_old >= limit && scores[0] < results[-1][2])
        return results
    endif

    var len_new = len(strs)
    if len_new > limit
        var cutoff = scores[limit - 1]
        len_new = limit
        while len_new < len(strs) && scores[len_new] == cutoff
            len_new += 1
        endwhile
    endif
    var batch: list<list<any>>
    for idx in range(len_new)
        add(batch, [strs[idx], poss[idx], scores[idx]])
    endfor
    sort(batch, CompareResults)

    var merged: list<list<any>>
    var i = 0
    var j = 0
    while len(merged) < limit && (i < len_old || j < len_new)
        if j >= len_new || (i < len_old && CompareResults(results[i], batch[j]) < 0)
            add(merged, results[i])
            i += 1
        else
            add(merged, batch[j])
            j += 1
        endif
    endwhile
    return j == 0 ? results : merged
enddef

def AsyncWorker(tid: number)
    # track position with an offset, re-slicing the remaining list for each
    # batch copies it and makes the whole search O(n^2)
    var li = async_list[async_offset : async_offset + async_step - 1]
    async_offset += len(li)
    var results: list<any> = matchfuzzypos(li, cur_pattern)

    async_count += len(results[0])

    var merged = MergeResults(async_results, results, async_limit)
    if merged isnot async_results || empty(async_transformed)
        async_results = merged
        async_transformed = TransformResults(async_results)
    endif
    var [str_list, hl_list] = async_transformed
    AsyncCb(str_list, hl_list, async_count)

    if async_count >= max_results
        if has_counter
            popup.SetCounter('> ' .. max_results, len_list)
        endif
        timer_stop(tid)
        return
    endif

    if async_offset >= len(async_list)
        timer_stop(tid)
        return
    endif
enddef

# Using timer to mimic async search. This is a workaround for the lack of async
# support in vim. It uses a timer to do the search in the background, and calls
# the callback function when part of the results are ready. The callback is
# called with the results, matchaddpos() positions, and the current match count.
#
# This function only allows one outstanding call at a time. If a new call is
# made before the previous one finishes, the previous one will be cancelled.
# The timer id is returned so calling code can preemptivley cancel the timer.
export def FuzzySearchAsync(li: list<string>, pattern: string, Cb: func): number
    # The list may grow while it is searched, e.g. FuzzyFiles adds job output to
    # it in place. When only the list has grown, continue the current search
    # into the new items, as restarting would discard the results so far, and
    # the results shown would drop back to those from the first batch
    if li is async_list && pattern == cur_pattern && !empty(pattern)
        AsyncCb = Cb
        if empty(timer_info(async_tid))
            if async_count < max_results
                async_tid = timer_start(async_wait, function('AsyncWorker'), {repeat: -1})
                AsyncWorker(async_tid)
            else
                var [str_list, hl_list] = async_transformed
                Cb(str_list, hl_list, async_count)
            endif
        endif
        return async_tid
    endif

    # only one outstanding call at a time
    timer_stop(async_tid)
    cur_pattern = pattern
    if empty(pattern)
        Cb(raw_list->slice(0, async_limit), [], len_list)
        return -1
    endif
    async_list = li
    async_offset = 0
    async_results = []
    async_transformed = []
    async_count = 0
    AsyncCb = Cb
    async_tid = timer_start(async_wait, function('AsyncWorker'), {repeat: -1})
    AsyncWorker(async_tid)
    return async_tid
enddef

default_actions = {
    "\<c-v>": actions.OpenFileVSplit,
    "\<c-s>": actions.OpenFileSplit,
    "\<c-x>": actions.OpenFileSplit,
    "\<c-t>": actions.OpenFileTab,
    "\<c-q>": actions.SendToQuickfix,
}

def GetDefaultOpts(): dict<any>
    var globals: dict<any>
    globals.dropdown = exists('g:fuzzbox_dropdown') ? g:fuzzbox_dropdown : false
    globals.counter = exists('g:fuzzbox_counter') ? g:fuzzbox_counter : true
    globals.preview = exists('g:fuzzbox_preview') ? g:fuzzbox_preview : true
    globals.compact = exists('g:fuzzbox_compact') ? g:fuzzbox_compact : false
    globals.scrollbar = exists('g:fuzzbox_scrollbar') ? g:fuzzbox_scrollbar : false
    globals.menu_wrap = exists('g:fuzzbox_menu_wrap') ? g:fuzzbox_menu_wrap : false
    globals.preview_wrap = exists('g:fuzzbox_preview_wrap') ? g:fuzzbox_preview_wrap : true

    var defaults = exists('g:fuzzbox_window_defaults') ? g:fuzzbox_window_defaults : {}
    return extendnew(globals, defaults)
enddef

# This function spawn a popup picker for user to select an item from a list.
# params:
#   - list: list of string to be selected, can be empty
#   - opts: dict of options, mostly for popup.Start()
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
    raw_list = li_raw
    len_list = len(raw_list)

    if has_key(opts, 'title') && !has_key(opts, 'prompt_title')
        opts.prompt_title = opts.title
    endif

    var defaults = GetDefaultOpts()

    has_counter = has_key(opts, 'counter') ? opts.counter : defaults.counter

    opts.async = has_key(opts, 'async') ? opts.async : ( len_list >= async_step)
    opts.preview_cb = has_key(opts, 'preview_cb') ? opts.preview_cb : actions.PreviewFile
    opts.select_cb = has_key(opts, 'select_cb') ? opts.select_cb : actions.OpenFile
    opts.input_cb = has_key(opts, 'input_cb') ? opts.input_cb : (
        opts.async ? function('InputAsync') : function('Input')
    )
    opts.change_cb = has_key(opts, 'change_cb') ? opts.change_cb : null

    opts.devicons = has_key(opts, 'devicons') ? opts.devicons : false
    opts.dropdown = has_key(opts, 'dropdown') ? opts.dropdown : defaults.dropdown
    opts.compact = has_key(opts, 'compact') ? opts.compact : defaults.compact
    opts.scrollbar = has_key(opts, 'scrollbar') ? opts.scrollbar : defaults.scrollbar
    opts.menu_wrap = has_key(opts, 'menu_wrap') ? opts.menu_wrap : defaults.menu_wrap
    opts.preview_wrap = has_key(opts, 'preview_wrap') ? opts.preview_wrap : defaults.preview_wrap

    if has_key(opts, 'default_actions') && !opts.default_actions
        opts.actions = has_key(opts, 'actions') ? opts.actions : {}
    else
        opts.actions = has_key(opts, 'actions') ? extendnew(default_actions, opts.actions) : default_actions
    endif

    opts.cleanup = () => timer_stop(async_tid)

    var wids = popup.Start(extendnew(defaults, opts))

    if opts.input_cb == function('InputAsync')
        UpdateResults(raw_list->slice(0, async_limit), [], len_list, len_list)
    else
        UpdateResults(raw_list, [], len_list, len_list)
    endif

    return wids
enddef
