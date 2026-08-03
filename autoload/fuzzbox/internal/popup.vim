vim9script

scriptencoding utf-8

import autoload './colors.vim'
import autoload './devicons.vim'
import autoload './launcher.vim'
import autoload './utils.vim'

var wins = { menu: -1, prompt: -1, preview: -1 }
var options: dict<any>
var cursor_pos: number
var cursor_mid: number
var loading_tid: number
var preview_tid: number
var t_ve: string
var hlcursor: dict<any>
export var active = false

var keymaps: dict<any> = {
    'menu_up': ["\<C-p>", "\<Up>"],
    'menu_down': ["\<C-n>", "\<Down>"],
    'menu_select': ["\<CR>"],
    'menu_page_up': [],
    'menu_page_down': [],
    'menu_scroll_up': ["\<PageUp>"],
    'menu_scroll_down': ["\<PageDown>"],
    'menu_shift_up': [],
    'menu_shift_down': [],
    'preview_page_up': [],
    'preview_page_down': [],
    'preview_scroll_up': ["\<S-Up>"],
    'preview_scroll_down': ["\<S-Down>"],
    'preview_shift_up': [],
    'preview_shift_down': [],
    'cursor_begining': ["\<C-b>", "\<Home>"], # :h c_CTRL-B
    'cursor_end': ["\<C-e>", "\<End>"], # :h c_CTRL-E
    'cursor_word_left': ["\<C-Left>"], # :h c_<C-Left>
    'cursor_word_right': ["\<C-Right>"], # :h c_<C-Right>
    'backspace': ["\<C-h>", "\<BS>"], # :h c_CTRL-H
    'delete': ["\<Del>"], # :h c_<Del>
    'delete_all': [],
    'delete_word': ["\<C-w>"], # :h c_CTRL-W
    'delete_prefix': ["\<C-u>"], # :h c_CTRL-U
    'exit': ["\<Esc>", "\<C-c>", "\<C-[>"], # :h c_<Esc>, :h c_CTRL-C
}
keymaps = exists('g:fuzzbox_keymaps') && type(g:fuzzbox_keymaps) == v:t_dict ?
    extend(keymaps, g:fuzzbox_keymaps) : keymaps

var dynamic_preview_title = exists('g:fuzzbox_dynamic_preview_title') ?
    g:fuzzbox_dynamic_preview_title : true

var preview_cutoff = exists('g:fuzzbox_preview_cutoff')
    && type(g:fuzzbox_preview_cutoff) == v:t_number ?
    g:fuzzbox_preview_cutoff : 120

var compact_after = exists('g:fuzzbox_compact_after')
    && type(g:fuzzbox_compact_after) == v:t_number
    ? g:fuzzbox_compact_after : 420

var borderchars = exists('g:fuzzbox_borderchars') &&
    type(g:fuzzbox_borderchars) == v:t_list &&
    [4, 8]->index(len(g:fuzzbox_borderchars)) != -1 ?
    g:fuzzbox_borderchars : (
        &encoding == 'utf-8' ?
            ['─', '│', '─', '│', '╭', '╮', '╯', '╰'] :
            ['-', '|', '-', '|']
    )

