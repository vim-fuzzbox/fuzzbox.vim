vim9script

import autoload '../../internal/utils.vim'

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
var ugrep_options = exists('g:fuzzbox_files_ugrep_options')
    && type(g:fuzzbox_files_ugrep_options) == v:t_list ?
    g:fuzzbox_files_ugrep_options : g:fuzzbox_ugrep_options
var recurse_submodules = exists('g:fuzzbox_grep_recurse_submodules') ?
    g:fuzzbox_grep_recurse_submodules : g:fuzzbox_recurse_submodules

var max_count = 1000

def Build_rg(): string
    var result = 'rg -M200 -S --vimgrep --no-messages --max-count=' .. max_count .. ' -F'
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
        ' ' .. join(ripgrep_options, ' ') .. ' %s -e "%s" .'
enddef

def Build_ugrep(): string
    var result = 'ugrep -Inku --tabs=1 --width=200 -j --no-messages --max-count=' .. max_count .. ' -F'
    if include_hidden
        result ..= ' --hidden'
    endif
    if follow_symlinks
        result ..= ' -R'
    else
        result ..= ' -r'
    endif
    if respect_gitignore
        result ..= ' --ignore-files'
    endif
    var dir_list_parsed = reduce(dir_exclude,
        (acc, dir) => acc .. "--exclude-dir " .. dir .. " ", "")
    var file_list_parsed = reduce(file_exclude,
        (acc, file) => acc .. "--exclude " .. file .. " ", "")
    return result .. ' ' .. dir_list_parsed .. file_list_parsed  ..
        ' ' .. join(ugrep_options, ' ') .. ' %s -e "%s" .'
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
    return result .. ' ' .. dir_list_parsed .. file_list_parsed .. ' %s -- "%s"'
enddef

var bsd_grep: any
def Build_grep(): string
    if empty(bsd_grep)
        bsd_grep = ( has('mac') || has('bsd') ) && system('grep --version | head -1') =~# 'BSD'
    endif
    var result = 'grep -n -r -I -s --max-count=' .. max_count .. ' -F'
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
    return result .. ' ' .. dir_list_parsed .. file_list_parsed .. ' %s -e "%s"'
enddef

var git_version: string
def Build_git(cwd: string): string
    var no_index = !utils.InsideGitRepo(cwd)
    var result = 'git grep -n -I --column -F'
    # Note: recurse submodules incompatible with --no-index in old git versions
    if !respect_gitignore
        result ..= ' --no-index --no-recurse-submodules'
    elseif no_index
        result ..= ' --no-index --no-recurse-submodules --exclude-standard'
    elseif recurse_submodules
        result ..= ' --recurse-submodules'
    else
        result ..= ' --untracked --no-recurse-submodules'
    endif
    if empty(git_version)
        git_version = system('git version')->matchstr('\M\(\d\+\.\)\{2}\d\+')
    endif
    var [major, minor] = split(git_version, '\M.')[0 : 1]
    # -m/--max-count option added in git version 2.38.0
    if str2nr(major) > 2 || ( str2nr(major) == 2 && str2nr(minor) >= 38 )
        result ..= ' --max-count=' .. max_count
    endif
    return result ..  ' %s -e "%s"'
enddef

var findstr_cmd = 'FINDSTR /S /N /O /P /L %s "%s" *'

export def Build(pattern: string, cwd: string): string
    var fmtstr: string
    var ignore_case_opt: string
    if executable('rg')
        fmtstr = Build_rg()
    elseif executable('ugrep')
        fmtstr = Build_ugrep()
    elseif executable('ag')
        fmtstr = Build_ag()
    elseif executable('git')
        fmtstr = Build_git(cwd)
        ignore_case_opt = '-i'
    elseif has('unix')
        fmtstr = Build_grep()
        ignore_case_opt = '-i'
    else
        fmtstr = findstr_cmd
        ignore_case_opt = '/I'
    endif

    # fudge smart-case for grep programs that don't natively support it
    # adds ignore case option to arguments when no upper case chars found
    if !empty(ignore_case_opt) && match(pattern, '\u') == -1
        return printf(fmtstr, ignore_case_opt, escape(pattern, '"'))
    else
        return printf(fmtstr, '', escape(pattern, '"'))
    endif
enddef
