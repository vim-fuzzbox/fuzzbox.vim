vim9script

import './helper.vim' as h
var fs = has('win64') ? '\' : '/'

def Test_FuzzyFiles()
    h.Execute('FuzzyFiles')
    h.Type('filesfoo')
    h.Enter()
    assert_equal($'files{fs}foo.txt', bufname())
    execute $'bwipe files{fs}foo.txt'
enddef

def Test_FuzzyGrep()
    h.Execute('FuzzyGrep')
    h.Type('spam')
    h.Type('ham')
    h.Type('eggs')
    h.Enter()
    assert_equal($'files{fs}spam.txt', bufname())
    execute $'bwipe files{fs}spam.txt'
enddef

def Test_FuzzyBuffers()
    edit files/foo.txt
    edit files/spam.txt
    h.Execute('FuzzyBuffers')
    h.Type('filesfoo')
    h.Enter()
    assert_equal($'files{fs}foo.txt', bufname())
    execute $'bwipe files{fs}foo.txt'
enddef

def Test_FuzzyMruCwd()
    edit files/foo.txt
    edit files/spam.txt
    h.Execute('FuzzyMruCwd')
    h.Type('filesfoo')
    h.Enter()
    assert_equal($'files{fs}foo.txt', bufname())
    execute $'bwipe files{fs}foo.txt'
    execute $'bwipe files{fs}spam.txt'
enddef

def Test_OpenFileSplit()
    var winnr_before = winnr()
    var wincount_before = winnr('$')
    h.Execute('FuzzyFiles')
    h.Type('filesfoo')
    h.Type("\<C-S>")
    assert_equal($'files{fs}foo.txt', bufname())
    assert_equal(wincount_before + 1, winnr('$'))
    assert_notequal(winnr_before, winnr())
    execute $'bwipe files{fs}foo.txt'
enddef

def Test_OpenFileVSplit()
    var winnr_before = winnr()
    var wincount_before = winnr('$')
    h.Execute('FuzzyFiles')
    h.Type('filesfoo')
    h.Type("\<C-V>")
    assert_equal($'files{fs}foo.txt', bufname())
    assert_equal(wincount_before + 1, winnr('$'))
    assert_notequal(winnr_before, winnr())
    execute $'bwipe files{fs}foo.txt'
enddef

def Test_OpenFileTab()
    var tabpage_before = tabpagenr()
    var tabcount_before = tabpagenr('$')
    h.Execute('FuzzyFiles')
    h.Type('filesfoo')
    h.Type("\<C-T>")
    assert_equal($'files{fs}foo.txt', bufname())
    assert_equal(tabcount_before + 1, tabpagenr('$'))
    assert_notequal(tabpage_before, tabpagenr())
    execute $'bwipe files{fs}foo.txt'
enddef

def Test_SendToQuickfix()
    h.Execute('FuzzyFiles')
    h.Type('filesfoo')
    h.Type("\<C-Q>")
    cwindow
    assert_equal(stridx(getline('.'), $'files{fs}foo.txt'), 0)
    cclose
enddef
