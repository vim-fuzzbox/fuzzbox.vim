vim9script

import autoload '../internal/selector.vim'
import autoload '../internal/previewer.vim'
import autoload '../internal/popup.vim'
import autoload '../internal/devicons.vim'
import autoload '../internal/helpers.vim'
import autoload '../internal/actions.vim'

var enable_devicons = devicons.Enabled()

# Options
var respect_gitignore = exists('g:fuzzbox_grep_respect_gitignore') ?
    g:fuzzbox_grep_respect_gitignore : g:fuzzbox_respect_gitignore
var file_exclude = exists('g:fuzzbox_grep_exclude_file')
    && type(g:fuzzbox_grep_exclude_file) == v:t_list ?
    g:fuzzbox_grep_exclude_file : g:fuzzbox_exclude_file
var dir_exclude = exists('g:fuzzbox_grep_exclude_dir')
    && type(g:fuzzbox_grep_exclude_dir) == v:t_list ?
    g:fuzzbox_grep_exclude_dir : g:fuzzbox_exclude_dir
var include_hidden = exists('g:fuzzbox_grep_include_hidden') ?
    g:fuzzbox_grep_include_hidden : g:fuzzbox_include_hidden
var follow_symlinks = exists('g:fuzzbox_grep_follow_symlinks') ?
    g:fuzzbox_grep_follow_symlinks : g:fuzzbox_follow_symlinks
var ripgrep_options = exists('g:fuzzbox_grep_ripgrep_options')
    && type(g:fuzzbox_grep_ripgrep_options) == v:t_list ?
    g:fuzzbox_grep_ripgrep_options : g:fuzzbox_ripgrep_options

var loading = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

var max_count = 1000

def Build_rg(): string
    var result = 'rg -M200 -S --vimgrep --max-count=' .. max_count .. ' -F'
    if include_hidden
        result ..= ' --hidden'
    endif
    if follow_symlinks
        result ..= ' --follow'
    endif
    if respect_gitignore
        result ..= ' --no-require-git'
    else
        result ..= ' --no-ignore'
    endif
    var dir_list_parsed = reduce(dir_exclude,
        (acc, dir) => acc .. "-g !" .. dir .. " ", "")
    var file_list_parsed = reduce(file_exclude,
        (acc, file) => acc .. "-g !" .. file .. " ", "")
    return result .. ' ' .. dir_list_parsed .. file_list_parsed ..
        ' ' .. join(ripgrep_options, ' ') .. ' %s -e "%s" "%s"'
enddef

def Build_ag(): string
    var result = 'ag -W200 -S --vimgrep --silent --max-count=' .. max_count .. ' -F'
    if include_hidden
        result ..= ' --hidden'
    endif
    if follow_symlinks
        result ..= ' --follow'
    endif
    if ! respect_gitignore
        result ..= ' --all-text'
    endif
    var dir_list_parsed = reduce(dir_exclude,
        (acc, dir) => acc .. "--ignore " .. dir .. " ", "")
    var file_list_parsed = reduce(file_exclude,
        (acc, file) => acc .. "--ignore " .. file .. " ", "")
    return result .. ' ' .. dir_list_parsed .. file_list_parsed .. ' %s -- "%s" "%s"'
enddef

var bsd_grep: any
def Build_grep(): string
    if empty(bsd_grep)
        bsd_grep = ( has('mac') || has('bsd') ) && system('grep --version | head -1') =~# 'BSD'
    endif
    var result = 'grep -n -r -I --max-count=' .. max_count .. ' -F'
    if follow_symlinks
        result = substitute(result, ' -r ', ' -R ', '')
        if bsd_grep
            # Assumes extended BSD grep (MacOS/FreeBSD)
            result ..= ' -S'
        endif
    endif
    var ParseDir = (dir): string => {
        # GNU grep expects glob without trailing '*' and leading '*/'
        # Thanks to @girishji and scope.vim for this little hack :-)
        return bsd_grep ? dir : dir->substitute('^\**/\{0,1}\(.\{-}\)/\{0,1}\**$', '\1', '')
    }
    var dir_list_parsed = reduce(dir_exclude,
        (acc, dir) => acc .. "--exclude-dir " .. ParseDir(dir) .. " ", "")
    var file_list_parsed = reduce(file_exclude,
        (acc, file) => acc .. "--exclude " .. file .. " ", "")
    return result .. ' ' .. dir_list_parsed .. file_list_parsed .. ' %s -e "%s" "%s"'
