vim9script

import autoload './internal/selector.vim'

export def Start(list: list<string>, opts: dict<any> = {}): dict<any>
    return selector.Start(list, opts)
enddef

export def UpdateResults(str_list: list<string>, hl_list: list<list<any>>)
    selector.UpdateMenu(str_list, hl_list)
enddef
