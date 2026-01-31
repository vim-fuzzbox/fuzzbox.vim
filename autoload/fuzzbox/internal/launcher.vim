vim9script

import autoload './popup.vim'
import autoload './helpers.vim'

var window_opts: dict<any>
if exists('g:fuzzbox_window_options') && type(g:fuzzbox_window_options) == v:t_dict
    extend(window_opts, g:fuzzbox_window_options)
elseif exists('g:fuzzbox_window_layout') && type(g:fuzzbox_window_layout) == v:t_dict
    # backwards compatibilty with old option name
    extend(window_opts, g:fuzzbox_window_layout)
endif

export def Start(selector: string, opts: dict<any> = {})
    if !exists('g:__fuzzbox_launcher_cache')
        g:__fuzzbox_launcher_cache = []
    endif
    var merged_opts = extendnew(get(window_opts, selector, {}), opts)
    insert(g:__fuzzbox_launcher_cache, { selector: selector, opts: merged_opts, prompt: '' })
    if filereadable(expand('<script>:p:h') .. '/../builtin/' .. selector .. '.vim')
        function('fuzzbox#builtin#' .. selector .. '#Start')(merged_opts)
    else
        function('fuzzbox#_extensions#' .. selector .. '#Start')(merged_opts)
    endif

    if exists('g:__fuzzbox_warnings_found') && g:__fuzzbox_warnings_found
        helpers.Warn('Fuzzbox started with warnings, use :FuzzyShowWarnings command to see details')
    endif
enddef

export def Resume()
    if !exists('g:__fuzzbox_launcher_cache') || empty(g:__fuzzbox_launcher_cache)
        helpers.Warn('fuzzbox: no previous search to resume')
        return
    endif
    for e in g:__fuzzbox_launcher_cache
        if !empty(e.prompt)
            if filereadable(expand('<script>:p:h') .. '/../builtin/' .. e.selector .. '.vim')
                function('fuzzbox#builtin#' .. e.selector .. '#Start')(e.opts)
            else
                function('fuzzbox#_extensions#' .. e.selector .. '#Start')(e.opts)
            endif
            if popup.GetPrompt() != e.prompt
                popup.SetPrompt(e.prompt)
            endif
            # trim cache, only save latest with prompt
            g:__fuzzbox_launcher_cache = [e]
            return
        endif
    endfor
    # clear cache, no items in cache have saved prompt, so cannot be resumed
    g:__fuzzbox_launcher_cache = []
    helpers.Warn('fuzzbox: no previous search to resume')
enddef

export def Save(wins: dict<any>)
    if !exists('g:__fuzzbox_launcher_cache') || empty(g:__fuzzbox_launcher_cache)
        return
    endif
    try
        var prompt_str = popup.GetPrompt()
        if !empty(prompt_str)
            g:__fuzzbox_launcher_cache[0].prompt = prompt_str
        elseif empty(g:__fuzzbox_launcher_cache[0].prompt)
            # remove from cache when no prompt to save, cannot be resumed
            remove(g:__fuzzbox_launcher_cache, 0)
        endif
    catch
        helpers.Warn('fuzzbox: ' .. v:exception .. ' at ' .. v:throwpoint)
    endtry
enddef
