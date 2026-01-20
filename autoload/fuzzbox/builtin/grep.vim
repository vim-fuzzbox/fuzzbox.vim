vim9script

import autoload '../internal/selector.vim'
import autoload '../internal/previewer.vim'
import autoload '../internal/popup.vim'
import autoload '../internal/devicons.vim'
import autoload '../internal/helpers.vim'
import autoload '../internal/actions.vim'
import autoload './grep/cmdbuilder.vim'

var enable_devicons = devicons.Enabled()

var loading = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

var cwd: string
var cwdlen: number
var cur_pattern = ''
var cur_result = []
var menu_wid = -1
var cur_menu_item = ''
var job_running = 0
var update_tid = 0
var last_pattern = ''
var last_result_len = -1
var last_result = []
var cur_dict = {}
var jid: job
var pid: number
var preview_wid = -1

def ParseResult(str: string): list<any>
    var seq = matchstrpos(str, sep_pattern)
    if seq[1] == -1
        return [null, -1, -1]
    endif
    # var path = str[: seq[1] - 1]
    var path = strpart(str, 0, seq[1])
    var linecol = split(seq[0], ':')
    var line = str2nr(linecol[0])
    var col: number
    if len(linecol) == 2
        col = str2nr(linecol[1])
    else
        col = 0
    endif
    return [path, line, col]
enddef

def Reducer(pattern: string, acc: dict<any>, val: string): dict<any>
    var seq = matchstrpos(val, sep_pattern)
    if seq[1] == -1
        return acc
    endif

    var linecol = split(seq[0], ':')
    var line: number = str2nr(linecol[0])
    var col: number
    if len(linecol) == 2
        col = str2nr(linecol[1])
    endif
    var path = strpart(val, 0, seq[1])
    # note: git-grep command returns relative paths, but we want to generate
    # a path relative to the cwd provided (not the current Vim working dir)
    # note2: also currently required for Git-Bash and friends, as this fixes
    # windows file separator in paths returned from external commands like rg
    var absolute_path = fnamemodify(path, ':p')
    var str = strpart(val, seq[2])
    var centerd_str = str
    var relative_path = strpart(absolute_path, cwdlen + 1)

    var prefix = relative_path .. seq[0]
    var col_list = [col + len(prefix), len(pattern)]
    var final_str = prefix .. centerd_str
    acc.dict[final_str] = [line, col, len(pattern)]
    var obj = {
        prefix: prefix,
        centerd_str: centerd_str,
        col_list: col_list,
        final_str: final_str,
        line: line,
    }
    add(acc.objs, obj)
    add(acc.strs, final_str)
    add(acc.cols, col_list)
    return acc
enddef

def JobStart(pattern: string)
    if type(jid) == v:t_job && job_status(jid) == 'run'
        job_stop(jid)
    endif
    cur_result = []
    if pattern == ''
        return
    endif
    job_running = 1
    var cmd_str: string
    # fudge smart-case for grep programs that don't natively support it
    # adds ignore case option to arguments when no upper case chars found
    if !empty(ignore_case) && match(pattern, '\u') == -1
        cmd_str = printf(cmd_template, ignore_case, escape(pattern, '"'), escape(cwd, '"'))
    else
        cmd_str = printf(cmd_template, '', escape(pattern, '"'), escape(cwd, '"'))
    endif
    jid = job_start(cmd_str, {
        out_cb: function('JobOutCb'),
        out_mode: 'raw',
        exit_cb: function('JobExitCb'),
        err_cb: function('JobErrCb'),
    })
    pid = job_info(jid).process
enddef

def JobOutCb(channel: channel, msg: string)
    if job_info(ch_getjob(channel)).process == pid
        var lists = helpers.Split(msg)
        cur_result += lists
    endif
enddef

def JobErrCb(channel: channel, msg: string)
    echoerr msg
enddef

def JobExitCb(id: job, status: number)
    if id == jid
        job_running = 0
    endif
enddef

def ResultHandle(lists: list<any>): list<any>
    if cur_pattern == ''
        return [[], [], {}]
    endif
    var result = reduce(lists, function('Reducer', [cur_pattern]),
         { strs: [], cols: [], objs: [], dict: {} })
    var strs = []
    var cols = []
    var idx = 1
    for r in result.objs
        add(strs, r.final_str)
        add(cols, [idx] + r.col_list)
        idx += 1
    endfor
    return [strs, cols, result.dict]
