vim9script

# gVim is very slow on my Windows AWS Workspace
var delay = has('win64') ? 2000 : 50
var fs = has('win64') ? '\' : '/'

def Wait()
    execute ':sleep ' .. delay .. 'm'
enddef

def Type(str: string)
    feedkeys(str, 'x')
    Wait()
enddef

def Execute(cmd: string)
    execute(cmd)
    Wait()
enddef

def Enter()
    feedkeys("\<CR>", 'x')
    Wait()
enddef

def Escape()
    feedkeys("\<Esc>", 'x')
    Wait()
enddef

def Test_FuzzyFiles()
    Execute('FuzzyFiles')
    Type('filesfoo')
    Enter()
    assert_equal($'files{fs}foo.txt', bufname())
    bwipe foo.txt
enddef

def Test_FuzzyGrep()
    Execute('FuzzyGrep')
    Type('spam')
    Type('ham')
    Type('eggs')
    Enter()
    assert_equal($'files{fs}spam.txt', bufname())
    bwipe spam.txt
enddef

def Test_FuzzyBuffers()
    edit files/foo.txt
    edit files/spam.txt
    Execute('FuzzyBuffers')
    Type('filesfoo')
    Enter()
    assert_equal($'files{fs}foo.txt', bufname())
    bwipe foo.txt
    bwipe spam.txt
enddef

def Test_FuzzyMruCwd()
    edit files/foo.txt
    edit files/spam.txt
    Execute('FuzzyMruCwd')
    Type('filesfoo')
    Enter()
    assert_equal($'files{fs}foo.txt', bufname())
    bwipe foo.txt
    bwipe spam.txt
enddef

def Test_Devicons()
    g:fuzzbox_devicons = 1
    assert_true(fuzzbox#internal#devicons#Enabled())
    Execute('FuzzyFiles')
    Type('filesfoo')
    var menu_wid = popup_list()->filter((_, wid) => getwinvar(wid, '&filetype') == 'fuzzbox_menu')[0]
    var menu_line = getbufoneline(winbufnr(menu_wid), line('$', menu_wid))
    var expected_glyph = function(g:fuzzbox_devicons_glyph_func)('files{fs}foo.txt')
    assert_equal(expected_glyph, menu_line[0])
    Enter()
    assert_equal($'files{fs}foo.txt', bufname())
    g:fuzzbox_devicons = 0
    assert_false(fuzzbox#internal#devicons#Enabled())
    bwipe foo.txt
enddef

def Test_OpenFileSplit()
    var winnr_before = winnr()
    var wincount_before = winnr('$')
    Execute('FuzzyFiles')
    Type('filesfoo')
    Type("\<C-S>")
    assert_equal($'files{fs}foo.txt', bufname())
    assert_equal(wincount_before + 1, winnr('$'))
    assert_notequal(winnr_before, winnr())
    bwipe foo.txt
enddef

def Test_OpenFileVSplit()
    var winnr_before = winnr()
    var wincount_before = winnr('$')
    Execute('FuzzyFiles')
    Type('filesfoo')
    Type("\<C-V>")
    assert_equal($'files{fs}foo.txt', bufname())
    assert_equal(wincount_before + 1, winnr('$'))
    assert_notequal(winnr_before, winnr())
    bwipe foo.txt
enddef

def Test_OpenFileTab()
    var tabpage_before = tabpagenr()
    var tabcount_before = tabpagenr('$')
    Execute('FuzzyFiles')
    Type('filesfoo')
    Type("\<C-T>")
    assert_equal($'files{fs}foo.txt', bufname())
    assert_equal(tabcount_before + 1, tabpagenr('$'))
    assert_notequal(tabpage_before, tabpagenr())
    bwipe foo.txt
enddef

def Test_SendToQuickfix()
    Execute('FuzzyFiles')
    Type('filesfoo')
    Type("\<C-Q>")
    cwindow
    assert_equal(stridx(getline('.'), $'files{fs}foo.txt'), 0)
    cclose
enddef
