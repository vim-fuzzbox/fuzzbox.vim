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

def Test_FuzzyFiles_OpenSplit()
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

def Test_FuzzyFiles_OpenVSplit()
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

def Test_FuzzyFiles_OpenTab()
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
    assert_notequal(stridx(getline('.'), $'files{fs}foo.txt'), -1)
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

def Test_FuzzyGrep_OpenSplit()
    var winnr_before = winnr()
    var wincount_before = winnr('$')
    h.Execute('FuzzyGrep')
    h.Type('spam')
    h.Type('ham')
    h.Type('eggs')
    h.Type("\<C-S>")
    assert_equal($'files{fs}spam.txt', bufname())
    assert_equal(wincount_before + 1, winnr('$'))
    assert_notequal(winnr_before, winnr())
    close
enddef

def Test_FuzzyBuffers()
    edit files/foo.txt
    edit files/spam.txt
    h.Execute('FuzzyBuffers')
    h.Type('filesfoo')
    h.Enter()
    assert_equal($'files{fs}foo.txt', bufname())
enddef

def Test_FuzzyBuffers_OpenSplit()
    var winnr_before = winnr()
    var wincount_before = winnr('$')
    edit files/foo.txt
    edit files/spam.txt
    h.Execute('FuzzyBuffers')
    h.Type('filesfoo')
    h.Type("\<C-S>")
    assert_equal($'files{fs}foo.txt', bufname())
    assert_equal(wincount_before + 1, winnr('$'))
    assert_notequal(winnr_before, winnr())
    close
enddef

def Test_FuzzyInBuffer()
    edit files/foo.txt
    h.Type('o')
    h.Type('spam' .. 'ham' .. 'eggs')
    h.Escape()
    h.Execute('FuzzyInBuffer')
    h.Type('foo')
    h.Enter()
    assert_equal($'files{fs}foo.txt', bufname())
    assert_equal(1, line('.'))
    h.Type('u')
    write
enddef

def Test_FuzzyMru()
    edit files/foo.txt
    edit files/spam.txt
    h.Execute('FuzzyMru')
    h.Type('filesfoo')
    h.Enter()
    assert_equal($'files{fs}foo.txt', bufname())
enddef

def Test_FuzzyMru_OpenSplit()
    var winnr_before = winnr()
    var wincount_before = winnr('$')
    edit files/foo.txt
    edit files/spam.txt
    h.Execute('FuzzyMru')
    h.Type('filesfoo')
    h.Type("\<C-S>")
    assert_equal($'files{fs}foo.txt', bufname())
    assert_equal(wincount_before + 1, winnr('$'))
    assert_notequal(winnr_before, winnr())
    close
enddef

def Test_FuzzyMarks()
    edit files/foo.txt
    edit files/spam.txt
    h.Execute('FuzzyMarks')
    h.Type("'spam")
    h.Enter()
    assert_equal($'files{fs}spam.txt', bufname())
enddef

def Test_FuzzyMarks_OpenSplit()
    var winnr_before = winnr()
    var wincount_before = winnr('$')
    edit files/foo.txt
    h.Execute('FuzzyMarks')
    h.Type("'foo")
    h.Type("\<C-S>")
    assert_equal($'files{fs}foo.txt', bufname())
    assert_equal(wincount_before + 1, winnr('$'))
    assert_notequal(winnr_before, winnr())
enddef

def Test_FuzzyJumps()
    edit files/foo.txt
    edit files/spam.txt
    h.Execute('FuzzyJumps')
    h.Type("filesfoo")
    h.Enter()
    assert_equal($'files{fs}foo.txt', bufname())
enddef

def Test_FuzzyJumps_OpenSplit()
    var winnr_before = winnr()
    var wincount_before = winnr('$')
    edit files/foo.txt
    edit files/spam.txt
    h.Execute('FuzzyJumps')
    h.Type("filesfoo")
    h.Type("\<C-S>")
    assert_equal($'files{fs}foo.txt', bufname())
    assert_equal(wincount_before + 1, winnr('$'))
    assert_notequal(winnr_before, winnr())
    close
enddef

def Test_FuzzyChanges()
    edit files/foo.txt
    h.Type('ddu')
    write
    h.Execute('FuzzyChanges')
    h.Type("filesfoo")
    h.Enter()
    assert_equal($'files{fs}foo.txt', bufname())
enddef

def Test_FuzzyChanges_OpenSplit()
    var winnr_before = winnr()
    var wincount_before = winnr('$')
    edit files/foo.txt
    h.Type('ddu')
    write
    h.Execute('FuzzyChanges')
    h.Type("filesfoo")
    h.Type("\<C-S>")
    assert_equal($'files{fs}foo.txt', bufname())
    assert_equal(wincount_before + 1, winnr('$'))
    assert_notequal(winnr_before, winnr())
    close
enddef

tt.Run('Fuzzy*')
