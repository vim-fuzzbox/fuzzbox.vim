vim9script

import autoload './internal/popup.vim'

export def SetTitle(wid: number, str: string)
    popup.SetTitle(wid, str)
enddef
