vim9script

import autoload './internal/popup.vim'

export def SetTitle(wid: number, str: string)
    popup.SetTitle(wid, str)
enddef

export def SetCounter(count: any, total: any = null)
    popup.SetCounter(count, total)
enddef

export def UpdateMenu(str_list: list<string>, hl_list: list<list<any>>)
    popup.UpdateMenu(str_list, hl_list)
enddef
