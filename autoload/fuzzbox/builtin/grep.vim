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
var cur_menu_item: string
var cur_dict: dict<any>
var cur_job: job

# Only the first async_limit results are shown in the menu, so only those are
# parsed and kept, any further output from the job is just counted
var cur_strs: list<string>
var cur_cols: list<list<number>>
var cur_count: number
# Incomplete last line from the previous chunk of raw job output
var part_line: string
var menu_dirty: bool

var async_limit = g:fuzzbox_async_limit
var max_results = g:fuzzbox_max_results

def ParseLine(val: string)
    # Workaround for ripgrep, must use . for relative path when stdout not a tty
    var final_str = substitute(val, '\v^\.(\\|\/)', '', '')

    # Find the first :line or :line:col followed by a colon or end of string
    # Note: this is the regex used by ParseResult() in actions.vim, which is
    # used to parse the result when opening the file, use the same regex here
    var [sep, start, end] = matchstrpos(final_str, '\v:\zs\d+%(:\d+)?\ze%(:|$)')
    if start == -1
        return
    endif
    var linecol = split(sep .. ':0', ':')
    var line = str2nr(linecol[0])
    var col = str2nr(linecol[1])
    cur_dict[final_str] = [line, col, len(cur_pattern)]
    add(cur_strs, final_str)
    # Offset column by the length of the file:line:col: prefix for highlighting
    # No highlight without a column number, e.g. from grep -n or findstr
    if col > 0
        add(cur_cols, [len(cur_strs), col + end + 1, len(cur_pattern)])
    endif
enddef

def AddLines(lines: list<string>)
    for line in lines
        if len(cur_strs) >= async_limit
            break
        endif
        ParseLine(line)
    endfor
    menu_dirty = true
enddef

def ResetResults()
    cur_strs = []
    cur_cols = []
    cur_dict = {}
    cur_count = 0
    part_line = ''
    menu_dirty = true
enddef

def JobStart(pattern: string)
    if job_status(cur_job) == 'run'
        job_stop(cur_job)
    endif
    ResetResults()
    if pattern == ''
        return
    endif
    var cmd: string
    if empty(custom_cmd)
        cmd = cmdbuilder.Build(pattern, cwd)
    else
        cmd = substitute(custom_cmd, '\V$*', '"' .. escape(pattern, '"') .. '"', '')
    endif
    utils.Debug('grep command: ' .. cmd)
    cur_job = job_start(cmd, {
        out_cb: function('JobOutCb'),
        out_mode: 'raw',
        exit_cb: function('JobExitCb'),
        close_cb: function('JobCloseCb'),
        err_cb: function('JobErrCb'),
        cwd: cwd
    })
enddef

def JobOutCb(channel: channel, msg: string)
    # ignore output from previous jobs that have been stopped
    if ch_getjob(channel) != cur_job
        return
    endif
    # Raw output can be split anywhere, so only count complete lines, and only
    # split and parse the output while there is still space in the menu
    cur_count += count(msg, "\n")
    if len(cur_strs) < async_limit
        var lines = utils.Split(part_line .. msg)
        part_line = msg[-1 : ] == "\n" || empty(lines) ? '' : remove(lines, -1)
        AddLines(lines)
    else
        # menu is full, only track whether output ends with an incomplete line
        part_line = msg[-1 : ] == "\n" ? '' : msg[-1 : ]
    endif
    UpdateMenu()
enddef

def JobErrCb(channel: channel, msg: string)
    echoerr msg
enddef

def JobExitCb(job: job, status: number)
    if job == cur_job
        UpdateMenu()
    endif
enddef

# Called after all output has been passed to JobOutCb, unlike JobExitCb
def JobCloseCb(channel: channel)
    # output may not end with a newline
    if ch_getjob(channel) == cur_job && !empty(part_line)
        cur_count += 1
        AddLines([part_line])
        part_line = ''
        UpdateMenu()
    endif
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
    var [linenr, colnr, _] = cur_dict[cur_menu_item]
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
    if cur_pattern == ''
        popup.UpdateMenu([], [])
        popup.SetCounter(null)
        return
    endif

    # limit results to prevent the job running for a long time
    if cur_count > max_results
        job_stop(cur_job)
        popup.SetCounter('> ' .. max_results)
    elseif job_status(cur_job) != 'run'
        popup.SetCounter(cur_count)
    endif

    # menu doesn't change once full, avoid updating it for every chunk
    if !menu_dirty
        return
    endif
    popup.UpdateMenu(cur_strs, cur_cols)
    menu_dirty = false
enddef

def Close(wid: number)
    if job_status(cur_job) == 'run'
        job_stop(cur_job)
    endif
    # release memory
    ResetResults()
enddef

export def Start(opts: dict<any> = {})
    opts.title = has_key(opts, 'title') ? opts.title : 'Live Grep'

    cwd = len(get(opts, 'cwd', '')) > 0 ? opts.cwd : getcwd()

    custom_cmd = ''
    if len(get(opts, 'command', '')) > 0
        custom_cmd = opts.command
        if stridx(custom_cmd, '$*') == -1
            custom_cmd ..= ' $*'
        endif
    endif

    cur_pattern = ''
    cur_menu_item = ''
    ResetResults()

    var wids = selector.Start([], extend(opts, {
        select_cb: actions.OpenFile,
        input_cb: function('Input'),
        preview_cb: function('Preview'),
        close_cb: function('Close'),
        devicons: true,
        counter: false
     }))
enddef
