vim9script

scriptencoding utf-8

import autoload './colors.vim'
import autoload './devicons.vim'
import autoload './launcher.vim'
import autoload './helpers.vim'

var popup_wins: dict<any>
var wins = { menu: -1, prompt: -1, preview: -1, info: -1 }
var popup_opts: dict<any>
var t_ve: string
var hlcursor: dict<any>
var has_devicons: bool
export var active = false

# user can register a custom action for any key
var actions: dict<any>

var keymaps: dict<any> = {
    'menu_up': ["\<C-p>", "\<Up>"],
    'menu_down': ["\<C-n>", "\<Down>"],
    'menu_select': ["\<CR>"],
    'menu_page_up': [],
    'menu_page_down': [],
    'menu_scroll_up': ["\<PageUp>"],
    'menu_scroll_down': ["\<PageDown>"],
    'menu_shift_up': ["\<S-Up>"],
    'menu_shift_down': ["\<S-Down>"],
    'preview_page_up': [],
    'preview_page_down': [],
    'preview_scroll_up': ["\<C-u>"], # :h CTRL-U
    'preview_scroll_down': ["\<C-d>"], # :h CTRL-D
    'cursor_begining': ["\<C-b>", "\<Home>"], # :h c_CTRL-B
    'cursor_end': ["\<C-e>", "\<End>"], # :h c_CTRL-E
    'cursor_word_left': ["\<C-Left>"], # :h c_<C-Left>
    'cursor_word_right': ["\<C-Right>"], # :h c_<C-Right>
    'backspace': ["\<C-h>", "\<BS>"], # :h c_CTRL-H
    'delete': ["\<Del>"], # :h c_<Del>
    'delete_all': [],
    'delete_word': ["\<C-w>"], # :h c_CTRL-W
    'delete_prefix': [],
    'exit': ["\<Esc>", "\<C-c>", "\<C-[>"], # :h c_<Esc>, :h c_CTRL-C
}
keymaps = exists('g:fuzzbox_keymaps') && type(g:fuzzbox_keymaps) == v:t_dict ?
    extend(keymaps, g:fuzzbox_keymaps) : keymaps

var borderchars = exists('g:fuzzbox_borderchars') &&
    type(g:fuzzbox_borderchars) == v:t_list &&
    len(g:fuzzbox_borderchars) == 8 ?
    g:fuzzbox_borderchars :
    ['─', '│', '─', '│', '╭', '╮', '╯', '╰']

export def SetPopupWinProp(wid: number, key: string, val: any)
    if has_key(popup_wins, wid) && has_key(popup_wins[wid], key)
        popup_wins[wid][key] = val
    else
        echoerr 'SetPopupWinProp: key not exist'
    endif
enddef

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
        helpers.Warn('Fuzzbox: failed to resolve cursor highlight: ' .. v:exception)
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

def InvokeAction(Action: func, wid: number = wins.menu)
    if Action == null # allow for null_function
        return
    endif
    var linetext = GetCursorItem()
    try
        try
            Action(wid, linetext, popup_opts)
        catch /\v:(E118):/
            try
                Action(wid, linetext)
            catch /\v:(E118):/
                # Experimental: don't rely on this within custom selectors
                try | Action(wid) | catch /\v:(E118):/ | Action() | endtry
            endtry
        endtry
    catch /\v:(E1013):/
        # backwards compat with old function signature, expected result as list
        # Handles "Argument 2: type mismatch, expected list<any> but got string"
        try
            Action(wid, [linetext], popup_opts)
        catch /\v:(E118):/
            Action(wid, [linetext])
        endtry
    endtry
enddef

# Called usually when popup window is closed
# It will only execute when menu window is closed
# params:
#   - wid: window id of the popup window
#   - select: the selected item in the popup window eg. ['selected str']
def GeneralPopupCallback(wid: number, select: any)
    if wid != wins.menu
        return
    endif
    launcher.Save(wins)
    for key in keys(wins)
        if len(getwininfo(wins[key])) > 0 && wins[key] != wid
            popup_close(wins[key])
        endif
        wins[key] = -1
    endfor

    # restore things to normal
    ShowCursor()
    active = false

    if has_key(popup_wins[wid], 'close_cb')
      && type(popup_wins[wid].close_cb) == v:t_func
        popup_wins[wid].close_cb(wid)
    endif

    # Clean up any running timers etc., see selector.vim
    doautocmd <nomodeline> User __FuzzboxCleanup

    popup_wins = {}

    silent doautocmd <nomodeline> User FuzzboxClosed
