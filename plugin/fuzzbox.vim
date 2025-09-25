if !has('vim9script') ||  v:version < 900
  finish
endif

vim9script noclear

if exists("g:loaded_fuzzbox")
    finish
endif
g:loaded_fuzzbox = 1

if exists("g:loaded_fuzzyy")
    echohl WarningMsg
    echo 'Fuzzbox failed to load, old Fuzzyy plugin loaded, please delete Fuzzyy. See :help fuzzyy.renamed'
    echohl None
    var doc_dir = substitute(expand('<script>:h'), 'plugin$', 'doc', '')
    execute "helptags " .. doc_dir
    finish
endif
g:loaded_fuzzyy = 1

var warnings = []
if &encoding != 'utf-8'
    warnings += ['fuzzbox: Vim encoding is ' .. &encoding .. ', utf-8 is required for popup borders etc.']
endif

var fuzzyy_options = getcompletion('g:fuzzyy_', 'var')
if !empty(fuzzyy_options)
    for option in fuzzyy_options
        var fuzzbox_option = option->substitute('g:fuzzyy_', 'g:fuzzbox_', '')
        execute fuzzbox_option .. ' = ' .. option
        warnings += ['fuzzbox: deprecated option ' .. option .. ' found, and used to set ' .. fuzzbox_option]
    endfor
    if empty(getcompletion('fuzzyy.renamed', 'help'))
        try
            var doc_dir = substitute(expand('<script>:h'), 'plugin$', 'doc', '')
            execute "helptags " .. doc_dir
        catch
        endtry
    endif
    warnings += ['fuzzbox: Fuzzyy has been renamed to Fuzzbox, please update your Vim configuration, see :help fuzzyy.renamed']
endif

# Options
g:fuzzbox_enable_mappings = exists('g:fuzzbox_enable_mappings') ? g:fuzzbox_enable_mappings : 1
g:fuzzbox_respect_gitignore = exists('g:fuzzbox_respect_gitignore') ? g:fuzzbox_respect_gitignore : 1
g:fuzzbox_respect_wildignore = exists('g:fuzzbox_respect_wildignore') ? g:fuzzbox_respect_wildignore : 0
g:fuzzbox_follow_symlinks = exists('g:fuzzbox_follow_symlinks') ? g:fuzzbox_follow_symlinks : 0
g:fuzzbox_include_hidden = exists('g:fuzzbox_include_hidden') ? g:fuzzbox_include_hidden : 1
g:fuzzbox_exclude_file = exists('g:fuzzbox_exclude_file')
    && type(g:fuzzbox_exclude_file) == v:t_list ? g:fuzzbox_exclude_file : ['*.swp', 'tags']
g:fuzzbox_exclude_dir = exists('g:fuzzbox_exclude_dir')
    && type(g:fuzzbox_exclude_dir) == v:t_list ? g:fuzzbox_exclude_dir : ['.git', '.hg', '.svn']
g:fuzzbox_ripgrep_options = exists('g:fuzzbox_ripgrep_options')
    && type(g:fuzzbox_ripgrep_options) == v:t_list ? g:fuzzbox_ripgrep_options : []

if g:fuzzbox_respect_wildignore
    var wildignore_dir = copy(split(&wildignore, ','))->filter('v:val =~ "[\\/]"')
    var wildignore_file = copy(split(&wildignore, ','))->filter('v:val !~ "[\\/]"')
    extend(g:fuzzbox_exclude_file, wildignore_file)
    extend(g:fuzzbox_exclude_dir, wildignore_dir)
endif

# window layout customization for particular selectors
# you can override it by setting g:fuzzbox_window_layout
# e.g. let g:fuzzbox_window_layout = { 'files': { 'preview': 0 } }
var windows: dict<any> = {
    files: {
        prompt_title: 'Find Files'
    },
    grep: {
        prompt_title: 'Live Grep'
    },
    buffers: {
        prompt_title: 'Buffers'
    },
    mru: {
        prompt_title: 'Recent Files'
    },
    tags: {
        prompt_title: 'Tags'
    },
    highlights: {
        prompt_title: 'Highlight Groups',
        preview_ratio: 0.7,
    },
    cmdhistory: {
        prompt_title: 'Command History',
        width: 0.6,
    },
    colors: {
        prompt_title: 'Color Schemes',
        width: 0.25,
        xoffset: 0.6,
    },
    commands: {
        prompt_title: 'Commands',
        width: 0.4,
    },
    help: {
        prompt_title: 'Help',
        preview_ratio: 0.6,
    },
    inbuffer: {
        prompt_title: 'Lines in Buffer',
    },
    quickfix: {
        prompt_title: 'Quickfix',
    },
    marks: {},
}
if exists('g:fuzzbox_window_layout') && type(g:fuzzbox_window_layout) == v:t_dict
    for [key, value] in items(windows)
        if has_key(g:fuzzbox_window_layout, key)
            windows[key] = extend(value, g:fuzzbox_window_layout[key])
        endif
    endfor
