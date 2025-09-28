vim9script

import autoload './internal/selector.vim'

export def Start(list: list<string>, opts: dict<any> = {}): dict<any>
    return selector.Start(list, opts)
enddef
