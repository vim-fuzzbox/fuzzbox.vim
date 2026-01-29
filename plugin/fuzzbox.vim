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

# Options referenced from multiple selectors or other scripts
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

highlight default link fuzzboxCursor Cursor
highlight default link fuzzboxNormal Normal
highlight default link fuzzboxBorder Normal
highlight default link fuzzboxCounter NonText
highlight default link fuzzboxMatching Special
highlight default link fuzzboxPreviewMatch Search
highlight default link fuzzboxPreviewLine Visual
highlight default link fuzzboxSelectionSign Normal

import autoload '../autoload/fuzzbox/internal/launcher.vim'
import autoload '../autoload/fuzzbox/internal/helpers.vim'

command! -nargs=? FuzzyGrep launcher.Start('grep', { search: <q-args> })
command! -nargs=? FuzzyGrepRoot launcher.Start('grep', { cwd: helpers.GetRootDir(), 'search': <q-args> })
command! -nargs=0 FuzzyFiles launcher.Start('files')
command! -nargs=? FuzzyFilesRoot launcher.Start('files', { cwd: helpers.GetRootDir() })
command! -nargs=0 FuzzyHelp launcher.Start('help')
command! -nargs=0 FuzzyColors launcher.Start('colors')
command! -nargs=? FuzzyInBuffer launcher.Start('inbuffer', { search: <q-args> })
command! -nargs=0 FuzzyCommands launcher.Start('commands')
command! -nargs=0 FuzzyBuffers launcher.Start('buffers')
command! -nargs=0 FuzzyHighlights launcher.Start('highlights')
command! -nargs=0 FuzzyGitFiles launcher.Start('files', { command: 'git ls-files' })
command! -nargs=0 FuzzyCmdHistory launcher.Start('cmdhistory')
command! -nargs=0 FuzzyMru launcher.Start('mru')
command! -nargs=0 FuzzyMruCwd launcher.Start('mru', { cwd: getcwd() })
command! -nargs=0 FuzzyMruRoot launcher.Start('mru', { cwd: helpers.GetRootDir() })
command! -nargs=0 FuzzyQuickfix launcher.Start('quickfix')
command! -nargs=0 FuzzyLoclist launcher.Start('loclist')
command! -nargs=0 FuzzyTags launcher.Start('tags')
command! -nargs=0 FuzzyTagsRoot launcher.Start('tags', { cwd: helpers.GetRootDir() })
command! -nargs=0 FuzzyMarks launcher.Start('marks')
command! -nargs=0 FuzzyJumps launcher.Start('jumps')
command! -nargs=0 FuzzyArglist launcher.Start('arglist')
command! -nargs=0 FuzzyPrevious launcher.Resume()

# Hack to only show a single line warning when startng the selector
# Avoids showing warnings on Vim startup and does not break selector
if len(warnings) > 0
    g:__fuzzbox_warnings_found = 1
    command! -nargs=0 FuzzyShowWarnings for warning in warnings | echo warning | endfor
endif

# backwards compatibility
if exists('g:fuzzbox_enable_mappings') && !exists('g:fuzzbox_mappings')
    g:fuzzbox_mappings = g:fuzzbox_enable_mappings
endif
var enable_mappings = exists('g:fuzzbox_mappings') ? g:fuzzbox_mappings : true

if enable_mappings
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
