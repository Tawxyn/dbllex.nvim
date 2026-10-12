" Indent engine for the synergydbl filetype.
"
" Kept in autoload/ so no global function name is introduced. Loaded on first
" use by indent/synergydbl.vim.
"
" Guiding rule: return -1 whenever the answer cannot be proved from block
" structure. Leave uncertain indentation as the author wrote it.

let s:cpo_save = &cpo
set cpo&vim

" Declaration modifiers that may precede an OO block opener, e.g.
"   public method Reset, void
let s:mods = '\%(\%(public\|private\|protected\|internal\|static\|abstract'
      \ . '\|virtual\|override\|partial\|sealed\|readonly\)\s\+\)*'

" Openers for the enclosing-block walk.
"
" `if`, `else`, `for`, `while`, `foreach`, `do`, `repeat`, `try` and `catch`
" are handled as headers (see s:IsHeader). A following `begin` aligns with
" its header instead of introducing another indentation level.
"
" `.main`, `.proc`, `.subroutine` and `.function` double as hard barriers: a
" statement inside a routine always finds one, so the walk never has to cross
" a routine boundary.
" s:mods is zero-or-more, so the second branch also matches a bare `structure`,
" `enum` or `literal`.
let s:opener = '^\%(begin\|record\|group\|global\|main\|case\|using\|proc\)\>'
      \ . '\|^' . s:mods
      \ . '\%(class\|interface\|namespace\|method\|structure\|enum\|literal\)\>'
      \ . '\|^\.\%(main\|proc\|subroutine\|function\|method\|class\)\>'

" Closing word -> [opener pattern, closer pattern].
"
" Used two ways: to align a closer with its own opener, and to let the
" enclosing-block walk jump over a completed block in one step. Jumping is what
" makes the walk correct in the presence of implicitly closed constructs - a
" `proc` is closed by the routine's `endmethod`/`endmain`, and a `record` by
" either `endrecord` or `proc`, so no plain depth counter can model them.
let s:pairs = {
      \ 'end':          ['^begin\>',                   '^end\>'],
      \ 'endrecord':    ['^record\>',                  '^endrecord\>'],
      \ 'endgroup':     ['^group\>',                   '^endgroup\>'],
      \ 'endstructure': ['^' . s:mods . 'structure\>', '^endstructure\>'],
      \ 'endliteral':   ['^literal\>',                 '^endliteral\>'],
      \ 'endenum':      ['^' . s:mods . 'enum\>',      '^endenum\>'],
      \ 'endclass':     ['^' . s:mods . 'class\>',     '^endclass\>'],
      \ 'endinterface': ['^' . s:mods . 'interface\>', '^endinterface\>'],
      \ 'endnamespace': ['^' . s:mods . 'namespace\>', '^endnamespace\>'],
      \ 'endmethod':    ['^' . s:mods . 'method\>',    '^endmethod\>'],
      \ 'endglobal':    ['^global\>',                  '^endglobal\>'],
      \ 'endmain':      ['^main\>',                    '^endmain\>'],
      \ 'endcase':      ['^case\>',                    '^endcase\>'],
      \ 'endusing':     ['^using\>',                   '^endusing\>'],
      \ 'endtry':       ['^try\>',                     '^endtry\>'],
      \ 'catch':        ['^try\>',                     '^endtry\>'],
      \ 'until':        ['^\%(do\|repeat\)\>',         '^until\>'],
      \ }

" Data-division openers. A routine may hold several in a row, none of them
" closed. Each aligns with the enclosing routine rather than nesting inside
" the preceding division.
let s:data_div = '^\%(record\|literal\|global\|common\)\>'

" Directives that always sit in column 0: a routine boundary.
let s:boundary = '^\.\%(main\|proc\|end\|subroutine\|function\|start\|entry\)\>'

" A label definition: identifier + comma, alone on the line, trailing comment
" allowed. Requiring end-of-line separates `done,` from a field such as
" `quantity, d4`.
let s:label = '^\s*\h\w*\s*,\s*\%(;.*\)\?$'

" Constructs that genuinely belong at the left margin when nothing encloses
" them. Anything else with no enclosing block is left where the author put it,
" because the buffer may be an .include fragment rather than a whole program: a
" fragment is often a routine body with no .proc of its own, and forcing its
" statements to column 0 would be wrong.
let s:top_level = '^\%(import\|main\|record\|global\|common\|literal\)\>'
      \ . '\|^' . s:mods . '\%(namespace\|class\|interface\|structure\|enum\)\>'

" Blocks whose members have exactly that same `name,` shape - an enum member is
" indistinguishable from a label on its own line. Inside one of these, such a
" line is a member and indents with its block instead of dropping to column 0.
let s:member_ctx = '^' . s:mods . '\%(enum\|structure\)\>'
      \ . '\|^\%(record\|group\|literal\|global\|common\)\>'

