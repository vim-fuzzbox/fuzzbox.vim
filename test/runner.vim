vim9script

# Requires libtinytest plugin included in the vim-devel package
# See https://github.com/lifepillar/vim-devel
# Or https://codeberg.org/lifepillar/vim-devel

var cwd_before: string
var bufnr_before: number
var lnum_before: number
var devicons_before: number
var splitright_before: bool
var splitbelow_before: bool

def GlobalSetup()
    cwd_before = getcwd()
    execute ':cd ' .. fnamemodify(expand('%'), ':p:h')
    bufnr_before = bufnr()
    lnum_before = line('.')
    splitright_before = &splitright
    splitbelow_before = &splitbelow
    set splitright
    set splitbelow
    devicons_before = exists('g:fuzzbox_devicons') ? g:fuzzbox_devicons : 1
    g:fuzzbox_devicons = 0
enddef

def GlobalTeardown()
    if bufwinnr(bufnr_before) != -1
        execute ':' .. bufwinnr(bufnr_before) .. 'wincmd w'
        execute ':buffer ' .. bufnr_before
        execute ':norm! ' .. lnum_before .. 'G'
        execute ':norm! zz'
        wincmd p
    endif
    &splitright = splitright_before
    &splitbelow = splitbelow_before
    execute ':norm! gg'
    if !empty(bufname('results.txt'))
        bwipe results.txt
    endif
    write results.txt
    g:fuzzbox_devicons = devicons_before
    execute ':cd ' .. cwd_before
enddef

try
    packadd libtinytest
    import 'libtinytest.vim' as tt
    GlobalSetup()
    for file in glob('*_test.vim', false, true)
        execute ':source ' .. file
    endfor
    var test_results = tt.Run()
    GlobalTeardown()
catch
    var msg = $'FAILED: Error running tests -> {v:exception} at {v:throwpoint}'
    writefile([msg], 'results.txt', 'a')
    echoerr msg
endtry