endif

highlight default link fuzzboxCursor Cursor
highlight default link fuzzboxNormal Normal
highlight default link fuzzboxBorder Normal
highlight default link fuzzboxCounter NonText
highlight default link fuzzboxMatching Special
highlight default link fuzzboxPreviewMatch Search
highlight default link fuzzboxPreviewLine Visual

import autoload '../autoload/fuzzbox/utils/launcher.vim'
import autoload '../autoload/fuzzbox/utils/helpers.vim'

command! -nargs=? FuzzyGrep launcher.Start('grep', extendnew(windows.grep, { search: <q-args> }))
command! -nargs=? FuzzyGrepRoot launcher.Start('grep', extendnew(windows.grep, { cwd: helpers.GetRootDir(), 'search': <q-args> }))
command! -nargs=0 FuzzyFiles launcher.Start('files', windows.files)
command! -nargs=? FuzzyFilesRoot launcher.Start('files', extendnew(windows.files, { cwd: helpers.GetRootDir() }))
command! -nargs=0 FuzzyHelp launcher.Start('help', windows.help)
command! -nargs=0 FuzzyColors launcher.Start('colors', windows.colors)
command! -nargs=? FuzzyInBuffer launcher.Start('inbuffer', extendnew(windows.inbuffer, { search: <q-args> }))
command! -nargs=0 FuzzyCommands launcher.Start('commands', windows.commands)
command! -nargs=0 FuzzyBuffers launcher.Start('buffers', windows.buffers)
command! -nargs=0 FuzzyHighlights launcher.Start('highlights', windows.highlights)
command! -nargs=0 FuzzyGitFiles launcher.Start('files', extendnew(windows.files, { command: 'git ls-files' }))
command! -nargs=0 FuzzyCmdHistory launcher.Start('cmdhistory', windows.cmdhistory)
command! -nargs=0 FuzzyMru launcher.Start('mru', windows.mru)
command! -nargs=0 FuzzyMruCwd launcher.Start('mru', extendnew(windows.mru, { cwd: getcwd() }))
command! -nargs=0 FuzzyMruRoot launcher.Start('mru', extendnew(windows.mru, { cwd: helpers.GetRootDir() }))
command! -nargs=0 FuzzyQuickfix launcher.Start('quickfix', windows.quickfix)
command! -nargs=0 FuzzyTags launcher.Start('tags', windows.tags)
command! -nargs=0 FuzzyTagsRoot launcher.Start('tags', extendnew(windows.tags, { cwd: helpers.GetRootDir() }))
command! -nargs=0 FuzzyMarks launcher.Start('marks', windows.marks)
command! -nargs=0 FuzzyPrevious launcher.Resume()

# Hack to only show a single line warning when startng the selector
# Avoids showing warnings on Vim startup and does not break selector
if len(warnings) > 0
    g:__fuzzbox_warnings_found = 1
    command! -nargs=0 FuzzyShowWarnings for warning in warnings | echo warning | endfor
endif

if g:fuzzbox_enable_mappings
    var mappings = {
        '<leader>fb': ':FuzzyBuffers<CR>',
        '<leader>fc': ':FuzzyCommands<CR>',
        '<leader>ff': ':FuzzyFiles<CR>',
        '<leader>fg': ':FuzzyGrep<CR>',
        '<leader>fh': ':FuzzyHelp<CR>',
        '<leader>fi': ':FuzzyInBuffer<CR>',
        '<leader>fm': ':FuzzyMru<CR>',
        '<leader>fp': ':FuzzyPrevious<CR>',
        '<leader>fq': ':FuzzyQuickfix<CR>',
        '<leader>fr': ':FuzzyMruCwd<CR>'
    }
    for [lhs, rhs] in items(mappings)
        if empty(maparg(lhs, 'n'))
            exe 'nnoremap <silent> ' .. lhs .. ' ' .. rhs
        endif
    endfor
endif

# Load compatibility hacks on VimEnter, after other plugins are loaded
augroup fuzzboxCompat
  au!
  autocmd VimEnter * runtime! compat/fuzzbox.vim
augroup END
