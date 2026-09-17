vim9script

import 'libtinytest.vim' as tt
import './helper.vim' as h
var fs = has('win64') ? '\' : '/'

tt.Setup = h.Setup
tt.Teardown = h.Teardown

def Test_FuzzyFiles()
    h.Execute('FuzzyFiles')
    h.Type('filesfoo')
    h.Enter()
    assert_equal($'files{fs}foo.txt', bufname())
enddef

def Test_FuzzyFiles_OpenFileSplit()
    var winnr_before = winnr()
    var wincount_before = winnr('$')
    h.Execute('FuzzyFiles')
    h.Type('filesfoo')
    h.Type("\<C-S>")
    assert_equal($'files{fs}foo.txt', bufname())
    assert_equal(wincount_before + 1, winnr('$'))
    assert_notequal(winnr_before, winnr())
    close
enddef

def Test_FuzzyFiles_OpenFileVSplit()
    var winnr_before = winnr()
    var wincount_before = winnr('$')
    h.Execute('FuzzyFiles')
    h.Type('filesfoo')
    h.Type("\<C-V>")
    assert_equal($'files{fs}foo.txt', bufname())
    assert_equal(wincount_before + 1, winnr('$'))
    assert_notequal(winnr_before, winnr())
    close
enddef

def Test_FuzzyFiles_OpenFileTab()
    var tabpage_before = tabpagenr()
    var tabcount_before = tabpagenr('$')
    h.Execute('FuzzyFiles')
    h.Type('filesfoo')
    h.Type("\<C-T>")
    assert_equal($'files{fs}foo.txt', bufname())
    assert_equal(tabcount_before + 1, tabpagenr('$'))
    assert_notequal(tabpage_before, tabpagenr())
    tabclose
enddef

def Test_FuzzyFiles_SendToQuickfix()
    h.Execute('FuzzyFiles')
    h.Type('filesfoo')
    h.Type("\<C-Q>")
    cwindow
    assert_equal(stridx(getline('.'), $'files{fs}foo.txt'), 0)
    cclose
enddef

def Test_FuzzyGrep()
    h.Execute('FuzzyGrep')
    h.Type('spam')
    h.Type('ham')
    h.Type('eggs')
    h.Enter()
    assert_equal($'files{fs}spam.txt', bufname())
enddef

def Test_FuzzyBuffers()
    edit files/foo.txt
    edit files/spam.txt
    h.Execute('FuzzyBuffers')
    h.Type('filesfoo')
    h.Enter()
    assert_equal($'files{fs}foo.txt', bufname())
enddef

def Test_FuzzyMruCwd()
    edit files/foo.txt
    edit files/spam.txt
    h.Execute('FuzzyMruCwd')
    h.Type('filesfoo')
    h.Enter()
    assert_equal($'files{fs}foo.txt', bufname())
enddef

tt.Run('Fuzzy*')
