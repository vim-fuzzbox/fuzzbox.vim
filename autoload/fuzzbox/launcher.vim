vim9script

import autoload './internal/launcher.vim'

export def Start(selector: string, opts: dict<any> = {})
    launcher.Start(selector, opts)
enddef