enddef

# Handle situation when Text under cursor in menu window is changed
var preview_tid: number
def MenuCursorContentChangeCb()
    if has_key(popup_wins[wins.menu], 'preview_cb')
        if type(popup_wins[wins.menu].preview_cb) == v:t_func
            # timer to avoid triggering preview unnecessarily during mouse scroll
            timer_stop(preview_tid)
            preview_tid = timer_start(30, (_) => {
                if active # allow for popups to have closed when lambda is invoked
                    InvokeAction(popup_wins[wins.menu].preview_cb, wins.preview)
                endif
            }, { repeat: 0 })
        endif
    endif
enddef

# set prompt content
# params
#   - content: string to be set as prompt
export def SetPrompt(content: string)
    if wins.prompt == -1
        return
    endif
    popup_wins[wins.prompt].prompt.line = []
    popup_wins[wins.prompt].cursor_args.cur_pos = 0
    for i in range(strchars(content))
        PromptFilter(wins.prompt, strcharpart(content, i, 1, 1))
    endfor
enddef

export def GetPrompt(): string
    if wins.prompt == -1
        return ''
    endif
    return popup_wins[wins.prompt].prompt.line->join('')
enddef

# get the line under the cursor in the menu window
export def GetCursorItem(): string
    var bufnr = popup_wins[wins.menu].bufnr
    var cursorlinepos = line('.', wins.menu)
    var linetext = getbufline(bufnr, cursorlinepos, cursorlinepos)[0]
    if has_devicons
        linetext = devicons.RemoveDevicon(linetext)
    endif
    return linetext
enddef

def PromptFilter(wid: number, key: string): number
    var bufnr = popup_wins[wid].bufnr
    var line = copy(popup_wins[wid].prompt.line)
    var cur_pos = popup_wins[wid].cursor_args.cur_pos # index by number of char not byte
    var max_pos = popup_wins[wid].cursor_args.max_pos
    var last_displayed_line = popup_wins[wid].prompt.displayed_line
    var ascii_val = char2nr(key)
    if (len(key) == 1 && ascii_val >= 32 && ascii_val <= 126)
        || (ascii_val >= 19968 && ascii_val <= 205743) # chinese or more character support
        if cur_pos == len(line)
            line->add(key)
        else
            var pre = cur_pos - 1 >= 0 ? line[: cur_pos - 1] : []
            line = pre + [key] + line[cur_pos :]
        endif
        cur_pos += 1
    elseif index(keymaps['backspace'], key) >= 0
        if cur_pos == len(line)
            line = line[: -2]
        else
            var before = cur_pos - 2 >= 0 ? line[: cur_pos - 2] : []
            line = before + line[cur_pos :]
        endif
        cur_pos = max([ 0, cur_pos - 1 ])
    elseif key == "\<Left>"
        cur_pos = max([ 0, cur_pos - 1 ])
    elseif key == "\<Right>"
        cur_pos = min([ max_pos, cur_pos + 1 ])
    elseif index(keymaps['delete'], key) >= 0
        if cur_pos == max_pos
            line = line[: -2]
            cur_pos -= 1
        elseif cur_pos == 0
            line = line[1 : ]
        else
            var before = cur_pos - 1 >= 0 ? line[: cur_pos - 1] : []
            line = before + line[cur_pos + 1 :]
        endif
        max_pos -= 1
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
        line = []
        cur_pos = 0
    elseif index(keymaps['delete_word'], key) >= 0
        while cur_pos > 0 && line[cur_pos - 1] == ' '
            remove(line, cur_pos - 1)
            cur_pos = cur_pos - 1
        endwhile
        while cur_pos > 0 && line[cur_pos - 1] != ' '
            remove(line, cur_pos - 1)
            cur_pos = cur_pos - 1
        endwhile
    elseif index(keymaps['delete_prefix'], key) >= 0
        line = line[cur_pos :]
        cur_pos = 0
    elseif key ==? "\<LeftMouse>" || key ==? "\<2-LeftMouse>"
        var pos = getmousepos()
        if pos.winid != wid
            return 0
        endif
        var prefix_len = popup_wins[wid].cursor_args.prefix_len
        cur_pos = pos.wincol - prefix_len - 2
        if cur_pos > max_pos
            cur_pos = max_pos
        endif
        if cur_pos < 0
            cur_pos = 0
        endif
    else
        # catch all unhandled keys
        return 1
    endif
    popup_wins[wid].cursor_args.cur_pos = cur_pos

    var line_str = join(line, '')
    if has_key(popup_wins[wid].prompt, 'input_cb') && popup_wins[wid].prompt.line != line
        var prompt = popup_wins[wid].prompt.prefix
        var displayed_line = prompt .. line_str .. " "
        popup_settext(wid, displayed_line)
        popup_wins[wid].prompt.displayed_line = displayed_line
        popup_wins[wid].prompt.line = line
        # after a keystroke, we need to update the menu popup to display
        # appropriate content and reset the cursor position
        if popup_wins[wid].dropdown
            win_execute(wins.menu, "silent! cursor(1, 1)")
        else
            win_execute(wins.menu, "silent! cursor('$', 1)")
        endif
        popup_wins[wid].prompt.input_cb(wid, line_str)
    endif

    popup_wins[wid].cursor_args.max_pos = len(line)
    var prefix_len = popup_wins[wid].cursor_args.prefix_len

    # cursor hl
    var hl = popup_wins[wid].cursor_args.highlight
    matchdelete(popup_wins[wid].cursor_args.mid, wid)
    var hi_end_pos = prefix_len + 1
    if cur_pos > 0
        hi_end_pos += len(join(line[: cur_pos - 1], ''))
    endif
    var mid = matchaddpos(hl, [[1, hi_end_pos]], 10, -1, {window: wid})
    popup_wins[wid].cursor_args.mid = mid
    return 1
