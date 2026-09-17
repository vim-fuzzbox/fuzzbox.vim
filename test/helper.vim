vim9script

# gVim is very slow on my Windows AWS Workspace
var delay = has('win64') ? 2000 : 50
var fs = has('win64') ? '\' : '/'

var bufnr: number
var winnr: number
var buffers: list<number>
var devicons: bool
var mru_cwd_only: bool
var splitright: bool
var splitbelow: bool

export def Setup()
    bufnr = bufnr()
    winnr = winnr()
    buffers = getbufinfo({buflisted: 1})->map((_, buf) => buf.bufnr)
    execute ':cd ' .. fnamemodify(expand('<script>'), ':p:h')
    splitright = &splitright
    splitbelow = &splitbelow
    set splitright
    set splitbelow
    # mru_cwd_only = exists('g:fuzzbox_mru_cwd_only') ? g:fuzzbox_mru_cwd_only : 0
    # g:fuzzbox_mru_cwd_only = 1
    devicons = exists('g:fuzzbox_devicons') ? g:fuzzbox_devicons : 1
    g:fuzzbox_devicons = 0
enddef

export def Teardown()
    execute ':' .. winnr .. 'wincmd w'
    execute ':buffer ' .. bufnr
    for buf in getbufinfo({buflisted: 1})
        if index(buffers, buf.bufnr) == -1
            execute 'bwipe ' .. buf.bufnr
        endif
    endfor
    cd -
    &splitright = splitright
    &splitbelow = splitbelow
    # g:fuzzbox_mru_cwd_only = mru_cwd_only
    g:fuzzbox_devicons = devicons
enddef

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
