vim9script

import autoload '../internal/selector.vim'

export def Start(opts: dict<any> = {})
    if empty(argv())
        echohl ErrorMsg | echo "Arglist is empty" | echohl None
        return
    endif

    selector.Start(argv(), extend(opts, { devicons: true }))
enddef