enddef

def MenuFilter(wid: number, key: string): number
    var bufnr = popup_wins[wid].bufnr
    var width = popup_wins[wid].width
    var cursorlinepos = line('.', wid)
    var moved = 0
    if index(keymaps['menu_down'], key) >= 0
        win_execute(wid, 'norm! j')
        moved = 1
    elseif index(keymaps['menu_up'], key) >= 0
        moved = 1
        if popup_wins[wid].reverse_menu
            var textrows = popup_getpos(wid).height - 2
            var validrow = popup_wins[wid].validrow
            var minline = textrows - validrow + 1
            if cursorlinepos > minline
                win_execute(wid, 'norm! k')
                moved = 1
            endif
        else
            win_execute(wid, 'norm! k')
            moved = 1
        endif
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
        if has_key(popup_wins[wid], 'select_cb')
                && type(popup_wins[wid].select_cb) == v:t_func
            InvokeAction(popup_wins[wid].select_cb)
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
        if has_key(popup_wins[wid], 'select_cb')
                && type(popup_wins[wid].select_cb) == v:t_func
            InvokeAction(popup_wins[wid].select_cb)
        endif
        popup_close(wid)
    elseif index(keymaps['exit'], key) >= 0
        popup_close(wid)
    elseif has_key(actions, key) && type(actions[key]) == v:t_func
        InvokeAction(actions[key])
    else
        return 0
    endif

    if moved
        MenuCursorContentChangeCb()
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