enddef

def Build_git(): string
    var result = 'git grep -n -I --column --untracked --exclude-standard -F'
    var version = system('git version')->matchstr('\M\(\d\+\.\)\{2}\d\+')
    var [major, minor] = split(version, '\M.')[0 : 1]
    # -m/--max-count option added in git version 2.38.0
    if str2nr(major) > 2 || ( str2nr(major) == 2 && str2nr(minor) >= 38 )
        result ..= ' --max-count=' .. max_count
    endif
    return result ..  ' %s -e "%s" "%s"'
enddef

var findstr_cmd = 'FINDSTR /S /N /O /P /L %s "%s" "%s/*"'

# Script scoped vars reset for each invocation of Start(). Allows directory
# change between invocations and git-grep only to be used when in git repo.
var cmd: string
var sep_pattern: string
# Set to ignore case option for grep programs that do not support smart case
# When set, smart case will be emulated by adding ignore case option when
# search pattern does not include any characters Vim considers upper case
var ignore_case: string

def InsideGitRepo(): bool
    return stridx(system('git rev-parse --is-inside-work-tree'), 'true') == 0
enddef

def Build()
    if executable('rg')
        cmd = Build_rg()
        ignore_case = ''
        sep_pattern = '\:\d\+:\d\+:'
    elseif executable('ag')
        cmd = Build_ag()
        ignore_case = ''
        sep_pattern = '\:\d\+:\d\+:'
    elseif respect_gitignore && executable('git') && InsideGitRepo()
        cmd = Build_git()
        ignore_case = '-i'
        sep_pattern = '\:\d\+:\d\+:'
    elseif executable('grep')
        cmd = Build_grep()
        ignore_case = '-i'
        sep_pattern = '\:\d\+:'
    elseif executable('findstr') # for Windows
        cmd = findstr_cmd
        ignore_case = '/I'
        sep_pattern = '\:\d\+:'
    else
        echoerr 'Please install ag, rg, grep or findstr to run :FuzzyGrep'
    endif
enddef

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

# return:
#   [path, linenr]
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
    if type(jid) == v:t_job
        try | job_stop(jid) | catch | endtry
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
        cmd_str = printf(cmd, ignore_case, escape(pattern, '"'), escape(cwd, '"'))
    else
        cmd_str = printf(cmd, '', escape(pattern, '"'), escape(cwd, '"'))
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
    if colnr > 0
        var hl_list = [cur_dict[cur_menu_item]]
        matchaddpos('fuzzboxPreviewMatch', hl_list, 9999, -1,  {window: preview_wid})
    else
        matchaddpos('fuzzboxPreviewLine', [linenr], 9999, -1,  {window: preview_wid})
    endif
enddef

def Preview(wid: number, result: string)
    if wid == -1
        return
    endif
    var [relative_path, linenr, colnr] = ParseResult(result)
    cur_menu_item = result

    if relative_path == null
        previewer.PreviewText(preview_wid, '')
        return
    endif

    var path = cwd .. '/' .. relative_path
    previewer.PreviewFile(preview_wid, path)
    win_execute(preview_wid, 'norm! ' .. linenr .. 'G')
    win_execute(preview_wid, 'norm! zz')
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

    if job_running
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

export def Start(opts: dict<any> = {})
    Build()
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
