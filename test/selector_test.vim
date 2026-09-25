vim9script

import 'libtinytest.vim' as tt
import './helper.vim' as h

tt.Setup = h.Setup
tt.Teardown = h.Teardown

var selected: string

# Search asynchronously over two batches, with matches only in the first, then
# select the first result, which should be the best match
def AssertBestMatchSelected(dropdown: bool)
    var li = ['tar/get.txt', 'x/target.txt']
    li += range(g:fuzzbox_async_step * 2 - len(li))->mapnew((_, i) => $'file{i}.txt')
    selected = ''
    fuzzbox#selector#Start(li, {
        async: true,
        dropdown: dropdown,
        select_cb: (wid, result) => {
            selected = result
            popup_close(wid)
        },
    })
    h.Type('target')
    execute ':sleep ' .. (g:fuzzbox_async_wait * 2 + 50) .. 'm'
    h.Enter()
    assert_equal('x/target.txt', selected)
enddef

def Test_Selector_Async_BestMatch()
    AssertBestMatchSelected(false)
enddef

def Test_Selector_Async_BestMatch_Dropdown()
    AssertBestMatchSelected(true)
enddef

tt.Run('Selector*')
