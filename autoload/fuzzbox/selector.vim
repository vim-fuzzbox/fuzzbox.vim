vim9script

import autoload './internal/selector.vim'

export def Start(list: list<string>, opts: dict<any> = {}): dict<any>
    return selector.Start(list, opts)
enddef

export def UpdateResults(str_list: list<string>, hl_list: list<list<any>>,
        match_count: number, total_count: number)
    selector.UpdateResults(str_list, hl_list, match_count, total_count)
enddef
