vim9script

import autoload '../internal/selector.vim'
import autoload '../internal/previewer.vim'
import autoload '../internal/popup.vim'
import autoload '../internal/devicons.vim'
import autoload '../internal/utils.vim'
import autoload '../internal/actions.vim'
import autoload './grep/cmdbuilder.vim'

var cwd: string
var custom_cmd: string
var cur_pattern: string
var cur_result: list<string>
var cur_menu_item: string
var last_pattern: string
var last_result_len: number
var last_result: list<string>
var cur_dict: dict<any>
var cur_job: job
var pid: number

var async_limit = g:fuzzbox_async_limit

def MatchSepPos(str: string): list<any>
    var matchdata: list<any>
    for pattern in ['\:\d\+:\d\+:', '\:\d\+:']
        matchdata = matchstrpos(str, pattern)
        if matchdata[1] != -1
            return matchdata
        endif
    endfor
    return ['', -1, -1]
enddef

def ParseResult(str: string): list<any>
    var seq = MatchSepPos(str)
    if seq[1] == -1
        return [null, -1, -1]
    endif
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
    var seq = MatchSepPos(val)
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
    var str = strpart(val, seq[2])

    # Workaround for ripgrep, must use . for relative path when stdout not a tty
    var relative_path = substitute(path, '\v^\.(\\|\/)', '', '')

    var prefix = relative_path .. seq[0]
    var col_list = [col + len(prefix), len(pattern)]
    var final_str = prefix .. str
    acc.dict[final_str] = [line, col, len(pattern)]
    var obj = {
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
    if job_status(cur_job) == 'run'
        job_stop(cur_job)
    endif
    cur_result = []
    if pattern == ''
        return
    endif
    var cmd: string
    if empty(custom_cmd)
        cmd = cmdbuilder.Build(pattern)
    else
        cmd = substitute(custom_cmd, '\V$*', '"' .. escape(pattern, '"') .. '"', '')
    endif
    utils.Debug('grep command: ' .. cmd)
    cur_job = job_start(cmd, {
        out_cb: function('JobOutCb'),
        out_mode: 'raw',
        exit_cb: function('JobExitCb'),
        err_cb: function('JobErrCb'),
        cwd: cwd
    })
    pid = job_info(cur_job).process
enddef

def JobOutCb(channel: channel, msg: string)
    if job_info(ch_getjob(channel)).process == pid
        var lists = utils.Split(msg)
        cur_result += lists
        UpdateMenu()
    endif
enddef

def JobErrCb(channel: channel, msg: string)
    echoerr msg
enddef

def JobExitCb(job: job, status: number)
    if job == cur_job
        UpdateMenu()
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
    popup.SetLoading()
    JobStart(result)
    UpdateMenu()
enddef

def UpdatePreviewHl(wid: number)
    if !has_key(cur_dict, cur_menu_item)
        return
    endif
    var [path, linenr, colnr] = ParseResult(cur_menu_item)
    clearmatches(wid)
    if !previewer.IsTextFile(wid)
        return
    endif
    if colnr > 0
        var hl_list = [cur_dict[cur_menu_item]]
        matchaddpos('fuzzboxPreviewMatch', hl_list, 9999, -1,  {window: wid})
    else
        matchaddpos('fuzzboxPreviewLine', [linenr], 9999, -1,  {window: wid})
    endif
enddef

def Preview(wid: number, result: string, opts: dict<any>)
    cur_menu_item = result

    actions.PreviewFile(wid, result, opts)

    UpdatePreviewHl(wid)
enddef

def UpdateMenu()
    if !popup.active
        return
    endif
    var cur_result_len = len(cur_result)
    if cur_pattern == ''
        popup.UpdateMenu([], [])
        last_pattern = cur_pattern
        last_result_len = cur_result_len
        popup.SetCounter(null)
        return
    endif

    # limit results to prevent ballooning memory usage
    var max_results = 10000
    if cur_result_len > max_results
        job_stop(cur_job)
        popup.SetCounter('> ' .. max_results)
    elseif job_status(cur_job) != 'run'
        popup.SetCounter(cur_result_len)
    endif

    if last_pattern == cur_pattern
        && cur_result_len == last_result_len
        return
    endif

    var strs: list<string>
    var cols: list<list<number>>
    if cur_result_len == 0
        strs = []
        cols = []
    else
        last_result = cur_result
        [strs, cols, cur_dict] = ResultHandle(cur_result->slice(0, async_limit))
    endif

    popup.UpdateMenu(strs, cols)
    last_pattern = cur_pattern
    last_result_len = cur_result_len
enddef

def Close(wid: number)
    if job_status(cur_job) == 'run'
        job_stop(cur_job)
    endif
    # release memory
    cur_result = []
    last_result = []
enddef

export def Start(opts: dict<any> = {})
    opts.title = has_key(opts, 'title') ? opts.title : 'Live Grep'

    cwd = len(get(opts, 'cwd', '')) > 0 ? opts.cwd : getcwd()

    if len(get(opts, 'command', '')) > 0
        custom_cmd = opts.command
        if stridx(custom_cmd, '$*') == -1
            custom_cmd ..= ' $*'
        endif
    endif

    cur_pattern = ''
    cur_result = []
    cur_menu_item = ''

    last_pattern = ''
    last_result_len = -1
    last_result = []
    cur_dict = {}

    var wids = selector.Start([], extend(opts, {
        select_cb: actions.OpenFile,
        input_cb: function('Input'),
        preview_cb: function('Preview'),
        close_cb: function('Close'),
        devicons: true,
        counter: false
     }))
enddef