" Upper bound on how many lines a single indent decision may examine. Reached
" only by a malformed file; the caller then leaves the line alone rather than
" guessing, and `=G` over a large file stays responsive.
let s:budget_max = 500

" Return a:line with string literals and the trailing comment removed, then
" trimmed. Keeps `; end of loop` and "...begin..." from driving indentation.
"
" Scanned by hand rather than with a regex because DBL escapes a quote by
" doubling it ("" and ''), which a single substitute() cannot express.
function! s:Code(line) abort
  let l:out = ''
  let l:i = 0
  let l:n = strlen(a:line)
  while l:i < l:n
    let l:c = a:line[l:i]
    if l:c ==# ';'
      break
    elseif l:c ==# '"' || l:c ==# "'"
      let l:q = l:c
      let l:i += 1
      while l:i < l:n
        if a:line[l:i] ==# l:q
          " A doubled delimiter is an escaped delimiter, not the end.
          if l:i + 1 < l:n && a:line[l:i + 1] ==# l:q
            let l:i += 2
            continue
          endif
          let l:i += 1
          break
        endif
        let l:i += 1
      endwhile
      let l:out .= ' '
    else
      let l:out .= l:c
      let l:i += 1
    endif
  endwhile
  return substitute(l:out, '^\s\+\|\s\+$', '', 'g')
endfunction

" True for lines the walks must step over: blank, comment-only, or a '&'
" continuation of the statement above.
function! s:IsSkippable(lnum) abort
  let l:raw = getline(a:lnum)
  return l:raw =~# '^\s*$' || l:raw =~# '^\s*;' || l:raw =~# '^\s*&'
endfunction

" A "header" introduces a single dependent statement or an aligned `begin`,
" without being a block of its own.
"
" A parenthesised `if` must end at its condition, optionally followed by `then`.
" Balance the condition's parentheses so an inline call ending in `)` cannot
" look like a header. Non-parenthesised conditions require a trailing `then`.
" `onerror label` is a statement, not a header, and is absent by design.
function! s:IsHeader(code) abort
  let l:code = substitute(a:code, '\c^else\s\+\zeif\>', '', '')
  if l:code =~? '^if\>'
    let l:i = matchend(l:code, '\c^if\>\s*(')
    if l:i < 0
      return l:code =~? '\<then$'
    endif
    let l:depth = 1
    while l:i < strlen(l:code)
      if l:code[l:i] ==# '('
        let l:depth += 1
      elseif l:code[l:i] ==# ')'
        let l:depth -= 1
        if l:depth == 0
          return strpart(l:code, l:i + 1) =~? '^\s*\%(then\)\?\s*$'
        endif
      endif
      let l:i += 1
    endwhile
    return 0
  endif
  if a:code =~? '^else$'
    return 1
  endif
  if a:code =~? '^\%(for\|foreach\|while\)\>'
    return 1
  endif
  if a:code =~? '^\%(do\|repeat\|try\)$'
    return 1
  endif
  if a:code =~? '^catch\>'
    return 1
  endif
  return 0
endfunction

" First word of a line's code, lowercased; '' for a blank or comment-only line.
function! s:Word(lnum) abort
  return tolower(matchstr(s:Code(getline(a:lnum)), '^\a\w*'))
endfunction

" Line number of the opener matching the closer on a:from, 0 if unmatched,
" -1 if the budget ran out.
function! s:MatchingOpener(from, opener, closer) abort
  let l:depth = 0
  let l:lnum = a:from - 1
  while l:lnum > 0
    if s:budget <= 0
      return -1
    endif
    let s:budget -= 1
    if !s:IsSkippable(l:lnum)
      let l:code = s:Code(getline(l:lnum))
      if l:code =~? a:closer
        let l:depth += 1
      elseif l:code =~? a:opener
        if l:depth > 0
          let l:depth -= 1
        else
          return l:lnum
        endif
      endif
    endif
    let l:lnum -= 1
  endwhile
  return 0
endfunction

" Line number of the innermost opener still unclosed above a:from; 0 if the
" line is at top level, -1 if the budget ran out.
"
" A completed block is jumped over in one step via s:MatchingOpener rather than
" counted, which is what keeps an implicitly closed `proc` from swallowing the
" opener that really encloses the line.
" a:skip_data_div is set when the line being indented is itself a data-division
" opener, so a preceding unclosed division is stepped over instead of nested in.
function! s:EnclosingOpener(from, skip_data_div) abort
  let l:lnum = a:from
  while l:lnum > 0
    if s:budget <= 0
      return -1
    endif
    let s:budget -= 1
    if !s:IsSkippable(l:lnum)
      let l:code = s:Code(getline(l:lnum))
      let l:word = tolower(matchstr(l:code, '^\a\w*'))
      if has_key(s:pairs, l:word)
        let l:open = s:MatchingOpener(l:lnum, s:pairs[l:word][0], s:pairs[l:word][1])
        if l:open < 0
          return -1
        endif
        if l:open > 0
          " Skip the whole block: continue above its opener.
          let l:lnum = l:open
        endif
      elseif l:code =~? s:opener
        if !(a:skip_data_div && l:code =~? s:data_div)
          return l:lnum
        endif
      endif
    endif
    let l:lnum -= 1
  endwhile
  return 0