var loadingchars = exists('g:fuzzbox_loadingchars') &&
    type(g:fuzzbox_loadingchars) == v:t_list ?
    g:fuzzbox_loadingchars : (
        &encoding == 'utf-8' ?
            ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'] :
            ['|', '/', '-', '\']
    )

var selection_sign = exists('g:fuzzbox_selection_sign')
    && type(g:fuzzbox_selection_sign) == v:t_string ?
    g:fuzzbox_selection_sign : '>'

if !empty(selection_sign)
    sign_define('FuzzboxSelection', {text: selection_sign, texthl: 'fuzzboxSelectionSign'})
endif

def ResolveCursor()
    hlset([{name: 'fuzzboxCursor', cleared: true}])
    var fallback = {
        name: 'fuzzboxCursor',
        term: { 'reverse': true },
        cterm: { 'reverse': true },
        gui: { 'reverse': true },
    }
    var attrs = hlget('Cursor', true)->get(0, {})
    if !attrs->get('guifg') && !attrs->get('guibg')
        hlset([fallback])
        return
    endif
    var special = ['NONE', 'bg', 'fg', 'background', 'foreground']
    var guifg = attrs->get('guifg', 'NONE')
    var guibg = attrs->get('guibg', 'NONE')
    if has('gui')
        hlset([{name: 'fuzzboxCursor', guifg: guifg, guibg: guibg}])
        return
    endif
    var ctermfg = attrs->get('ctermfg',
        index(special, guifg) != -1 ? guifg : string(colors.TermColor(guifg))
    )
    var ctermbg = attrs->get('ctermbg',
        index(special, guibg) != -1 ? guibg : string(colors.TermColor(guibg))
    )
    try
        hlset([{
            name: 'fuzzboxCursor',
            guifg: guifg,
            guibg: guibg,
            ctermfg: ctermfg,
            ctermbg: ctermbg
        }])
    catch /\v:(E419|E420|E453):/
        # foreground and/or background not known and used as ctermfg or ctermbg
        hlset([fallback])
    catch
        utils.Warn('Fuzzbox: failed to resolve cursor highlight: ' .. v:exception)
        hlset([fallback])
    endtry
enddef

# Use to hide the cursor while popups active
def HideCursor()
    # terminal cursor
    t_ve = &t_ve
    setlocal t_ve=
    # gui cursor
    if len(hlget('Cursor')) > 0
        hlcursor = hlget('Cursor')[0]
        hlset([{name: 'Cursor', cleared: true}])
    endif
enddef

# Use to restore cursor when closing popups
def ShowCursor()
    # terminal cursor
    if &t_ve != t_ve
        &t_ve = t_ve
    endif
    # gui cursor
    if len(hlget('Cursor')) > 0 && get(hlget('Cursor')[0], 'cleared', false)
        hlset([hlcursor])
    endif
enddef

def InvokeAction(Action: func, wid: number)
    if Action == null # allow for null_function
        return
    endif
    var linetext = GetResult()

    var sig = typename(Action)->matchlist('func(\(.*\))$')[1]->split(', ')

    var args: list<any>
    if len(sig) > 0
        args->add(wid)
    endif
    if len(sig) > 1
        if sig[1] =~ '^list<\l\+>$'
            # backwards compatibility with old sig, result as list
            args->add([linetext])
        else
            args->add(linetext)
        endif
    endif
    if len(sig) > 2
        args->add(options)
    endif

    call(Action, args)
enddef

# Called when the menu window is closed, e.g. Esc key handled by MenuFilter
# Closes all Fuzzbox windows, triggers user autocmds, and resets everything
def MenuCallback(wid: number, result: any)
    if wid != wins.menu
        return
    endif

    if exists('#User#FuzzboxClosing')
        doautocmd <nomodeline> User FuzzboxClosing
    endif

    launcher.Save(wins)

    if has_key(options, 'close_cb')
            && type(options.close_cb) == v:t_func
        InvokeAction(options.close_cb, wins.menu)
    endif

    # we need to redraw if the windows overlap the statusline and cmdline
    var total_height = popup_getoptions(wins.menu).maxheight + popup_getoptions(wins.prompt).maxheight + 4 # 4 = borderchars
    var redraw_required = total_height >= &lines - &cmdheight

    # close each of the popup windows
    for key in keys(wins)
        if len(getwininfo(wins[key])) > 0 && wins[key] != wid
            popup_close(wins[key])
        endif
        wins[key] = -1
    endfor

    # call cleanup function from selector.vim, stop running timers etc.
    if has_key(options, 'cleanup') && type(options.cleanup) == v:t_func
        call(options.cleanup, [])
    endif

    # restore things to normal
    ShowCursor()
    active = false
    options = {}
    wins = { menu: -1, prompt: -1, preview: -1 }

    if redraw_required
        redraw
    endif

    if exists('#User#FuzzboxClosed')
        doautocmd <nomodeline> User FuzzboxClosed
    endif
enddef

# update menu window with list of items and positions for matchaddpos()
export def UpdateMenu(str_list: list<string>, hl_list: list<list<any>>)
    if options.devicons
        # avoid modifying source/raw list when adding devicons, and limit
        # columns to avoid slow rendering of highlights on very long lines
        var new_list = str_list->mapnew('slice(v:val, 0, 1000)')
        var hl_offset = devicons.GetDeviconOffset()
        var new_hl_list = reduce(hl_list, (a, v) => {
            v[1] += hl_offset
            return add(a, v)
        }, [])
        devicons.AddDevicons(new_list)
        MenuSetText(new_list)
        MenuSetHl(new_hl_list)
        devicons.AddColor(wins.menu)
    else
        MenuSetText(str_list)
        MenuSetHl(hl_list)
    endif
enddef

# Handle situation when Text under cursor in menu window is changed
def HandleChange()
    if !empty(selection_sign)
        var bufnr = winbufnr(wins.menu)
        var lnum = line('.', wins.menu)
        sign_unplace('PopUpFuzzbox', {buffer: bufnr, id: 1})
        sign_place(1, 'PopUpFuzzbox', 'FuzzboxSelection', bufnr, {lnum: lnum})
    endif
    if has_key(options, 'change_cb') &&
            type(options.change_cb) == v:t_func
            InvokeAction(options.change_cb, wins.menu)
    endif
    if wins.preview != -1 &&
            has_key(options, 'preview_cb') &&
            type(options.preview_cb) == v:t_func
        # timer to avoid triggering preview unnecessarily during mouse scroll
        timer_stop(preview_tid)
        preview_tid = timer_start(30, (_) => {
            if active # allow for popups to have closed when lambda is invoked
                InvokeAction(options.preview_cb, wins.preview)
            endif
        }, { repeat: 0 })
    endif
enddef

export def SetPrompt(content: string)
    if wins.prompt == -1
        return
    endif
    cursor_pos = 0
    popup_settext(wid, options.prompt_prefix .. " ")
    for i in range(strchars(content))
        PromptFilter(wins.prompt, strcharpart(content, i, 1, 1))
    endfor
enddef

export def GetPrompt(): string
    if wins.prompt == -1
        return ''
    endif
    var bufnr = winbufnr(wins.prompt)
    return getbufline(bufnr, 1, 1)[0]->substitute('^' .. options.prompt_prefix, '', '')[: -2]
enddef

# gets the selected result in the menu window (can be empty string)
def GetResult(): string
    var bufnr = winbufnr(wins.menu)
    var cursorlinepos = line('.', wins.menu)
    # note: getbufoneline() only added in vim 9.1.0916, neovim 0.9.0
    var linetext = getbufline(bufnr, cursorlinepos, cursorlinepos)[0]
    if options.devicons
        linetext = devicons.RemoveDevicon(linetext)
    endif
    return linetext
enddef

def PromptFilter(wid: number, key: string): number
    var bufnr = winbufnr(wid)
    var bufline = getbufline(bufnr, 1, 1)[0]->substitute('^' .. options.prompt_prefix, '', '')[: -2]
    var line = copy(bufline)
    var cur_pos = cursor_pos # index by number of char not byte
    var max_pos = len(line)
    var ascii_val = char2nr(key)
    if index(keymaps['backspace'], key) >= 0
        if cur_pos == len(line)
            line = line[: -2]
        else
            var before = cur_pos - 2 >= 0 ? line[: cur_pos - 2] : ''
            line = before .. line[cur_pos :]
        endif
        cur_pos = max([ 0, cur_pos - 1 ])
    elseif index(keymaps['delete'], key) >= 0
        if cur_pos == max_pos
            line = line[: -2]
            cur_pos -= 1
        elseif cur_pos == 0
            line = line[1 : ]
        else
            var before = cur_pos - 1 >= 0 ? line[: cur_pos - 1] : ''
            line = before .. line[cur_pos + 1 :]
        endif
    elseif index(keymaps['cursor_begining'], key) >= 0
        cur_pos = 0
    elseif index(keymaps['cursor_end'], key) >= 0
        cur_pos = max_pos
    elseif index(keymaps['cursor_word_left'], key) >= 0
        while cur_pos > 0 && line[cur_pos - 1] == ' '
            cur_pos = cur_pos - 1
        endwhile
        while cur_pos > 0 && line[cur_pos - 1] != ' '
            cur_pos = cur_pos - 1
        endwhile
    elseif index(keymaps['cursor_word_right'], key) >= 0
        while cur_pos < max_pos && line[cur_pos] != ' '
            cur_pos = cur_pos + 1
        endwhile
        while cur_pos < max_pos && line[cur_pos] == ' '
            cur_pos = cur_pos + 1
        endwhile
    elseif index(keymaps['delete_all'], key) >= 0
        line = ''
        cur_pos = 0
    elseif index(keymaps['delete_word'], key) >= 0
        var old_pos = cur_pos
        while cur_pos > 0 && line[cur_pos - 1] == ' '
            cur_pos = cur_pos - 1
        endwhile
        while cur_pos > 0 && line[cur_pos - 1] != ' '
            cur_pos = cur_pos - 1
        endwhile
        line = cur_pos - 1 >= 0 ? line[: cur_pos - 1] .. line[old_pos :] : line[old_pos :]
    elseif index(keymaps['delete_prefix'], key) >= 0
        line = line[cur_pos :]
        cur_pos = 0
    elseif key == "\<Left>"
        cur_pos = max([ 0, cur_pos - 1 ])
    elseif key == "\<Right>"
        cur_pos = min([ max_pos, cur_pos + 1 ])
    elseif key ==? "\<LeftMouse>" || key ==? "\<2-LeftMouse>"
        var pos = getmousepos()
        if pos.winid != wid
            return 0
        endif
        cur_pos = pos.wincol - strcharlen(options.prompt_prefix) - 2
        if cur_pos > max_pos
            cur_pos = max_pos
        endif
        if cur_pos < 0
            cur_pos = 0
        endif
    elseif key == "P" && has('gui') && line->slice(cur_pos - 3, cur_pos) == '"+g'
        # handle gvim & macvim paste, copied from scope.vim, thanks @girishji
        var pasted = getreg('+')
        line = line->slice(0, cur_pos - 3) .. pasted .. line->slice(cur_pos)
        cur_pos = (cur_pos - 3) + len(pasted)
    elseif (ascii_val >= 32 && ascii_val <= 126) || (ascii_val >= 160) || (ascii_val == 9)
        if cur_pos == len(line)
            line ..= key
        else
            var before = cur_pos - 1 >= 0 ? line[: cur_pos - 1] : ''
            line = before .. key .. line[cur_pos :]
        endif
        cur_pos += 1
    else
        # catch all unhandled keys
        return 1
    endif
    cursor_pos = cur_pos

    if bufline != line
        popup_settext(wid, options.prompt_prefix .. line .. " ")
        if has_key(options, 'input_cb')
            if options.dropdown
                win_execute(wins.menu, "silent! cursor(1, 1)")
            else
                win_execute(wins.menu, "silent! cursor('$', 1)")
            endif
            options.input_cb(wid, line)
        endif
    endif

    # cursor hl
    matchdelete(cursor_mid, wid)
    var hi_end_pos = len(options.prompt_prefix) + 1
    if cur_pos > 0
        hi_end_pos += len(line[: cur_pos - 1])
    endif
    cursor_mid = matchaddpos('fuzzboxCursor', [[1, hi_end_pos]], 10, -1, {window: wid})
    return 1
enddef

def MenuFilter(wid: number, key: string): number
    var bufnr = winbufnr(wid)
    var width = popup_getoptions(wid).maxwidth
    var moved = 0
    var cursorline = line('.', wid)
    if index(keymaps['menu_down'], key) >= 0
        win_execute(wid, 'norm! j')
        moved = 1
    elseif index(keymaps['menu_up'], key) >= 0
        win_execute(wid, 'norm! k')
        moved = 1
    elseif index(keymaps['menu_page_up'], key) >= 0
        win_execute(wid, "norm! \<c-b>")
        moved = 1
    elseif index(keymaps['menu_page_down'], key) >= 0
        win_execute(wid, "norm! \<c-f>")
        moved = 1
    elseif index(keymaps['menu_scroll_up'], key) >= 0
        win_execute(wid, "norm! \<c-u>")
        moved = 1
    elseif index(keymaps['menu_scroll_down'], key) >= 0
        win_execute(wid, "norm! \<c-d>")
        moved = 1
    elseif index(keymaps['menu_shift_up'], key) >= 0
        win_execute(wid, "norm! 3k")
        moved = 1
    elseif index(keymaps['menu_shift_down'], key) >= 0
        win_execute(wid, "norm! 3j")
        moved = 1
    elseif key ==? "\<LeftMouse>"
        var pos = getmousepos()
        # if wincol > width, assume clicking in scrollbar
        if pos.winid != wid || pos.wincol > width
            return 0
        endif
        win_execute(wid, 'norm! ' .. pos.line .. 'G')
        moved = 1
    elseif key ==? "\<2-LeftMouse>"
        var pos = getmousepos()
        # if wincol > width, assume clicking in scrollbar
        if pos.winid != wid || pos.wincol > width
            return 0
        endif
        win_execute(wid, 'norm! ' .. pos.line .. 'G')
        if has_key(options, 'select_cb')
                && type(options.select_cb) == v:t_func
            InvokeAction(options.select_cb, wins.menu)
        endif
        popup_close(wid)
    elseif key ==? "\<ScrollWheelUp>"
        var pos = getmousepos()
        if pos.winid != wid
            return 0
        endif
        win_execute(wid, 'norm! 3k')
        moved = 1
    elseif key ==? "\<ScrollWheelDown>"
        var pos = getmousepos()
        if pos.winid != wid
            return 0
        endif
        win_execute(wid, "norm! 3j")
        moved = 1
    elseif index(keymaps['menu_select'], key) >= 0
        if has_key(options, 'select_cb')
                && type(options.select_cb) == v:t_func
            InvokeAction(options.select_cb, wins.menu)
        endif
        popup_close(wid)
    elseif index(keymaps['exit'], key) >= 0
        popup_close(wid)
    elseif has_key(options.actions, key) && type(options.actions[key]) == v:t_func
        InvokeAction(options.actions[key], wins.menu)
    else
        return 0
    endif

    if moved && !options.dropdown
        var minline = getwinvar(wins.menu, 'minline', 1)
        if line('.', wid) < minline
            win_execute(wid, 'norm! ' .. minline .. 'G')
        endif
        if line('.', wid) == cursorline
            moved = 0
        endif
    endif

    if moved
        HandleChange()
    endif
    return 1
enddef

def PreviewFilter(wid: number, key: string): number
    if index(keymaps['preview_page_up'], key) >= 0
        win_execute(wid, "norm! \<c-b>")
    elseif index(keymaps['preview_page_down'], key) >= 0
        win_execute(wid, "norm! \<c-f>")
    elseif index(keymaps['preview_scroll_up'], key) >= 0
        win_execute(wid, "norm! \<c-u>")
    elseif index(keymaps['preview_scroll_down'], key) >= 0
        win_execute(wid, "norm! \<c-d>")
    elseif index(keymaps['preview_shift_up'], key) >= 0
        win_execute(wid, "norm! 3k")
    elseif index(keymaps['preview_shift_down'], key) >= 0
        win_execute(wid, "norm! 3j")
    elseif key ==? "\<ScrollWheelUp>"
        var pos = getmousepos()
        if pos.winid != wid
            return 0
        endif
        win_execute(wid, "norm! 3\<c-y>")
    elseif key ==? "\<ScrollWheelDown>"
        var pos = getmousepos()
        if pos.winid != wid
            return 0
        endif
        win_execute(wid, "norm! 3\<c-e>")
    else
        return 0
    endif
    return 1
enddef

def NewPopup(args: dict<any>): number
    var width = get(args, 'width', 0.4)
    var height = get(args, 'height', 0.4)
    var xoffset = get(args, 'xoffset', 0.3)
    var yoffset = get(args, 'yoffset', 0.3)

    # Use current window size for positioning relatively positioned popups
    var columns = &columns
    var lines = &lines

    # Size and position
    var final_width = min([max([1, width >= 1 ? width : float2nr(columns * width)]), columns])
    var final_height = min([max([1, height >= 1 ? height : float2nr(lines * height)]), lines])

    var line = yoffset >= 1 ? yoffset : float2nr(yoffset * lines)
    var col = xoffset >= 1 ? xoffset : float2nr(xoffset * columns)

    # Managing the differences
    line = min([max([0, line]), lines - final_height])
    col = min([max([0, col]), columns - final_width])

    var opts = {
        line: line,
        col: col,
        minwidth: final_width,
        maxwidth: final_width,
        minheight: final_height,
        maxheight: final_height,
        scrollbar: false,
        padding: [0, 0, 0, 0],
        mapping: false,
        zindex: 1000,
        wrap: 0,
        cursorline: 0,
        callback: null_function,
        border: [1],
        borderchars: borderchars,
        borderhighlight: ['fuzzboxBorder'],
        highlight: 'fuzzboxNormal'
    }

    for key in ['filter', 'scrollbar', 'wrap', 'zindex', 'title', 'callback']
        if has_key(args, key)
            opts[key] = args[key]
        endif
    endfor

    var wid = popup_create('', opts)
    if has_key(args, 'cursorline') && args.cursorline
       # we don't use popup option 'cursorline' because it is buggy (some
       # colorscheme will make cursorline highlight disappear)
       setwinvar(wid, '&cursorline', 1)
       setwinvar(wid, '&cursorlineopt', 'line')
    endif

    var bufnr = winbufnr(wid)
    setbufvar(bufnr, '&modeline', 0)

    return wid
enddef

def MenuSetText(text_list: list<string>)
    if type(text_list) != v:t_list
        echoerr 'text must be a list'
    endif
    if winbufnr(wins.menu) == -1
        return
    endif
    var text = text_list
    var old_cursor_pos = line('$', wins.menu) - line('.', wins.menu)
    var textrows = popup_getpos(wins.menu).height - 2

    if !options.dropdown
        var len_text = len(text_list)
        setwinvar(wins.menu, 'minline', textrows - len_text + 1)
        text = reverse(text_list)
        if len_text < textrows
            text = repeat([''], textrows - len_text) + text
        endif
    endif

    if popup_getoptions(wins.menu).scrollbar
        if !getwinvar(wins.menu, 'noscrollbar_width')
            setwinvar(wins.menu, 'noscrollbar_width', popup_getoptions(wins.menu).maxwidth)
        endif
        var curwidth = popup_getpos(wins.menu).width
        var noscrollbar_width = getwinvar(wins.menu, 'noscrollbar_width')
        if len(text) > textrows && curwidth != noscrollbar_width - 1
            var width = noscrollbar_width - 1
           popup_move(wins.menu, {minwidth: width, maxwidth: width})
        elseif len(text) <= textrows && curwidth != noscrollbar_width
            var width = noscrollbar_width
            popup_move(wins.menu, {minwidth: width, maxwidth: width})
        endif
    endif

    popup_settext(wins.menu, text)
    if !options.dropdown
        var new_line_length = line('$', wins.menu)
        var new_cursor_pos = new_line_length - old_cursor_pos
        win_execute(wins.menu, 'normal! ' .. new_line_length .. 'zb')
        win_execute(wins.menu, 'normal! ' .. new_cursor_pos .. 'G')
    endif

    # Delay triggering content changed callback to allow selectors to move the
    # cursorline after starting, see jumps and quickfix selectors for examples.
    # Without this the selection sign would not be moved to the new cursorline
    timer_start(10, (_) => {
        if active # allow for popups to have closed when lambda is invoked
            HandleChange()
        endif
    }, { repeat: 0 })
enddef

# Set Highlight for menu window
# params:
#   - hi_list: list of position to highlight eg. [[1,2,3], [1,5]]
def MenuSetHl(hl_list_raw: list<any>)
    if winbufnr(wins.menu) == -1
        return
    endif
    clearmatches(wins.menu)
    # pass empty list to matchaddpos will cause error
    if len(hl_list_raw) == 0
        return
    endif
    var hl_list = hl_list_raw

    # in case of reverse menu, we need to reverse the hl_list
    var textrows = popup_getpos(wins.menu).height - 2
    var height = max([hl_list_raw[-1][0], textrows])
    if !options.dropdown
        hl_list = reduce(hl_list_raw, (acc, v) => add(acc, [height - v[0] + 1] + v[1 :]), [])
    endif

    if !has('patch-9.0.0622')
        # matchaddpos() has maximum limit of 8 positions prior to patch 9.0.0620
        # patch 9.0.0622 then fixed some performance issues with many matches
        var idx = 0
        while idx < len(hl_list)
            matchaddpos('fuzzboxMatching', hl_list[idx : idx + 7 ], 99, -1,  {window: wins.menu})
            idx += 8
        endwhile
        return
    endif

    matchaddpos('fuzzboxMatching', hl_list, 99, -1,  {window: wins.menu})
enddef

def PopupPrompt(args: dict<any>): number
    if hlget('fuzzboxCursor')->get(0, {})->get('linksto', '') ==? 'Cursor'
        ResolveCursor()
    endif

    var opts = {
        width: 0.4,
        height: 1,
        filter: function('PromptFilter')
    }
    opts = extend(opts, args)
    var wid = NewPopup(opts)
    cursor_pos = 0
    popup_settext(wid, options.prompt_prefix .. " ")

    if has_key(args, 'title') && !empty(args.title)
        SetTitle(wid, args.title)
    endif

    # set cursor
    cursor_mid = matchaddpos('fuzzboxCursor',
        [[1, len(options.prompt_prefix) + 1 + cursor_pos]], 10, -1,  {window: wid})

    if has_key(args, 'text') && !empty(args.text)
        for i in range(strchars(args.text))
            PromptFilter(wid, strcharpart(args.text, i, 1, 1))
        endfor
    endif

    return wid
enddef

export def SetTitle(wid: number, str: string)
    # Preview title cannot be changed unless dynamic preview titles are allowed
    # An update can be forced by using popup_setoptions() to clear the title first
    if wid == wins.preview && !dynamic_preview_title
            && !empty(popup_getoptions(wid).title)
        return
    endif
    if empty(str)
        popup_setoptions(wid, {title: ''})
        return
    endif
    # var title = substitute(prompt_prefix, '\m.', borderchars[0], 'g') .. args.title
    var title = ' ' .. str .. ' '
    var padding = ( popup_getoptions(wid).maxwidth / 2 ) - ( len(title) / 2 )
    title = repeat([borderchars[0]], padding)->join('') .. title
    popup_setoptions(wid, {title: title})
enddef

export def SetCounter(count: any, total: any = null, isloading: bool = false)
    # this can happen with async callbacks
    if wins.prompt == -1
        return
    endif
    # ability to align virtual text only added in Vim 9.0.0121
    if !has('patch-9.0.0121')
        return
    endif
    var hlgroup: string
    if isloading
        hlgroup = 'fuzzboxLoading'
    else
        hlgroup = 'fuzzboxCounter'
        timer_stop(loading_tid)
    endif
    var bufnr = winbufnr(wins.prompt)
    var type = 'FuzzboxCounter'
    var prop = prop_type_get(type)
    if empty(prop)
        prop_type_add(type, {'highlight': hlgroup})
    elseif prop.highlight != hlgroup
        prop_type_change(type, {'highlight': hlgroup})
    endif
    var text: string
    if type(count) == v:t_none
        text = ''
    elseif type(count) == v:t_string
        text = count
    elseif empty(total)
        text = type(count) == v:t_string ? count : string(count)
    else
        text = string(count) .. ' / ' .. string(total)
    endif
    prop_remove({all: true, type: type, bufnr: bufnr}, 1)
    prop_add(1, 0, {
        bufnr: bufnr,
        type: type,
        text: text .. ' ',
        text_align: 'right'
    })
enddef

export def SetLoading()
    timer_stop(loading_tid)
    var loading_idx = 0
    loading_tid = timer_start(100, (_) => {
        SetCounter(loadingchars[loading_idx], null, true)
        if loading_idx == len(loadingchars) - 1
            loading_idx = 0
        else
            loading_idx += 1
        endif
    }, { repeat: -1 })
enddef

def PopupMenu(args: dict<any>): number
    var opts = {
        width: 0.4,
        height: 17,
        yoffset: 0.3,
        cursorline: 1,
        filter: function('MenuFilter'),
        callback: function('MenuCallback')
    }

    opts = extend(opts, args)
    var wid = NewPopup(opts)

    if has_key(args, 'title') && !empty(args.title)
        SetTitle(wid, args.title)
    endif

    if !empty(selection_sign)
        setwinvar(wid, '&signcolumn', 'yes')
        if exists('&winhighlight')
            setwinvar(wid, '&winhighlight', 'SignColumn:fuzzboxNormal,Normal:fuzzboxNormal')
        endif
    endif

    return wid
enddef

def PopupPreview(args: dict<any>): number
    var opts = {
        width: 0.4,
        height: 19,
        yoffset: 0.3,
        cursorline: 1,
        filter: function('PreviewFilter'),
    }

    opts = extend(opts, args)
    var wid = NewPopup(opts)

    if has_key(args, 'title') && !empty(args.title)
        SetTitle(wid, args.title)
    else
        # hack to respect g:dynamic_preview_title - setting the title to some
        # value here prevents it being changed by calls to SetTitle() later
        popup_setoptions(wid, {title: borderchars[0]})
    endif

    setwinvar(wid, '&number', 1)
    return wid
enddef

def GetOptions(opts: dict<any>): dict<any>
    var preview = has_key(opts, 'preview') ? opts.preview : true
    var compact = has_key(opts, 'compact') ? opts.compact : false
    var minwidth = has_key(opts, 'minwidth')
        && type(opts.minwidth) == v:t_float ? opts.minwidth : 0.5
    var maxwidth = has_key(opts, 'maxwidth')
        && type(opts.maxwidth) == v:t_float ? opts.maxwidth : 0.8
    var minheight = has_key(opts, 'minheight')
        && type(opts.minheight) == v:t_float ? opts.minheight : 0.5
    var maxheight = has_key(opts, 'maxheight')
        && type(opts.maxheight) == v:t_float ? opts.maxheight : 0.8
    var width: any = preview ? maxwidth : minwidth
    var height: any = preview ? maxwidth : minheight
    width = has_key(opts, 'width') ? opts.width : width
    height = has_key(opts, 'height') ? opts.height : height
    width = width > &columns ? &columns : width
    height = height > &lines ? &lines : height
    if preview_cutoff > &columns
        preview = false
    endif
    if compact_after < &columns
        compact = true
    endif
    if compact
        width = type(width) == v:t_float ? width - 0.1 : width
        height = type(height) == v:t_float ? height - 0.1 : height
    endif

    var preview_ratio = 0.5
    preview_ratio = has_key(opts, 'preview_ratio') && opts.preview_ratio > 0 &&
        opts.preview_ratio < 1 ? opts.preview_ratio : preview_ratio

    # total width and height including borderchars
    height = height < 1 ? float2nr(height * &lines) : float2nr(height)
    width = width < 1 ? float2nr(width * &columns) : float2nr(width)

    # deduct borderchars from total width and height before calculating offsets
    width = width - 2
    height = height - 2

    if preview
        width = width - 2 # additional borderchars
    endif

    var xoffset = width < 1 ? (1 - width) / 2 : (&columns - width) / 2
    var yoffset = height < 1 ? (1 - height) / 2 : (&lines - height) / 2
    xoffset = has_key(opts, 'xoffset') && opts.xoffset > 0 ? opts.xoffset : xoffset
    yoffset = has_key(opts, 'yoffset') && opts.yoffset > 0 ? opts.yoffset : yoffset
    yoffset = yoffset < 1 ? float2nr(yoffset * &lines) : float2nr(yoffset)
    xoffset = xoffset < 1 ? float2nr(xoffset * &columns) : float2nr(xoffset)

    return {
        preview: preview,
        preview_ratio: preview_ratio,
        minwidth: minwidth,
        maxwidth: maxwidth,
        minheight: minheight,
        maxheight: maxheight,
        width: width,
        height: height,
        xoffset: xoffset,
        yoffset: yoffset,
        compact: compact,
        actions: has_key(opts, 'actions') ? opts.actions : {},
        devicons: has_key(opts, 'devicons') && opts.devicons && devicons.Enabled(),
        dropdown: has_key(opts, 'dropdown') && opts.dropdown,
        scrollbar: has_key(opts, 'scrollbar') && opts.scrollbar,
        menu_title: has_key(opts, 'menu_title') ? opts.menu_title : '',
        menu_wrap: has_key(opts, 'menu_wrap') ? opts.menu_wrap : false,
        prompt_title: has_key(opts, 'prompt_title') ? opts.prompt_title : '',
        prompt_prefix: has_key(opts, 'prompt_prefix') ? opts.prompt_prefix : '',
        prompt_text: has_key(opts, 'prompt_text') ? opts.prompt_text : '',
        preview_title: has_key(opts, 'preview_title') ? opts.preview_title : '',
        preview_wrap: has_key(opts, 'preview_wrap') ? opts.preview_wrap : true,
    }
enddef

# params:
#   - opts: dict of options, including the following callbacks
#       - select_cb: function called when a result is selected
#       - change_cb: function called when cursor moves in the menu
#       - input_cb: function called when user inputs into prompt
#       - close_cb: function called when all windows are closed
#       - preview_cb: function called to preview a selection
# return:
#   A dictionary of window ids:
#    {
#       menu: menu_wid,
#       prompt: prompt_wid,
#       preview: preview_wid,
#    }
export def Start(opts: dict<any>): dict<any>
    if active
        return { menu: -1, prompt: -1, preview: -1 }
    endif
    active = true

    if exists('#User#FuzzboxOpening')
        doautocmd <nomodeline> User FuzzboxOpening
    endif

    options = extendnew(opts, GetOptions(opts))

    var preview_width = 0
    var menu_width = 0
    if options.preview
        preview_width = float2nr(options.width * options.preview_ratio)
        menu_width = options.width - preview_width
    else
        menu_width = options.width
    endif

    var prompt_height = 3 # 1 row of text plus borderchars
    var menu_height = options.height - prompt_height

    var prompt_yoffset: number
    var menu_yoffset: number

    if options.dropdown
        prompt_yoffset = options.yoffset
        menu_yoffset = options.yoffset + prompt_height
    else
        menu_yoffset = options.yoffset
        prompt_yoffset = options.yoffset + menu_height + 2
    endif

    var menu_opts = {
        scrollbar: options.scrollbar,
        yoffset: menu_yoffset,
        xoffset: options.xoffset,
        width: menu_width,
        height: menu_height,
        zindex: 1200,
        title: options.menu_title,
        wrap: options.menu_wrap
    }
    wins.menu = PopupMenu(menu_opts)

    var prompt_opts = {
        yoffset: prompt_yoffset,
        xoffset: options.xoffset,
        width: menu_width,
        zindex: 1010,
        title: options.prompt_title,
        prefix: options.prompt_prefix,
        text: options.prompt_text
    }
    wins.prompt = PopupPrompt(prompt_opts)

    if options.preview
        var preview_xoffset = popup_getoptions(wins.menu).col + popup_getoptions(wins.menu).maxwidth
        prompt_height = popup_getoptions(wins.prompt).maxheight
        var preview_height = menu_height + prompt_height + 2
        var preview_opts = {
            width: preview_width,
            height: preview_height,
            yoffset: options.yoffset,
            xoffset: preview_xoffset + 2,
            zindex: 1100,
            title: options.preview_title,
            wrap: options.preview_wrap
        }
        wins.preview = PopupPreview(preview_opts)
    endif

    HideCursor()

    if exists('#User#FuzzboxOpened')
        doautocmd <nomodeline> User FuzzboxOpened
    endif

    return wins
enddef