def CreatePopup(args: dict<any>): number
    var opts = {
       line: args.line,
       col: args.col,
       minwidth: args.width,
       maxwidth: args.width,
       minheight: args.height,
       maxheight: args.height,
       scrollbar: false,
       padding: [0, 0, 0, 0],
       zindex: 1000,
       wrap: 0,
       cursorline: 0,
       callback: function('GeneralPopupCallback'),
       border: [1],
       borderchars: borderchars,
       borderhighlight: ['fuzzboxBorder'],
       highlight: 'fuzzboxNormal', }

    if &encoding != 'utf-8'
        remove(opts, 'borderchars')
    endif

    if has_key(args, 'enable_border') && !args.enable_border
        remove(opts, 'border')
    endif

    for key in ['filter', 'border', 'borderhighlight', 'highlight', 'borderchars',
    'scrollbar', 'padding', 'wrap', 'zindex', 'title']
        if has_key(args, key)
            opts[key] = args[key]
        endif
    endfor
    var noscrollbar_width = opts.minwidth
    if opts.scrollbar
        opts.minwidth -= 1
        opts.maxwidth -= 1
    endif

    if has_key(opts, 'filter')
        opts.mapping = false
    endif
    var wid = popup_create('', opts)
    if has_key(args, 'cursorline') && args.cursorline
       # we don't use popup option 'cursorline' because it is buggy (some
       # colorscheme will make cursorline highlight disappear)
       setwinvar(wid, '&cursorline', 1)
       setwinvar(wid, '&cursorlineopt', 'line')
    endif
    popup_wins[wid] = {
         highlights: {},
         noscrollbar_width: noscrollbar_width,
         validrow: 0,
         preview_cb: null,
         line: args.line,
         col: args.col,
         width: args.width,
         height: args.height,
         reverse_menu: 0,
         dropdown: 0,
         cursor_item: null,
         wid: wid,
         update_delay_timer: -1,
         prompt_delay_timer: -1,
         }

    for key in ['dropdown', 'reverse_menu', 'preview_cb', 'close_cb', 'select_cb']
        if has_key(args, key)
            popup_wins[wid][key] = args[key]
        endif
    endfor
    return wid
enddef

def NewPopup(args: dict<any>): list<number>
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

    var opts = extend(args, {
     line: line,
     col: col,
     width: final_width,
     height: final_height
     })

    var wid = CreatePopup(opts)
    var bufnr = winbufnr(wid)
    setbufvar(bufnr, '&modeline', 0)

    popup_wins[wid].bufnr = bufnr

    return [wid, bufnr]
enddef

export def MenuSetText(text_list: list<string>)
    if type(text_list) != v:t_list
        echoerr 'text must be a list'
    endif
    if !has_key(popup_wins, wins.menu)
        return
    endif
    var text = text_list
    var old_cursor_pos = line('$', wins.menu) - line('.', wins.menu)

    popup_wins[wins.menu].validrow = len(text_list)
    var textrows = popup_getpos(wins.menu).height - 2
    if popup_wins[wins.menu].reverse_menu
        text = reverse(text_list)
        if len(text) < textrows
            text = repeat([''], textrows - len(text)) + text
        endif
    endif

    if popup_getoptions(wins.menu).scrollbar
        var curwidth = popup_getpos(wins.menu).width
        var noscrollbar_width = popup_wins[wins.menu].noscrollbar_width
        if len(text) > textrows && curwidth != noscrollbar_width - 1
            var width = noscrollbar_width - 1
           popup_move(wins.menu, {minwidth: width, maxwidth: width})
        elseif len(text) <= textrows && curwidth != noscrollbar_width
            var width = noscrollbar_width
            popup_move(wins.menu, {minwidth: width, maxwidth: width})
        endif
    endif

    popup_settext(wins.menu, text)
    if popup_wins[wins.menu].reverse_menu
        var new_line_length = line('$', wins.menu)
        var cursor_pos = new_line_length - old_cursor_pos
        win_execute(wins.menu, 'normal! ' .. new_line_length .. 'zb')
        win_execute(wins.menu, 'normal! ' .. cursor_pos .. 'G')
    endif

    MenuCursorContentChangeCb()
enddef

