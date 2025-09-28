vim9script

import autoload './popup.vim'
import autoload './helpers.vim'

export def Start(selector: string, opts: dict<any> = {})
    if !exists('g:__fuzzbox_launcher_cache')
        g:__fuzzbox_launcher_cache = []
    endif
    insert(g:__fuzzbox_launcher_cache, { selector: selector, opts: opts, prompt: '' })
    try
        function('fuzzbox#builtin#' .. selector .. '#Start')(opts)
    catch /\v:(E700|E117):/
        function('fuzzbox#_extensions#' .. selector .. '#Start')(opts)
    endtry

    if exists('g:__fuzzbox_warnings_found') && g:__fuzzbox_warnings_found
        echohl WarningMsg
        echo 'Fuzzbox started with warnings, use :FuzzyShowWarnings command to see details'
        echohl None
    endif
enddef

export def Resume()
    if !exists('g:__fuzzbox_launcher_cache') || empty(g:__fuzzbox_launcher_cache)
        helpers.Warn( 'fuzzbox: no previous search to resume')
        return
    endif
    for e in g:__fuzzbox_launcher_cache
        if !empty(e.prompt)
            try
                function('fuzzbox#builtin#' .. e.selector .. '#Start')(e.opts)
            catch /\v:(E700|E117):/
                function('fuzzbox#_extensions#' .. e.selector .. '#Start')(e.opts)
            endtry
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
