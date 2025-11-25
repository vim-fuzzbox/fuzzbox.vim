vim9script

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

def InsideGitRepo(): bool
    return stridx(system('git rev-parse --is-inside-work-tree'), 'true') == 0
enddef

export def Build(): list<any>
    var cmd_template: string
    var sep_pattern: string
    var ignore_case: string
    if executable('rg')
        cmd_template = Build_rg()
        ignore_case = ''
        sep_pattern = '\:\d\+:\d\+:'
    elseif executable('ag')
        cmd_template = Build_ag()
        ignore_case = ''
        sep_pattern = '\:\d\+:\d\+:'
    elseif respect_gitignore && executable('git') && InsideGitRepo()
        cmd_template = Build_git()
        ignore_case = '-i'
        sep_pattern = '\:\d\+:\d\+:'
    elseif executable('grep')
        cmd_template = Build_grep()
        ignore_case = '-i'
        sep_pattern = '\:\d\+:'
    elseif executable('findstr') # for Windows
        cmd_template = findstr_cmd
        ignore_case = '/I'
        sep_pattern = '\:\d\+:'
    else
        echoerr 'Please install ag, rg, grep or findstr to run :FuzzyGrep'
    endif
    return [cmd_template, sep_pattern, ignore_case]
enddef
