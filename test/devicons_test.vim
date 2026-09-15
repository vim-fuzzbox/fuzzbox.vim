vim9script

packadd devicons

import './helper.vim' as h
var fs = has('win64') ? '\' : '/'

def Test_Devicons()
    g:fuzzbox_devicons = 1
    assert_true(fuzzbox#internal#devicons#Enabled())
    h.Execute('FuzzyFiles')
    h.Type('filesfoo')
    var menu_wid = popup_list()->filter((_, wid) => getwinvar(wid, '&filetype') == 'fuzzbox_menu')[0]
    var menu_line = getbufoneline(winbufnr(menu_wid), line('$', menu_wid))
    var expected_glyph = function(g:fuzzbox_devicons_glyph_func)('files{fs}foo.txt')
    h.Enter()
    # Note: vim-devicons appends a space in gui vim by default, see g:DevIconsAppendArtifactFix
    assert_equal(expected_glyph[0], menu_line[0])
    assert_equal($'files{fs}foo.txt', bufname())
    g:fuzzbox_devicons = 0
    assert_false(fuzzbox#internal#devicons#Enabled())
    execute $'bwipe files{fs}foo.txt'
enddef

def Test_DeviconColors()
    g:fuzzbox_devicons = 1
    assert_true(fuzzbox#internal#devicons#Enabled())
    h.Execute('FuzzyFiles')
    var menu_wid = popup_list()->filter((_, wid) => getwinvar(wid, '&filetype') == 'fuzzbox_menu')[0]
    var matches = getmatches(menu_wid)
    h.Escape()
    assert_notequal([], matches->filter((_, match) => match.group =~ '^fuzzboxDevicon_'))
    g:fuzzbox_devicons = 0
    assert_false(fuzzbox#internal#devicons#Enabled())
enddef
