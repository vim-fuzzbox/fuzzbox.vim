vim9script

# Requires libtinytest plugin included in the vim-devel package
# See https://github.com/lifepillar/vim-devel
# Or https://codeberg.org/lifepillar/vim-devel

try
    packadd libtinytest
    import 'libtinytest.vim' as tt
    if empty($TEST_FILE)
        for file in glob('*_test.vim', false, true)
            tt.Import(file)
        endfor
    else
        tt.Import($TEST_FILE)
    endif
    tt.Run()
    if !empty(bufname('results.txt'))
        bwipe results.txt
    endif
    write results.txt
catch
    var msg = $'FAILED: Error running tests -> {v:exception} at {v:throwpoint}'
    writefile([msg], 'results.txt', 'a')
    echoerr msg
endtry
