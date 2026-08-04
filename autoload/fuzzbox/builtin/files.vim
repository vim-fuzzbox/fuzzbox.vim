vim9script

import autoload '../internal/selector.vim'
import autoload '../internal/popup.vim'
import autoload '../internal/previewer.vim'
import autoload '../internal/devicons.vim'
import autoload '../internal/utils.vim'
import autoload '../internal/actions.vim'
import autoload './files/cmdbuilder.vim'

var cur_pattern: string
var last_pattern: string
var cwd: string
var cur_result: list<string>
var total_count: number
var cur_count: number
var cur_job: job

var async_limit = g:fuzzbox_async_limit

def AsyncCb(str_list: list<string>, hl_list: list<list<any>>, match_count: number)
    cur_count = match_count
    selector.UpdateResults(str_list, hl_list, cur_count, total_count)
enddef

def Input(wid: number, result: string)
    UpdateMenu()
enddef

def JobStart(path: string, cmd: string)
    if job_status(cur_job) == 'run'
        job_stop(cur_job)
    endif
    cur_result = []
    if path == ''
        return
    endif
    cur_job = job_start(cmd, {
        out_cb: function('JobOutCb'),
        out_mode: 'raw',
        exit_cb: function('JobExitCb'),
        err_cb: function('JobErrCb'),
        cwd: path
    })
enddef

def JobOutCb(channel: channel, msg: string)
    var lists = utils.Split(msg)
    cur_result += lists
    UpdateMenu()
enddef

def JobErrCb(channel: channel, msg: string)
    echoerr msg
enddef

def JobExitCb(job: job, status: number)
    UpdateMenu()
enddef

var async_tid: number
def UpdateMenu()
    if !popup.active
        return
    endif
    cur_pattern = popup.GetPrompt()
    var cur_result_len = len(cur_result)
    if cur_result_len > total_count
        total_count = cur_result_len
    endif
    if job_status(cur_job) == 'run'
        if cur_pattern != ''
            popup.SetCounter(cur_count, total_count)
        else
            popup.SetCounter(cur_result_len, total_count)
        endif
        if cur_pattern == last_pattern
            return
        endif
        last_pattern = cur_pattern
    endif

    if cur_pattern != ''
        async_tid = selector.FuzzySearchAsync(cur_result, cur_pattern, function('AsyncCb'))
    else
        timer_stop(async_tid)
        selector.UpdateResults(cur_result->slice(0, async_limit), [],
            cur_result_len, total_count)
    endif
enddef

def Close(wid: number)
    if job_status(cur_job) == 'run'
        job_stop(cur_job)
    endif
    # release memory
    cur_result = []
enddef

export def Start(opts: dict<any> = {})
    opts.title = has_key(opts, 'title') ? opts.title : 'Find Files'

    total_count = 0
    cur_result = []
    cur_pattern = ''
    last_pattern = '@!#-='
    cwd = len(get(opts, 'cwd', '')) > 0 ? opts.cwd : getcwd()
    var wids = selector.Start([], extend(opts, {
        select_cb: actions.OpenFile,
        preview_cb: actions.PreviewFile,
        input_cb: function('Input'),
        close_cb: function('Close'),
        devicons: true,
        counter: true
    }))
    var cmd: string
    if len(get(opts, 'command', '')) > 0
        cmd = opts.command
    else
        cmd = cmdbuilder.Build()
    endif
    utils.Debug('files command: ' .. cmd)
    JobStart(cwd, cmd)
enddef