enddef

# async version
def Input(wid: number, result: string)
    cur_pattern = result
    JobStart(result)
enddef

def UpdatePreviewHl()
    if !has_key(cur_dict, cur_menu_item) || preview_wid < 0
        return
    endif
    var [path, linenr, colnr] = ParseResult(cur_menu_item)
    clearmatches(preview_wid)
    if !previewer.IsTextFile(preview_wid)
        return
    endif
    if colnr > 0
        var hl_list = [cur_dict[cur_menu_item]]
        matchaddpos('fuzzboxPreviewMatch', hl_list, 9999, -1,  {window: preview_wid})
    else
        matchaddpos('fuzzboxPreviewLine', [linenr], 9999, -1,  {window: preview_wid})
    endif
enddef

def Preview(wid: number, result: string, opts: dict<any>)
    if wid == -1
        return
    endif
    cur_menu_item = result

    actions.PreviewFile(wid, result, opts)

    UpdatePreviewHl()
enddef

def UpdateMenu(...li: list<any>)
    var cur_result_len = len(cur_result)
    if cur_pattern == ''
        selector.UpdateMenu([], [])
        last_pattern = cur_pattern
        last_result_len = cur_result_len
        popup.SetCounter(null)
        return
    endif

    # limit results to prevent ballooning memory usage
    var max_results = 10000
    if cur_result_len > max_results
        if type(jid) == v:t_job && job_status(jid) == 'run'
            job_stop(jid)
        endif
        popup.SetCounter('> ' .. max_results)
    elseif job_running
        var time = float2nr(str2float(reltime()->reltimestr()[4 : ]) * 1000)
        var speed = 100
        var loadidx = (time % speed) / len(loading)
        popup.SetCounter(loading[loadidx])
    else
        popup.SetCounter(len(cur_result))
    endif

    if last_pattern == cur_pattern
        && cur_result_len == last_result_len
        return
    endif

    var strs: list<string>
    var cols: list<list<number>>
    if cur_result_len == 0
        # we should use last result to do fuzzy search
        # [strs, cols, cur_dict] = ResultHandle(last_result[: 2000])
        strs = []
        cols = []
    else
        last_result = cur_result
        [strs, cols, cur_dict] = ResultHandle(cur_result[: selector.async_limit])
    endif

    selector.UpdateMenu(strs, cols)
    UpdatePreviewHl()
    last_pattern = cur_pattern
    last_result_len = cur_result_len
enddef

def Close(wid: number)
    timer_stop(update_tid)
    if type(jid) == v:t_job && job_status(jid) == 'run'
        job_stop(jid)
    endif
    # release memory
    # cur_result = []
    # last_result = []
enddef

def Profiling()
    profile start ~/.vim/vim.log
    profile func Start
    profile func UpdateMenu
    profile func Preview
    profile func UpdatePreviewHl
    profile func JobHandler
    profile func ResultHandle
    profile func Reducer
enddef

# Script scoped vars reset for each invocation of Start(). Allows directory
# change between invocations and git-grep only to be used when in git repo.
var cmd_template: string
var sep_pattern: string
# Set to ignore case option for grep programs that do not support smart case
# When set, smart case will be emulated by adding ignore case option when
# search pattern does not include any characters Vim considers upper case
var ignore_case: string

export def Start(opts: dict<any> = {})
    opts.title = has_key(opts, 'title') ? opts.title : 'Live Grep'

    [cmd_template, sep_pattern, ignore_case] = cmdbuilder.Build()

    cwd = len(get(opts, 'cwd', '')) > 0 ? opts.cwd : getcwd()
    cwdlen = len(cwd)
    cur_pattern = ''
    cur_result = []
    cur_menu_item = ''
    job_running = 0

    update_tid = 0
    last_pattern = ''
    last_result_len = -1
    last_result = []
    cur_dict = {}

    var wids = selector.Start([], extend(opts, {
        select_cb: actions.OpenFile,
        input_cb: function('Input'),
        preview_cb: function('Preview'),
        close_cb: function('Close'),
        devicons: enable_devicons,
        counter: false
     }))
    menu_wid = wids.menu
    if menu_wid == -1
        return
    endif
    preview_wid = wids.preview
    update_tid = timer_start(100, function('UpdateMenu'), {repeat: -1})
    if len(get(opts, 'search', '')) > 0
        popup.SetPrompt(opts.search)
    endif
    # Profiling()
enddef
