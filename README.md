# fuzzbox.vim

**Fuzzyy has been renamed to Fuzzbox, new name, same great taste!**

A modern fuzzy finder with minimal dependencies. Written in vim9script using
Vim's native fuzzing matching, background job, and popup window features, it's
fast and works out of the box on Mac, Linux, and Windows.

## Screenshot

![screenshot](https://raw.githubusercontent.com/vim-fuzzbox/showcase/refs/heads/main/screenshot.png)
[](https://raw.githubusercontent.com/vim-fuzzbox/showcase/refs/heads/main/screenshot.png)
Visit the [showcase](https://github.com/vim-fuzzbox/showcase) for other examples

## Requirements

- Vim >= 9.0 (plugin is written in vim9scipt, Vim 9+ required, Neovim not
  supported)

Fuzzbox uses programs pre-installed on almost all Mac, Linux, and Windows
systems for finding files and searching in files by default (e.g. `grep`,
`findstr`), but uses faster alternatives if they are available.

### Suggested dependencies

- [ripgrep](https://github.com/BurntSushi/ripgrep) - used for FuzzyGrep and
  FuzzyFiles if installed, faster than the defaults and respects gitignore

### Optional dependencies

- [ag](https://github.com/ggreer/the_silver_searcher) - used for FuzzyGrep if
  ripgrep not installed
- [fd](https://github.com/sharkdp/fd) - used for FuzzyFiles if ripgrep not
  installed
- [git](https://git-scm.com/) - used for FuzzyGrep and FuzzyFiles when inside git
  repo and no alternative dependency installed
- [ctags](https://ctags.io) - used to generate tags for FuzzyTags (Universal
  Ctags implementation is required)
  
### Compatible plugins
- [vim-devicons](https://github.com/ryanoasis/vim-devicons) - used to show
  [devicons](https://devicon.dev/) when listing files if installed
- [vim-nerdfont](https://github.com/lambdalisue/vim-nerdfont) - alternative
  plugin to show devicons, used if installed and vim-devicons not installed
- [vim-glyph-palette](https://github.com/lambdalisue/vim-glyph-palette) - used
  to colorize devicons if installed, instead of Fuzzbox's own color mappings
- [vim-nerdtree-syntax-highlight](https://github.com/tiagofumo/vim-nerdtree-syntax-highlight) - 
  used to colorize devicons if installed, and [vim-nerdtree](https://github.com/preservim/nerdtree)
  installed

## Install

Any plugin manager will work, or you can use Vim's built-in package support:

For vim-plug
```vim
Plug 'vim-fuzzbox/fuzzbox.vim'
```

As Vim package
```
git clone https://github.com/vim-fuzzbox/fuzzbox.vim ~/.vim/pack/plugins/start/fuzzbox
```

## Commands

| Command               | Description
| ---                   | ---
| FuzzyFiles            | search files in current working directory (CWD)
| FuzzyFilesRoot        | search files in the project/vcs root directory
| FuzzyGrep [str]       | search for string in CWD, use [str] if provided
| FuzzyGrepRoot [str]   | search for string in the project/vcs root directory
| FuzzyBuffers          | search opened buffers
| FuzzyMru              | search most recent used files
| FuzzyMruCwd           | search most recent used files in CWD
| FuzzyMruRoot          | search most recent used files in project/vcs root
| FuzzyInBuffer [str]   | search for string in buffer, use [str] if provided
| FuzzyHelp             | search subjects/tags in help documents
| FuzzyCommands         | search commands
| FuzzyColors           | search installed color schemes
| FuzzyCmdHistory       | search command history
| FuzzyHighlights       | search highlight groups
| FuzzyQuickfix         | search the quickfix list, see `:h quickfix`
| FuzzyArglist          | search the argument list, see `:h arglist`
| FuzzyJumps            | search jumps, see `:h jumplist`
| FuzzyMarks            | search marks, see `:h mark-motions`
| FuzzyTags             | search tags in tagfiles(), see `:h tags`
| FuzzyTagsRoot         | search tags in the project/vcs root directory
| FuzzyGitFiles         | search files in output from `git ls-files`
| FuzzyPrevious         | reloads the previous selector and search string

- For FuzzyGrep and FuzzyInBuffer, you can define a keymap like this to search
  the word under cursor.
  ```vim
  nnoremap <leader>fw :FuzzyGrep <C-R><C-W><CR>
  ```
- FuzzyGrep requires one of `rg`, `ag`, `grep` or `findstr` commands. If neither
  `rg` or `ag` are installed it will also use `git-grep` when in a git repo.
- FuzzyFiles requires one of `rg`, `fd`, `find` or `powershell` commands. If
  neither `rg` or `fd` are installed it will also use `git-ls-files` when in a
  git repo.
- FuzzyTags requires `ctags` (Universal Ctags) to generate a tags file.

## Mappings

```vim
nnoremap <silent> <leader>fb :FuzzyBuffers<CR>
nnoremap <silent> <leader>fc :FuzzyCommands<CR>
nnoremap <silent> <leader>ff :FuzzyFiles<CR>
nnoremap <silent> <leader>fg :FuzzyGrep<CR>
nnoremap <silent> <leader>fh :FuzzyHelp<CR>
nnoremap <silent> <leader>fi :FuzzyInBuffer<CR>
nnoremap <silent> <leader>fm :FuzzyMru<CR>
nnoremap <silent> <leader>fp :FuzzyPrevious<CR>
nnoremap <silent> <leader>fq :FuzzyQuickfix<CR>
nnoremap <silent> <leader>fr :FuzzyMruCwd<CR>
```

You can set `g:fuzzbox_mappings = 0` to disable these default mappings.

Fuzzbox will not overwrite mappings from your vimrc when adding default mappings.

## Navigation

- \<CTRL-P> or \<Up> moves up by one line in the menu window
- \<CTRL-N> or \<Down> moves down by one line in the menu window
- \<PageUp> scrolls up half a page in the menu window
- \<PageDown> scrolls down half a page in the menu window
- \<S-Up> scrolls up three lines in the menu window
- \<S-Down> scrolls down three lines in the menu window
- \<CTRL-U> scrolls up half a page in the preview window
- \<CTRL-D> scrolls down half a page in the preview window
- \<CTRL-B> or \<Home> moves the cursor to the start of the prompt
- \<CTRL-E> or \<End> moves the cursor to the end of the prompt
- \<CTRL-Left> moves the cursor one word left in the prompt
- \<CTRL-Right> moves the cursor one word right in the prompt
- \<CTRL-W> deletes the word before the cursor in the prompt
- \<CTRL-\\> toggles text wrap in the menu window (off by default)
- \<CTRL-C> or \<ESC> exits Fuzzbox, closing all the windows

You can use `g:fuzzbox_keymaps` to change most of these defaults.

Navigation with the mouse is also supported. A single mouse click in the menu
window moves the cursor line, double click selects a line. The mouse wheel can
be used to scroll in both the preview and menu windows.

**Command specific keymaps**

- FuzzyHighlights
  - \<CTRL-K> toggle white preview background color

- FuzzyMru
  - \<CTRL-K> toggle between all MRU files and CWD only

- FuzzyBuffers, FuzzyFiles, FuzzyGrep, FuzzyInBuffer, FuzzyMru, FuzzyQuickfix,
  FuzzyMarks, FuzzyTags
  - \<CTRL-S> open selected file in horizontal split
  - \<CTRL-V> open selected file in vertical split
  - \<CTRL-T> open selected file in new tab page

- FuzzyBuffers, FuzzyFiles, FuzzyGrep, FuzzyInBuffer, FuzzyMru, FuzzyQuickfix
  - \<CTRL-Q> send results to quickfix list

Send results to quickfix list only includes results currently in the menu buffer,
which effectively limits the results to a few hundred at most (this is probably
what you want, sending thousands of results to the quickfix list is slow).

## Options

### g:fuzzbox_mappings
Enable default set of leader mappings (see above for details). Default 1
```vim
let g:fuzzbox_mappings = 1
```

### g:fuzzbox_devicons
Show devicons when listing files (e.g. FuzzyFiles, FuzzyGrep). Default 1
```vim
let g:fuzzbox_devicons = 1
```
This option requires
[vim-devicons](https://github.com/ryanoasis/vim-devicons),
[vim-nerdfont](https://github.com/lambdalisue/vim-nerdfont), or use of
`g:fuzzbox_devicons_glyph_func`

### g:fuzzbox_dropdown
Enable dropdown theme (prompt at top rather than bottom). Default 0
```vim
let g:fuzzbox_dropdown = 0
```

### g:fuzzbox_preview
Enable preview window in supported selectors (e.g. FuzzyFiles). Default 1
```vim
let g:fuzzbox_preview = 1
```

### g:fuzzbox_compact
Enable compact layout, reduces default window dimensions. Default 0
```vim
let g:fuzzbox_compact = 0
```

### g:fuzzbox_counter
Show count of matches. Default 1, set to 0 if you don't want a counter to be
shown for most selectors.
```vim
let g:fuzzbox_counter = 1
```
This option is ignored by some selectors/commands, e.g. FuzzyFiles, FuzzyGrep

### g:fuzzbox_scrollbar
Show a scrollbar in the menu window when the results do not fit. Default 0
```vim
let g:fuzzbox_scrollbar = 0
```
This option does not affect whether the menu window is scrollable, it always
is, just whether a scrollbar is shown.

### g:fuzzbox_prompt_prefix
Set the prefix for the input in the prompt window. Default '> ', must be a
string, but an empty string is valid.
```vim
let g:fuzzbox_prompt_prefix = '> '
```

### g:fuzzbox_menu_wrap
Enable text wrap in the menu window. Default 0
```vim
let g:fuzzbox_menu_wrap = 0
```
You can also use `CTRL-\` to toggle text wrap in the menu while Fuzzbox is open.

### g:fuzzbox_preview_wrap
Enable text wrap in the preview window. Default 1
```vim
let g:fuzzbox_preview_wrap = 1
```

### g:fuzzbox_borderchars
Set the borderchars of popup windows. Must be a list of 8 characters.
```vim
let g:fuzzbox_borderchars = ['─', '│', '─', '│', '╭', '╮', '╯', '╰']
```

### g:fuzzbox_reuse_windows
Fuzzbox avoids opening files in windows containing special buffers, like buffers
created by file explorer plugins or help and quickfix buffers. Use this to add
exceptions, the match is on either buftype or filetype. Default `['netrw']`
(Netrw is Vim's built-in file explorer plugin)
```vim
let g:fuzzbox_reuse_windows = ['netrw']
```
Example usage
```vim
let g:fuzzbox_reuse_windows = ['netrw', 'bufexplorer', 'mru', 'terminal']
```

### g:fuzzbox_respect_gitignore
Make FuzzyFiles & FuzzyGrep respect `.gitignore`. Default 1. Only work when
1. inside a git repository and git is installed
2. or either rg or fd is installed for FuzzyFiles
3. or either rg or ag is installed for FuzzyGrep
```vim
let g:fuzzbox_respect_gitignore = 1
```
This option can also be set specifically for FuzzyFiles and/or FuzzyGrep using
`g:fuzzbox_files_respect_gitignore` and `g:fuzzbox_grep_respect_gitignore`

### g:fuzzbox_respect_wildignore
Make FuzzyFiles & FuzzyGrep respect Vim's |wildignore| option. Default 0
```vim
let g:fuzzbox_respect_wildignore = 0
```
Fuzzbox parses `&wildignore` when the plugin is loaded, and appends patterns to
`g:fuzzbox_exclude_dir` and `g:fuzzbox_exclude_file`. Patterns with a `/` are
assumed to be directory patterns, patterns without are assumed to be a file
patterns. This is not exactly the same as Vim's parsing of `&wildignore`. See
`:h autocmd-patterns`

### g:fuzzbox_include_hidden
Make FuzzyFiles & FuzzyGrep include hidden files. Default 1. Only applied when
1. rg, fd or PowerShell Get-ChildItem used with FuzzyFiles
2. rg or ag used with FuzzyGrep
```vim
let g:fuzzbox_include_hidden = 1
```
This option can also be set specifically for FuzzyFiles and/or FuzzyGrep using
`g:fuzzbox_files_include_hidden` and `g:fuzzbox_grep_include_hidden`

### g:fuzzbox_follow_symlinks
Make FuzzyFiles & FuzzyGrep follow symbolic links. Not applied when using
git-ls-files, git-grep or findstr. Default 0
```vim
let g:fuzzbox_follow_symlinks = 0
```
This option can also be set specifically for FuzzyFiles and/or FuzzyGrep using
`g:fuzzbox_files_follow_symlinks` and `g:fuzzbox_grep_follow_symlinks`

### g:fuzzbox_root_patterns
Patterns to find a project root in supported commands, e.g. FuzzyFilesRoot.
These commands find a "root" directory to use as the working directory by
walking up the directory tree looking for any match of these glob patterns.
Default is intentionally conservative, using common VCS root markers only.
```vim
let g:fuzzbox_root_patterns = ['.git', '.hg', '.svn']
```
Example usage
```vim
let g:fuzzbox_root_patterns = ['.git', 'package.json', 'pyproject.toml']
```

### g:fuzzbox_exclude_file
Make FuzzyFiles, FuzzyGrep, and FuzzyMru always exclude files matching these
glob patterns. Applies whether `.gitignore` is respected or not. Default
`['*.swp', 'tags']`
```vim
let g:fuzzbox_exclude_file = ['*.swp', 'tags']
```
This option can also be set specifically for FuzzyFiles, FuzzyGrep, and FuzzyMru
using `g:fuzzbox_files_exclude_file` and `g:fuzzbox_grep_exclude_file` etc.

### g:fuzzbox_exclude_dir
Make FuzzyFiles, FuzzyGrep, and FuzzyMru always exclude these directories.
Applies whether `.gitignore` is respected or not. Default
`['.git', '.hg', '.svn']`
```vim
let g:fuzzbox_exclude_dir = ['.git', '.hg', '.svn']
```
This option can also be set specifically for FuzzyFiles, FuzzyGrep, and FuzzyMru
using `g:fuzzbox_files_exclude_dir` and `g:fuzzbox_grep_exclude_dir` etc.

### g:fuzzbox_ripgrep_options
Add custom ripgrep options for FuzzyFiles & FuzzyGrep. Appended to the generated
options. Default `[]`
```vim
let g:fuzzbox_ripgrep_options = []
```
Example usage
```vim
let g:fuzzbox_ripgrep_options = [
  \ "--no-config",
  \ "--max-filesize=1M",
  \ "--no-ignore-parent",
  \ "--ignore-file " . expand('~/.ignore')
  \ ]
```
This option can also be set specifically for FuzzyFiles and/or FuzzyGrep using
`g:fuzzbox_files_ripgrep_options` and `g:fuzzbox_grep_ripgrep_options`

### g:fuzzbox_devicons_color_table
Add custom mappings for colorizing devicon glyphs. A dictionary of filename
patterns and colors. Colors must be either color names in Vim's `v:colornames`
dict or hex colors in `#rrggbb` format. Default {}
```vim
let g:fuzzbox_devicons_color_table = {}
```
Example usage
```vim
let g:fuzzbox_devicons_color_table = { '*.vala': 'mediumpurple', '*.jl': '#9558B2' }
```

### g:fuzzbox_devicons_glyph_func
Specify a custom function for obtaining devicon glyphs from file names or paths.
By default Fuzzbox integrates with vim-devicons to obtain glyphs and measure byte
widths. You can use this option to obtain devicon glyphs from another nerdfont
compatible plugin, or your own custom function. Default ''
```vim
let g:fuzzbox_devicons_glyph_func = ''
```
Example usage
```vim
let g:fuzzbox_devicons_glyph_func = 'nerdfont#find'
```
The function should take a single string argument and return a single glyph.

### g:fuzzbox_devicons_color_func
Specify a custom function for colorizing devicon glyphs. By default Fuzzbox does
this with an internal function using a small set of common file name patterns
and colors, but you may want more extensive support for file name patterns not
recognised by Fuzzbox and to apply the same colors to Fuzzbox as other plugins.
Default ''
```vim
let g: fuzzbox_devicons_color_func = ''
```
Example usage
```vim
let g: fuzzbox_devicons_color_func = 'glyph_palette#apply'
```
The function should take no arguments and use matchadd() to add highlighting.

### g:fuzzbox_keymaps
Change navigation keymaps. The following are the defaults
```vim
let g:fuzzbox_keymaps = {
  \ 'menu_up': ["\<C-p>", "\<Up>"],
  \ 'menu_down': ["\<C-n>", "\<Down>"],
  \ 'menu_select': ["\<CR>"],
  \ 'menu_page_up': [],
  \ 'menu_page_down': [],
  \ 'menu_scroll_up': ["\<PageUp>"],
  \ 'menu_scroll_down': ["\<PageDown>"],
  \ 'menu_shift_up': ["\<S-Up>"],
  \ 'menu_shift_down': ["\<S-Down>"],
  \ 'preview_page_up': [],
  \ 'preview_page_down': [],
  \ 'preview_scroll_up': ["\<C-u>"],
  \ 'preview_scroll_down': ["\<C-d>"],
  \ 'cursor_end': ["\<C-e>", "\<End>"],
  \ 'cursor_begining': ["\<C-b>", "\<Home>"],
  \ 'cursor_word_left': ["\<C-Left>"],
  \ 'cursor_word_right': ["\<C-Right>"],
  \ 'backspace': ["\<C-h>", "\<BS>"],
  \ 'delete': ["\<Del>"],
  \ 'delete_all': [],
  \ 'delete_word': ["\<C-w>"],
  \ 'delete_prefix': [],
  \ 'exit': ["\<Esc>", "\<c-c>", "\<c-[>"],
  \ }
```

### g:fuzzbox_buffers_exclude
FuzzyBuffers will exclude the buffers in this list. Buffers not included in
Vim's buffer list are excluded by default, so this is only necessary for buffers
included in Vim's buffer list, but you want hidden by FuzzyBuffers (possibly
from a badly behaved plugin). The match is on buffer name or type. Default `[]`
```vim
let g:fuzzbox_buffers_exclude = []
```
Example usage:
```vim
let g:fuzzbox_buffers_exclude = ['terminal']
```

### g:fuzzbox_window_options
Window configuration. The general defaults for window configuration options are:
```vim
{
'preview': 1,         " Enable the preview window, set to 0 to disable
'preview_ratio': 0.5, " 0.5 means preview window will take 50% of the layout
'width': 0.8,         " 0.8 (80%) when preview is enabled, 0.5 (50%) otherwise
'height': 0.8,        " 0.8 (80%) when preview is enabled, 0.5 (50%) otherwise
'compact': 0,         " Enable compact layout, reduces default window dimensions
'xoffset': auto       " x offset of the windows, 0.1 means 10% from left of the screen
'yoffset': auto       " y offset of the windows, 0.1 means 10% from top of the screen
}
```
The defaults are customised for some builtin selectors, with the following values:
```vim
{
  'highlights': {
    'preview_ratio': 0.7,
   },
   'colors': {
     'compact': 1,
   },
   'help': {
     'preview_ratio': 0.6,
  },
}
```

Values set in `g:fuzzbox_window_options` will override the defaults. For
example, you can disable preview window for FuzzyFiles and friends with:
```vim
let g:fuzzbox_window_options = { 'files': { 'preview': 0 } }
```
or you change the width of the preview window for FuzzyHighlights with:
```vim
let g:fuzzbox_window_options = { 'highlights': { 'width': 0.5 } }
```

- preview is ignored by commands that do not support it, e.g. FuzzyCmdHistory
- x and y offsets are by default calculated to center the windows on the screen
- width, height, and x and y offsets > 0 and < 1 are resolved as percentages
- width, height, and x and y offsets >= 1 are fixed numbers of lines and cols
- invalid values for preview_ratio, width, height, and x & y offsets are ignored

### g:fuzzbox_async_step
Fuzzbox mimics async processing to fuzzy match in batches, which avoids problems
running Vim's built in fuzzy matching on massive lists at once. The size of
these batches is the async step value, which defaults to 10,000. This default
should work well for most developer workstations, but you might want to reduce
if you notice a lack of responsiveness on low spec machines
```vim
let g:fuzzbox_async_step = 10000
```

## User autocommands

Fuzzbox adds two `User` autocommands which you can use to run custom commands
when Fuzzbox is opened and closed. This can be helpful to aid compatibility with
other plugins, e.g. [vim-lsp](https://github.com/prabirshrestha/vim-lsp)

By default vim-lsp will automatically start configured language servers when the
filetype of a buffer changes. To avoid starting language servers unnecessarily
when you preview a file in Fuzzbox you can disable vim-lsp while Fuzzbox is open:

```vim
augroup LspFuzzbox
  autocmd!
  autocmd User FuzzboxOpened call lsp#disable()
  autocmd User FuzzboxClosed call lsp#enable()
augroup END
```

## Syntax highlighting

It is also possible to modify the colors used for highlighting. The defaults are
shown below, you can change them in your vimrc. See :help :highlight if you are
unfamiliar with Vim highlighting

```vim
highlight default link fuzzboxCursor Cursor
highlight default link fuzzboxNormal Normal
highlight default link fuzzboxBorder Normal
highlight default link fuzzboxCounter NonText
highlight default link fuzzboxMatching Special
highlight default link fuzzboxPreviewMatch Search
highlight default link fuzzboxPreviewLine Visual
```

Note: when the popup is open, Fuzzbox will technically hide the terminal cursor
and clear the Cursor highlight group. This is to work around limitations in how
|popupwin| operates. To allow fuzzboxCursor to be linked to Cursor (the default),
the resolved properties of Cursor are copied to fuzzboxCursor where possible.

## Credits

Fuzzbox was originally created as Fuzzyy by Nachuan Tang (@Donaldttt) and is
currently developed and maintained by Mark Woods (@mmrwoods). Many other people
have contributed code to fix bugs and add new features, and by submitting issues
to report bugs or suggest new features. Thanks for all the contributions!

The Fuzzbox logo is adapted from an image on [fuzzboxes.org](https://fuzzboxes.org/)
and is used with kind permission of Nick Sternberg.