# Set Highlight for menu window
# params:
#   - hi_list: list of position to highlight eg. [[1,2,3], [1,5]]
export def MenuSetHl(hl_list_raw: list<any>)
    if !has_key(popup_wins, wins.menu)
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
    if popup_wins[wins.menu].reverse_menu
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
    var [wid, bufnr] = NewPopup(opts)
    var prompt_prefix = has_key(args, 'prompt_prefix') ? args.prompt_prefix : '> '
    var prompt_prefix_len = strcharlen(prompt_prefix)
    var prompt_opt = {
     line: [],
     prefix: prompt_prefix,
     displayed_line: prompt_prefix .. " ",
     }

    var cursor_args = {
     min_pos: 0,
     max_pos: 0,
     prefix_len: prompt_prefix_len,
     cur_pos: 0,
     highlight: 'fuzzboxCursor',
     mid: -1,
     }

    popup_wins[wid].cursor_args = cursor_args
    popup_wins[wid].prompt = prompt_opt
    if has_key(args, 'input_cb') && type(args.input_cb) == v:t_func
        popup_wins[wid].prompt.input_cb = args.input_cb
    endif
    popup_settext(wid, prompt_opt.displayed_line)

    if has_key(args, 'title') && !empty(args.title)
        SetTitle(wid, args.title)
    endif

    # set cursor
    var mid = matchaddpos(cursor_args.highlight,
    [[1, prompt_prefix_len + 1 + cursor_args.cur_pos]], 10, -1,  {window: wid})
    popup_wins[wid].cursor_args.mid = mid
    return wid
enddef

export def SetTitle(wid: number, str: string)
    # var title = substitute(prompt_prefix, '\m.', borderchars[0], 'g') .. args.title
    var title = ' ' .. str .. ' '
    var padding = ( popup_getoptions(wid).maxwidth / 2 ) - ( len(title) / 2 )
    title = repeat([borderchars[0]], padding)->join('') .. title
    popup_setoptions(wid, {title: title})
enddef

export def SetCounter(count: any, total: any = null)
    # this can happen with async callbacks
    if wins.prompt == -1
        return
    endif
    var bufnr = popup_wins[wins.prompt].bufnr
    var type = 'FuzzboxCounter'
    var prop = prop_type_get(type)
    if empty(prop)
        prop_type_add(type, {'highlight': type})
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

def PopupMenu(args: dict<any>): number
    var opts = {
     width: 0.4,
     height: 17,
     yoffset: 0.3,
     cursorline: 1,
     filter: function('MenuFilter'),
     }

    opts = extend(opts, args)
    var [wid, bufnr] = NewPopup(opts)

    if has_key(args, 'title') && !empty(args.title)
        SetTitle(wid, args.title)
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
    var [wid, bufnr] = NewPopup(opts)

    setwinvar(wid, '&number', 1)
    return wid
enddef

