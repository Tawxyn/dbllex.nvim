" Vim indent file
" Language:     Synergy DBL
" Filetype:     synergydbl
"
" Conservative by design. The indent expression returns -1 ("leave this line
" alone") for anything it cannot derive from block structure, so `=` and `o`
" never invent an answer. Set g:synergydbl_no_indent = 1 to skip this file
" entirely. See README.md, "Indentation".

if exists('b:did_indent')
  finish
endif

if get(g:, 'synergydbl_no_indent', 0)
  finish
endif

let b:did_indent = 1

setlocal indentexpr=synergydbl#GetIndent()

" Only the structural words are triggers. Nothing here reindents on ordinary
" punctuation, so typing normal code never causes a surprise reindent.
setlocal indentkeys=!^F,o,O
setlocal indentkeys+==~end,=~endrecord,=~endgroup,=~endstructure,=~endliteral
setlocal indentkeys+==~endenum,=~endclass,=~endinterface,=~endnamespace
setlocal indentkeys+==~endmethod,=~endglobal,=~endmain,=~endcase,=~endusing,=~endtry
setlocal indentkeys+==~else,=~catch,=~begin,=~proc,=~until

let b:undo_indent = 'setlocal indentexpr< indentkeys< | unlet! b:did_indent'
