vim9script

# Run test using source command, e.g.
#
#       :source %

import autoload 'fuzzbox/internal/inspect.vim'

def Test(label: string, actual: any, expected: any)
  assert_equal(expected, actual)
  if empty(v:errors)
    echo $'PASS  {label}'
  else
    echo $'FAIL  {label}: {v:errors[0]}'
  endif
  v:errors = []
enddef

def NoArgs(): void
enddef
def OneArg(n: number): void
enddef
def TwoArgs(n: number, s: string): bool
  return true
enddef
def WithList(l: list<string>, n: number): void
enddef
def WithDict(d: dict<string>, n: number): void
enddef
def WithNestedList(l: list<dict<string>>, n: number): void
enddef
def WithCallback(Cb: func(number, string): bool, s: string): void
enddef

Test('no args', inspect.Signature(NoArgs), [])
Test('one arg', inspect.Signature(OneArg), ['number'])
Test('two args', inspect.Signature(TwoArgs), ['number', 'string'])
Test('list arg', inspect.Signature(WithList), ['list<string>', 'number'])
Test('dict arg', inspect.Signature(WithDict), ['dict<string>', 'number'])
Test('nested list arg', inspect.Signature(WithNestedList), ['list<dict<string>>', 'number'])
Test('callback arg', inspect.Signature(WithCallback), ['func(number, string): bool', 'string'])
