vim9script

# Detect filetype without triggering FileType autocmds

# Skip if filetype detection not enabled, see $VIMRUNTIME/filetype.vim
if !exists("g:did_load_filetypes")
  finish
endif

# Copy simple filetypedetect autocmds patterns to detect ft with noautocmd
# Works for many file types, but not all, hence additional patterns below
for item in autocmd_get({
        group: 'filetypedetect', event: 'BufNewFile'
    })->filter((_, val) => {
        return val.cmd =~ '\M^setf\(iletype\)\?\s\+\w\+$' || val.cmd =~ '\M^call\s\+dist#ft#\w\+'
    })

    autocmd_add([{
        group: 'fuzzboxFiletypeDetect',
        event: 'User',
        cmd: 'noautocmd ' .. item.cmd,
        pattern: item.pattern
    }])
endfor

# Filetypes that are not handled by copying simple filetypedetect autocmds above
# No allowance for precedence, only one pattern expected to match each filetype
# Note that this needs to allow for older versions of $VIMRUNTIME/filetype.vim
var filetype_patterns = {
    c:          '*.c,*.h',
    cfg:        '*.cfg',
    cpp:        '*.hpp',
    d:          '*.d',
    eiffel:     '*.e',
    elixir:     '*.ex',
    fortran:    '*.f',
    fsharp:     '*.fs',
    html:       '*.html,*.htm',
    lisp:       '*.cl',
    make:       '[Mm]akefile',
    markdown:   '*.markdown,*.mdown,*.mkd,*.mkdn,*.mdwn,*.md',
    matlab:     '*.m',
    perl:       '*.pl,*.pm',
    php:        '*.inc',
    r:          '*.R,*.r',
    sh:         '*.sh',
    sql:        '*.sql',
    terraform:  '*.tf',
    tex:        '*.tex',
    typescript: '*.ts',
    vim:        '*vimrc*',
    xml:        '*.xml',
}
for [filetype, pattern] in items(filetype_patterns)
    autocmd_add([{
        group: 'fuzzboxFiletypeDetect',
        event: 'User',
        cmd: 'noautocmd setf ' .. filetype,
        pattern: pattern
    }])
endfor

# When no pattern matches, try to detect filetype from content
au fuzzboxFiletypeDetect User * {
    if empty(&filetype)
        try
            noautocmd dist#script#DetectFiletype()
        catch
            echohl ErrorMsg
            echom 'fuzzbox:' v:exception .. ' ' .. v:throwpoint
            echohl None
        endtry
    endif
}

# Use conf as FALLBACK in same way as $VIMRUNTIME/filetype.vim
au fuzzboxFiletypeDetect User * {
    if empty(&filetype) && (
            expand("<amatch>") =~# '\.conf$'
            || getline(1) =~ '^#' || getline(2) =~ '^#'
            || getline(3) =~ '^#' || getline(4) =~ '^#'
            || getline(5) =~ '^#')
        noautocmd setf FALLBACK conf
    endif
}
