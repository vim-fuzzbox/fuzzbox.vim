vim9script

# Experimental convenience script to create custom commands and selectors
#
# You can use this in your vimrc to create custom commmands that launch
# selectors with custom options, and create arbitrary selectors without
# creating a full Fuzzbox extension, e.g.
#
#   " Custom Fuzzbox command to search all files in CWD using ripgrep
#   command! FuzzyFilesAll call fuzzbox#Launch('files', #{command: 'rg -uu --files'})
#
#   " Custom Fuzzbox selector to toggle some pre-defined Vim options
#   function! FuzzyToggleCb(wid, result)
#       execute 'setlocal inv' .. a:result
#   endfunction
#   command! FuzzyToggle call fuzzbox#Select(
#       \ ['cursorcolumn', 'list', 'number', 'relativenumber', 'spell', 'wrap'],
#       \ #{
#       \   title: 'Toggle Option',
#       \   callback: function("FuzzyToggleCb")
#       \ })
#
# The above examples assume you are using legacy Vim script in your vimrc
#
# Note: selectors launched via fuzzbox#Select() are not remembered, and
# therefore are not known to FuzzyPrevious (this might be a good thing)

import autoload './fuzzbox/internal/launcher.vim'
import autoload './fuzzbox/internal/selector.vim' as _selector

export def Launch(selector: string, opts: dict<any> = {})
    launcher.Start(selector, opts)
enddef

export def Select(items: list<any>, opts: dict<any> = {})
    # Convenience options to simplify invocation
    var callback = has_key(opts, 'callback') ? function(remove(opts, 'callback')) : null
    var title = has_key(opts, 'title') ? remove(opts, 'title') : null

    if type(callback) == v:t_func
        opts.select_cb = callback
    endif
    if type(title) == v:t_string
        opts.prompt_title = title
    endif

    # Use compact view without a preview by default
    opts.compact = has_key(opts, 'compact') ? opts.compact : true
    opts.preview = has_key(opts, 'preview') ? opts.preview : false

    _selector.Start(items, opts)
enddef
