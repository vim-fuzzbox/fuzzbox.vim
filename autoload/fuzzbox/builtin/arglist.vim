vim9script

import autoload '../internal/selector.vim'

export def Start(opts: dict<any> = {})
    opts.title = has_key(opts, 'title') ? opts.title : 'Arglist'

    if empty(argv())
        echohl ErrorMsg | echo "Arglist is empty" | echohl None
        return
    endif

    selector.Start(argv(), extend(opts, { devicons: true }))
enddef