endfunction

" Find the `if` belonging to an `else`. Completed compound statements are
" skipped so an `if` inside a finished begin/end cannot capture the outer else.
" An `else if` both closes a branch and opens the next one at the same level.
function! s:MatchingIf(from) abort
  let l:depth = 0
  let l:lnum = a:from - 1
  while l:lnum > 0
    if s:budget <= 0
      return -1
    endif
    let s:budget -= 1
    if !s:IsSkippable(l:lnum)
      let l:code = s:Code(getline(l:lnum))
      let l:word = tolower(matchstr(l:code, '^\a\w*'))
      if l:code =~? '^else\s\+if\>'
        if l:depth == 0
          return l:lnum
        endif
      elseif l:word ==# 'else'
        let l:depth += 1
      elseif l:word ==# 'if'
        if l:depth == 0
          return l:lnum
        endif
        let l:depth -= 1
      elseif has_key(s:pairs, l:word)
        let l:open = s:MatchingOpener(l:lnum, s:pairs[l:word][0], s:pairs[l:word][1])
        if l:open <= 0
          return l:open
        endif
        let l:lnum = l:open
      elseif l:code =~? s:opener || l:code =~? s:boundary
        return 0
      endif
    endif
    let l:lnum -= 1
  endwhile
  return 0
endfunction

" Nearest line above a:lnum that is neither blank, comment-only, nor a
" continuation; 0 if there is none.
function! s:PrevMeaningful(lnum) abort
  let l:prev = a:lnum - 1
  while l:prev > 0
    if !s:IsSkippable(l:prev)
      return l:prev
    endif
    let l:prev -= 1
  endwhile
  return 0
endfunction

function! synergydbl#GetIndent() abort
  let l:raw = getline(v:lnum)

  " Comment-only lines keep their own indent, which preserves the `;---------`
  " banners that conventionally sit in column 0.
  if l:raw =~# '^\s*;'
    return -1
  endif

  " A continuation line only has to start with '&' as its first non-blank
  " character. Leave its indentation as the author wrote it.
  if l:raw =~# '^\s*&'
    return -1
  endif

  let l:code = s:Code(l:raw)

  " A routine boundary is always in column 0.
  if l:code =~? s:boundary
    return 0
  endif

  " Preserve the indentation of non-boundary directives.
  if l:code =~# '^\.'
    return -1
  endif

  let s:budget = s:budget_max

  " A label definition sits in column 0 - but only in a routine body. The same
  " `name,` shape inside an enum or a data division is a member, so it stays
  " with its block rather than being dragged to the margin.
  if l:raw =~# s:label
    let l:opener = s:EnclosingOpener(v:lnum - 1, 0)
    if l:opener < 0
      return -1
    endif
    if l:opener > 0 && s:Code(getline(l:opener)) =~? s:member_ctx
      return indent(l:opener) + shiftwidth()
    endif
    return 0
  endif

  let l:word = tolower(matchstr(l:code, '^\a\w*'))

  if l:word ==# 'else'
    let l:open = s:MatchingIf(v:lnum)
    return l:open > 0 ? indent(l:open) : -1
  endif

  " `proc` closes a data division and opens the routine body. It aligns with
  " whatever is innermost above it - the `record` in a traditional program, or
  " the `method`/`main` header in Synergy .NET - so it takes that opener's own
  " indent rather than one level in.
  if l:word ==# 'proc'
    let l:opener = s:EnclosingOpener(v:lnum - 1, 0)
    if l:opener < 0
      return -1
    endif
    return l:opener > 0 ? indent(l:opener) : 0
  endif

  " A closer aligns with its own opener.
  if has_key(s:pairs, l:word)
    let l:open = s:MatchingOpener(v:lnum, s:pairs[l:word][0], s:pairs[l:word][1])
    " Unmatched or unresolved: say nothing rather than something wrong.
    return l:open > 0 ? indent(l:open) : -1
  endif

  " One level inside the enclosing block.
  let l:opener = s:EnclosingOpener(v:lnum - 1, l:code =~? s:data_div)
  if l:opener < 0
    return -1
  endif
  if l:opener == 0
    return l:code =~? s:top_level ? 0 : -1
  endif
  let l:indent = indent(l:opener) + shiftwidth()

  " Use the header's own indent so chained single-statement conditions retain
  " every level. A `begin` aligns with its controlling header instead.
  let l:prev = s:PrevMeaningful(v:lnum)
  if l:prev > 0 && s:IsHeader(s:Code(getline(l:prev)))
    let l:indent = indent(l:prev) + (l:word ==# 'begin' ? 0 : shiftwidth())
  endif

  return l:indent
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