# params:
#   - opts: options: dictonary contains following keys:
#       - select_cb: callback function when a value is selected(press enter)
#       - preview_cb: callback function when cursor moves to a new value
#       - input_cb: callback function when user input something
# return:
#   A dictionary:
#    {
#        menu: wins.menu,
#        prompt: wins.prompt,
#        preview: wins.preview,
#    }
export def PopupSelection(opts: dict<any>): dict<any>
    popup_opts = opts
    if active
        return { menu: -1, prompt: -1, preview: -1 }
    endif
    active = true
    actions = has_key(opts, 'actions') ? opts.actions : {}
    has_devicons = has_key(opts, 'devicons') ? opts.devicons && devicons.Enabled() : 0
    var has_preview = has_key(opts, 'preview') ? opts.preview : 1

    if has_key(opts, 'title') && !has_key(opts, 'prompt_title')
        opts.prompt_title = opts.title
    endif

    var width: any = has_preview ? 0.8 : 0.5
    var height: any = has_preview ? 0.8 : 0.5
    if has_key(opts, 'compact') && opts.compact
        width = width - 0.1
        height = height - 0.1
    endif
    width = has_key(opts, 'width') && opts.width > 0 ? opts.width : width
    height = has_key(opts, 'height') && opts.height > 0 ? opts.height : height

    var preview_ratio = 0.5
    preview_ratio = has_key(opts, 'preview_ratio') && opts.preview_ratio > 0 &&
        opts.preview_ratio < 1 ? opts.preview_ratio : preview_ratio

    var xoffset = width < 1 ? (1 - width) / 2 : (&columns  - width) / 2
    var yoffset = height < 1 ? (1 - height) / 2 : (&lines - height) / 2
    xoffset = has_key(opts, 'xoffset') && opts.xoffset > 0 ? opts.xoffset : xoffset
    yoffset = has_key(opts, 'yoffset') && opts.yoffset > 0 ? opts.yoffset : yoffset

    # convert all pos to number
    yoffset = yoffset < 1 ? float2nr(yoffset * &lines) : float2nr(yoffset)
    xoffset = xoffset < 1 ? float2nr(xoffset * &columns) : float2nr(xoffset)
    height = height < 1 ? float2nr(height * &lines) : float2nr(height)
    width = width < 1 ? float2nr(width * &columns) : float2nr(width)

    var preview_width = 0
    var menu_width = 0
    if has_preview
        preview_width = float2nr(width * preview_ratio)
        menu_width = width - preview_width
    else
        menu_width = width
    endif

    var dropdown = has_key(opts, 'dropdown') && opts.dropdown

    var prompt_height = 3
    var menu_height = height - prompt_height

    var prompt_yoffset: number
    var menu_yoffset: number
    var reverse_menu: number

    if dropdown
        prompt_yoffset = yoffset
        menu_yoffset = yoffset + prompt_height
        reverse_menu = 0
    else
        menu_yoffset = yoffset
        prompt_yoffset = yoffset + menu_height + 2
        reverse_menu = 1
    endif
    reverse_menu = has_key(opts, 'reverse_menu') ? opts.reverse_menu : reverse_menu

    var menu_opts = {
        select_cb: has_key(opts, 'select_cb') ? opts.select_cb : null,
        close_cb: has_key(opts, 'close_cb') ? opts.close_cb : null,
        preview_cb: has_key(opts, 'preview_cb') ? opts.preview_cb : null,
        scrollbar: has_key(opts, 'scrollbar') ? opts.scrollbar : 0,
        reverse_menu: reverse_menu,
        yoffset: menu_yoffset,
        xoffset: xoffset,
        width: menu_width,
        height: menu_height,
        zindex: 1200,
    }
    if has_key(opts, 'menu_title')
        menu_opts['title'] = opts.menu_title
    endif
    if has_key(opts, 'menu_wrap')
        menu_opts['wrap'] = opts.menu_wrap
    endif
    wins.menu = PopupMenu(menu_opts)

    var prompt_opts = {
        yoffset: prompt_yoffset,
        xoffset: xoffset,
        width: menu_width,
        dropdown: dropdown,
        input_cb: has_key(opts, 'input_cb') ? opts.input_cb : null,
        prompt: has_key(opts, 'prompt') ? opts.prompt : '> ',
        zindex: 1010,
    }
    if has_key(opts, 'prompt_title')
        prompt_opts['title'] = opts.prompt_title
    endif
    if has_key(opts, 'prompt_prefix')
        prompt_opts['prompt_prefix'] = opts.prompt_prefix
    endif
    wins.prompt = PopupPrompt(prompt_opts)

    if has_preview
        var preview_xoffset = popup_wins[wins.menu].col + popup_wins[wins.menu].width
        var menu_row = popup_wins[wins.menu].line
        var prompt_row = popup_wins[wins.prompt].line
        prompt_height = popup_wins[wins.prompt].height
        # var preview_height = prompt_row - menu_row + prompt_height
        var preview_height =  menu_height + prompt_height + 2
        var preview_opts = {
            width: preview_width,
            height: preview_height,
            yoffset: yoffset,
            xoffset: preview_xoffset + 2,
            zindex: 1100,
            wrap: 1
        }
        if has_key(opts, 'preview_wrap')
            preview_opts['wrap'] = opts.preview_wrap
        endif
        wins.preview = PopupPreview(preview_opts)
        wins.preview = wins.preview
        popup_wins[wins.preview].partids = wins
    endif

    if has_key(opts, 'infowin') && opts.infowin
        var info_bufnr: number
        [wins.info, info_bufnr] = NewPopup({
            width: menu_width - 1,
            height: 1,
            yoffset: yoffset + 1,
            xoffset: xoffset + 1,
            padding: [0, 0, 0, 1],
            zindex: 2000,
            enable_border: 0,
        })
        wins.info = wins.info
        popup_wins[wins.info].partids = wins
    endif

    popup_wins[wins.menu].partids = wins
    popup_wins[wins.prompt].partids = wins

    HideCursor()

    silent doautocmd <nomodeline> User FuzzboxOpened

    return wins
enddef
