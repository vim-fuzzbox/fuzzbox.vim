vim9script

import autoload '../internal/selector.vim'

export def Start(opts: dict<any> = {})
    selector.Start(argv(), extend(opts, { devicons: true }))
enddef
