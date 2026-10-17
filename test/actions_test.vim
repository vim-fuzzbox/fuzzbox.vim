vim9script

import 'libtinytest.vim' as tt

# ParseResult() is not exported, so call it using its script-local <SNR> name
def GetScriptFunc(script: string, name: string): func
    if empty(getscriptinfo({name: script .. '$'}))
        execute 'runtime autoload/' .. script
    endif
    var sid = getscriptinfo({name: script .. '$'})[0].sid
    return function($'<SNR>{sid}_{name}')
enddef

def Test_ParseResult()
    var ParseResult = GetScriptFunc('fuzzbox/internal/actions.vim', 'ParseResult')
    # [result, [file, line, col, text]]
    var cases = [
        # file only
        ['foo.txt', ['foo.txt', 0, 0, '']],
        ['dir/foo.txt', ['dir/foo.txt', 0, 0, '']],
        # line and column
        ['foo.c:10', ['foo.c', 10, 0, '']],
        ['foo.c:10:5', ['foo.c', 10, 5, '']],
        ['foo.c:10:5:', ['foo.c', 10, 5, '']],
        # text
        ['foo.c:10:text', ['foo.c', 10, 0, 'text']],
        ['foo.c:10:5:text', ['foo.c', 10, 5, 'text']],
        ['foo.c:10:5:  indented text', ['foo.c', 10, 5, '  indented text']],
        ['foo.c:10:text: with: colons', ['foo.c', 10, 0, 'text: with: colons']],
        ['foo.c:10:5:text:20:30:', ['foo.c', 10, 5, 'text:20:30:']],
        ['foo.c:10:42 is not a column', ['foo.c', 10, 0, '42 is not a column']],
        # timestamp in the text, e.g. from grep -n, which does not include column
        ['log.txt:10:at 09:12:30: error', ['log.txt', 10, 0, 'at 09:12:30: error']],
        ['log.txt:10:5:at 09:12:30: error', ['log.txt', 10, 5, 'at 09:12:30: error']],
        # colons in file and directory names
        ['a:b.txt', ['a:b.txt', 0, 0, '']],
        ['a:b/c:d.txt:10:5:text', ['a:b/c:d.txt', 10, 5, 'text']],
        ['notes:2024/a.md', ['notes:2024/a.md', 0, 0, '']],
        ['notes:2024/a.md:3:text', ['notes:2024/a.md', 3, 0, 'text']],
        ['meeting 12:30.md', ['meeting 12:30.md', 0, 0, '']],
        # spaces in file and directory names
        ['my file.txt', ['my file.txt', 0, 0, '']],
        ['my dir/my file.txt', ['my dir/my file.txt', 0, 0, '']],
        ['my dir/my file.txt:10:5:some text', ['my dir/my file.txt', 10, 5, 'some text']],
        [' leading and trailing .txt ', [' leading and trailing .txt ', 0, 0, '']],
        ['my dir/12 30.txt:7:text', ['my dir/12 30.txt', 7, 0, 'text']],
        # Windows paths
        ['C:\dir\foo.txt', ['C:\dir\foo.txt', 0, 0, '']],
        ['C:\dir\foo.txt:10:5:text', ['C:\dir\foo.txt', 10, 5, 'text']],
        ['C:\Program Files\my file.txt:10:text', ['C:\Program Files\my file.txt', 10, 0, 'text']],
        # ambiguous, file names containing :digits: or ending in :digits
        ['foo:12', ['foo', 12, 0, '']],
        ['dir:1:/foo.txt', ['dir', 1, 0, '/foo.txt']],
    ]
    for [result, expected] in cases
        assert_equal(expected, ParseResult(result), $'ParseResult("{result}")')
    endfor
enddef
