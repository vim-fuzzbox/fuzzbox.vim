vim9script

import autoload './internal/devicons.vim'

export def Colorize(wid: number = win_getid())
    devicons.AddColor(wid)
enddef
