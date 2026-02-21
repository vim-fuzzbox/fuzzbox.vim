vim9script

import autoload './internal/popup.vim'

export def SetTitle(wid: number, str: string)
    popup.SetTitle(wid, str)
enddef

export def SetCounter(count: any, total: any = null)
    popup.SetCounter(count, total)
enddef
