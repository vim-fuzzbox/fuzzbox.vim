vim9script

import autoload '../internal/selector.vim'
import autoload '../internal/popup.vim'

import autoload 'lsp/lsp.vim'
import autoload 'lsp/buffer.vim' as buf
import autoload 'lsp/util.vim'
import autoload 'lsp/symbol.vim'
import autoload 'lsp/offset.vim'

var separator = g:fuzzbox_menu_separator

var symtable: list<dict<any>>
var rawlines: list<string>
var filetype: string
var filename: string
var lspserver: dict<any>
var bufnr: number

def ParseResult(result: string): list<any>
    var lnum = str2nr(split(result, separator)[0])
    var text = trim(split(result, separator)[1])
    var idx = indexof(symtable, (_, v) => {
        return v.lnum == lnum && v.text ==# text
    })
    var range = symtable[idx].range
    try
        offset.DecodePosition(lspserver, bufnr, range.start)
    catch
        echo 'Fuzzbox: error decoding lsp offset position ' .. v:exception .. ' ' .. v:throwpoint
    endtry
    return [lnum, range.start.character + 1]
enddef

def Select(wid: number, result: string)
    if empty(result)
        return
    endif
    var [lnum, col] = ParseResult(result)
    cursor(lnum, col)
    exe 'norm! zz'
enddef

def Preview(wid: number, result: string)
    if wid == -1
        return
    endif
    if empty(result)
        popup_settext(wid, '')
        return
    endif
    var preview_bufnr = winbufnr(wid)
    var [lnum, col] = ParseResult(result)
    if popup_getpos(wid).lastline == 1
        popup.SetTitle(wid, fnamemodify(filename, ':t'))
        popup_settext(wid, rawlines)
        setbufvar(preview_bufnr, '&syntax', filetype)
    endif
    win_execute(wid, 'norm! ' .. lnum .. 'G')
    win_execute(wid, 'norm! zz')
    clearmatches(wid)
    matchaddpos('fuzzboxPreviewLine', [lnum], 999, -1,  {window: wid})
    matchaddpos('fuzzboxPreviewCol', [[lnum, col]], 9999, -1,  {window: wid})
enddef

def OpenFileTab(wid: number, result: string)
    if empty(result)
        return
    endif
    var [lnum, col] = ParseResult(result)
    popup_close(wid)
    exe 'tabnew'
    exe 'buffer ' .. bufnr
    cursor(lnum, col)
    exe 'norm! zz'
enddef

def OpenFileVSplit(wid: number, result: string)
    if empty(result)
        return
    endif
    var [lnum, col] = ParseResult(result)
    popup_close(wid)
    exe 'vsplit'
    exe 'buffer ' .. bufnr
    cursor(lnum, col)
    exe 'norm! zz'
enddef

def OpenFileSplit(wid: number, result: string)
    if empty(result)
        return
    endif
    var [lnum, col] = ParseResult(result)
    popup_close(wid)
    exe 'split'
    exe 'buffer ' .. bufnr
    cursor(lnum, col)
    exe 'norm! zz'
enddef

def Close(wid: number)
    # release memory
    symtable = [{}]
    rawlines = []
    lspserver = {}
enddef

# process SymbolInformation[]
# Copied from scope.vim and lsp.vim
def ProcessSymbolInfoTable(symbolInfoTable: list<dict<any>>,
        symbolTable: list<dict<any>>)

    for syminfo in symbolInfoTable
        var symbolType = symbol.SymbolKindToName(syminfo.kind)->tolower()
        var text = syminfo.name
        if syminfo->has_key('containerName') && !syminfo.containerName->empty()
            text ..= $' [{syminfo.containerName}]'
        endif
        text ..= $' <{symbolType}>'
        var range: dict<dict<number>> = syminfo.location.range
        var lnum = range.start.line + 1
        symbolTable->add({text: text, range: range, lnum: lnum})
    endfor
enddef

# process DocumentSymbol[]
# Copied from scope.vim and lsp.vim
def ProcessDocSymbolTable(docSymbolTable: list<dict<any>>,
        symbolTable: list<dict<any>>,
        parentName: string = '')

    for syminfo in docSymbolTable
        var symbolType = symbol.SymbolKindToName(syminfo.kind)->tolower()
        var range: dict<dict<number>> = syminfo.selectionRange
        var lnum = range.start.line + 1
        var text = $'{syminfo.name} {parentName != null_string ? parentName : ""} <{symbolType}>'
        symbolTable->add({text: text, range: range, lnum: lnum})

        if syminfo->has_key('children')
            # Process all the child symbols
            ProcessDocSymbolTable(syminfo.children, symbolTable,
                syminfo.name)
        endif
    endfor
enddef

export def Start(opts: dict<any> = {})
    opts.title = has_key(opts, 'title') ? opts.title : 'LSP Document Symbols'

    bufnr = bufnr()
    symtable = []
    rawlines = getline(1, '$')
    filetype = &filetype
    filename = expand('%')
    if filename->empty()
        return
    endif

    lspserver = buf.BufLspServerGet(bufnr(), 'documentSymbol')
    if lspserver->empty()
        echo 'LSP server not found'
        return
    elseif !lspserver.running || !lspserver.ready
        echo 'LSP server not ready'
        return
    endif

    def ReplyCb(_: dict<any>, reply: list<dict<any>>)
        if reply->empty()
            echo 'LSP reply is empty'
            return
        endif

        if reply[0]->has_key('location')
            # reply is of type SymbolInformation[]
            ProcessSymbolInfoTable(reply, symtable)
        else
            # reply is of type DocumentSymbol[]
            ProcessDocSymbolTable(reply, symtable)
        endif

        # sort the symbols by line number
        symtable->sort((a, b) => a.lnum - b.lnum)

        # var fmt = ' %' .. len(string(line('$'))) .. 'd ' .. separator .. ' %s'
        var fmt = '%s (%d)'
        var lines = symtable->mapnew((_, v) => printf(fmt, v.text, v.lnum))

        var wids = selector.Start(lines, extend(opts, {
            preview: false,
            select_cb: function('Select'),
            preview_cb: function('Preview'),
            close_cb: function('Close'),
            actions: {
                "\<c-v>": function('OpenFileVSplit'),
                "\<c-s>": function('OpenFileSplit'),
                "\<c-t>": function('OpenFileTab'),
            }
        }))

        win_execute(wids.menu, $'syn match NonText "<\w\+>"')
        win_execute(wids.menu, $'syn match NonText "(\d\+)"')
    enddef

    var params = {textDocument: {uri: util.LspFileToUri(filename)}}
    lspserver.rpc_a('textDocument/documentSymbol', params, ReplyCb)
enddef
