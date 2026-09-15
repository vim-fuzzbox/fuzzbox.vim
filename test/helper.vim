vim9script

# gVim is very slow on my Windows AWS Workspace
var delay = has('win64') ? 2000 : 50

export def Wait()
    execute ':sleep ' .. delay .. 'm'
enddef

export def Type(str: string)
    feedkeys(str, 'x')
    Wait()
enddef

export def Execute(cmd: string)
    execute(cmd)
    Wait()
enddef

export def Enter()
    feedkeys("\<CR>", 'x')
    Wait()
enddef

export def Escape()
    feedkeys("\<Esc>", 'x')
    Wait()
enddef
