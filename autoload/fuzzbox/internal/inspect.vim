vim9script

# Returns the argument types of a funcref as a list of strings, derived from
# typename(). A naive split(', ') breaks on nested func types like
# func(number): bool used as an argument type — this tracks () nesting depth
# and only splits at commas when depth == 0.
export def Signature(Func: func): list<string>
  var sig = typename(Func)
  if sig !~# '^func('
    return []
  endif

  # Find the closing ')' of the outermost arg list
  var depth = 0
  var args_end = -1
  for i in range(4, len(sig) - 1)
    var ch = sig[i]
    if ch == '('
      depth += 1
    elseif ch == ')'
      depth -= 1
      if depth == 0
        args_end = i
        break
      endif
    endif
  endfor

  var args_str = sig[5 : args_end - 1]
  if empty(args_str)
    return []
  endif

  var args: list<string> = []
  var current = ''
  depth = 0
  for ch in args_str
    if ch == '('
      depth += 1
      current ..= ch
    elseif ch == ')'
      depth -= 1
      current ..= ch
    elseif ch == ',' && depth == 0
      args->add(trim(current))
      current = ''
    else
      current ..= ch
    endif
  endfor
  if !empty(trim(current))
    args->add(trim(current))
  endif

  return args
enddef
