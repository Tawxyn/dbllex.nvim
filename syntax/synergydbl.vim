" Vim syntax file
" Language:     Synergy DBL (traditional and Synergy .NET)
" Filetype:     synergydbl
"
" Lexical patterns for declarations, statements, and literals.

if exists('b:current_syntax')
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" DBL keywords and identifiers are case-insensitive.
syntax case ignore

" Pin the keyword character set used by `syn keyword` so it cannot drift with
" the ftplugin's 'iskeyword' (which adds '%'). This is the Vim default set.
" With '%' excluded here, `open` inside `%sample_open` still cannot match as a
" keyword, because it is preceded by '_', which IS a keyword character.
syntax iskeyword @,48-57,_,192-255

" ---------------------------------------------------------------------------
" Comments
" ---------------------------------------------------------------------------
" A semicolon starts a comment. ';;' and ';;;' are longer comment prefixes.
"
" Declared first and left uncontained on purpose. Vim scans a line left to
" right and matches at the earliest position where any item applies, so a
" comment starting at column 5 wins over a quote at column 30 and swallows the
" rest of the line. That is what makes prose apostrophes and quotes inside
" comments harmless.
syn keyword SynergyDblTodo contained TODO FIXME XXX HACK NOTE
syn match SynergyDblComment /;.*$/ contains=SynergyDblTodo

" ---------------------------------------------------------------------------
" String literals
" ---------------------------------------------------------------------------
" DBL escapes a delimiter by doubling it, hence skip=/""/ and skip=/''/.
" For example: greeting = "Say ""hello"" to 'guest'"
"
" 'oneline' is correct as well as defensive: DBL strings never span a physical
" line (continuation uses a separate '&' line), so an unbalanced quote can only
" mis-highlight the line it is on.
"
" A string starts before any semicolon inside it, so embedded punctuation
" stays in the string: greeting = "first; 'second'"
syn region SynergyDblString oneline start=/"/ skip=/""/ end=/"/
syn region SynergyDblString oneline start=/'/ skip=/''/ end=/'/

" ---------------------------------------------------------------------------
" Numeric literals
" ---------------------------------------------------------------------------
" The leading \< is what keeps this from firing inside a field specification:
" in `a256` the '2' is preceded by 'a', a word character, so \< fails there.
" In `[10]i4` the '1' follows '[', so 10 correctly reads as a number.
syn match SynergyDblNumber /\<\d\+\%(\.\d\+\)\?\>/

" ---------------------------------------------------------------------------
" Field specifications and declared types
" ---------------------------------------------------------------------------
" Traditional field specs are only meaningful in declaration position, so they
" must be recognised from the shape of the whole line, not from the letters
" alone - otherwise a variable called `d8` would be painted as a type.
"
" Shape:  [modifiers...] name , [[dim]] spec [, initializer...]
" Look behind from the spec itself. Matching a prefix with \zs would require
" the syntax engine to revisit text already claimed by `public` or a numeric
" dimension such as `[3]`, so those earlier highlights would hide the type.
let s:decl_prefix = '^\s*\%(\%(public\|private\|protected\|internal\|static'
      \ . '\|readonly\|abstract\|virtual\|override\|partial\|sealed\|global'
      \ . '\|common\|data\|stack\|local\|group\)\s\+\)*\h\w*\s*,\s*'

" Example declarations:
"   selected, d2, 7
"   title, a48
"   scores, [LIMIT]i4
"   scores, [4]i4
"   public entryCount, i4
"   public static entryCount, i4
"   group members, [LIMIT]a
"   ratio, d5.2
" The declaration prefix also keeps type-shaped initialiser names uncoloured.
" The trailing \%(,\|;\|$\) requires the spec to end the field or be followed by
" an initialiser or trailing comment.
execute 'syn match SynergyDblType /\%(' . s:decl_prefix
      \ . '\%(\[[^]]*\]\)\?\s*\)\@<=[adinp]\d*\%(\.\d\+\)\?\ze\s*\%(,\|;\|$\)/'

" Named scalar types, which appear in the same trailing position:
"   public method Reset, void
"   caption, string
" Anchored on ", <type>" at end of field so ordinary argument lists such as
" `%sample_value(left, right)` cannot match.
syn match SynergyDblType /,\s*\zs\%(boolean\|byte\|char\|decimal\|double\|float\|int\|long\|object\|sbyte\|short\|string\|uint\|ulong\|ushort\|void\)\>\ze\s*\%(,\|;\|$\)/

" Object-type prefix, for example @System.Exception.
syn match SynergyDblType /@\h[[:alnum:]_.]*/

" ---------------------------------------------------------------------------
" Compiler directives and conditional compilation
" ---------------------------------------------------------------------------
" Both are anchored to the start of the line, which is why a dotted operator
" such as `.not.` can never be mistaken for a directive.
"
" \> after each alternative keeps `.end` from claiming `.endc` (the following
" 'c' is a word character), so `.endc` falls through to the PreProc group.
syn match SynergyDblDirective /^\s*\zs\.\%(endclass\|subroutine\|namespace\|noproto\|nodebug\|include\|function\|nomain\|method\|nolist\|entry\|align\|class\|ident\|array\|proto\|start\|title\|main\|proc\|list\|name\|page\|end\)\>/

syn match SynergyDblPreProc /^\s*\zs\.\%(endregion\|undefine\|region\|ifndef\|ifdef\|define\|iftf\|else\|endc\|iff\|ift\|if\)\>/

" ---------------------------------------------------------------------------
" Operators
" ---------------------------------------------------------------------------
" Both delimiting dots are part of the match, so `.not.user` highlights the
" operator and leaves the operand alone. Only the dotted relational/logical
" forms are claimed; arithmetic punctuation is left unhighlighted, matching
" most shipped Vim syntax files.
syn match SynergyDblOperator /\.\%(eqs\|nes\|gts\|lts\|ges\|les\|bnot\|band\|bxor\|nand\|bor\|xor\|nor\|not\|and\|eq\|ne\|gt\|lt\|ge\|le\|or\)\./

" ---------------------------------------------------------------------------
" Statements and control flow
" ---------------------------------------------------------------------------
syn keyword SynergyDblKeyword if then else begin end
syn keyword SynergyDblKeyword for from thru while do until repeat foreach in
syn keyword SynergyDblKeyword case endcase using endusing select
syn keyword SynergyDblKeyword exitloop nextloop
syn keyword SynergyDblKeyword return stop exit nop offerror
syn keyword SynergyDblKeyword try catch endtry throw finally
syn keyword SynergyDblKeyword mreturn freturn xreturn
syn keyword SynergyDblKeyword new this clear incr decr sleep import

" `goto`/`call`/`onerror` take a label and `xcall` takes an external routine.
" nextgroup lets the target match after the keyword has already been consumed.
syn keyword SynergyDblKeyword goto call onerror skipwhite nextgroup=SynergyDblLabelRef
syn keyword SynergyDblKeyword xcall skipwhite nextgroup=SynergyDblCallTarget
syn match   SynergyDblLabelRef   contained /\h\w*/
syn match   SynergyDblCallTarget contained /\h\w*/

" I/O and record-handling statements.
syn keyword SynergyDblKeyword open close read reads write writes display accept
syn keyword SynergyDblKeyword store delete find get put lock unlock

" ---------------------------------------------------------------------------
" Declaration and routine structure
" ---------------------------------------------------------------------------
syn keyword SynergyDblStructure record endrecord group endgroup
syn keyword SynergyDblStructure structure endstructure literal endliteral
syn keyword SynergyDblStructure enum endenum interface endinterface
syn keyword SynergyDblStructure class endclass namespace endnamespace
syn keyword SynergyDblStructure method endmethod
syn keyword SynergyDblStructure main endmain proc data global endglobal common

syn keyword SynergyDblStorageClass public private protected static readonly
syn keyword SynergyDblStorageClass abstract virtual override partial sealed const

" ---------------------------------------------------------------------------
" Routines, intrinsics and call targets
" ---------------------------------------------------------------------------
" Match percent-prefixed routine names by shape.
syn match SynergyDblFunction /%\h\w*/

" Match caret-prefixed intrinsic names by shape.
syn match SynergyDblIntrinsic /\^\h\w*/

" ---------------------------------------------------------------------------
" Labels
" ---------------------------------------------------------------------------
" A label definition is an identifier followed by a comma, alone on the line
" (a trailing comment is allowed), for example `retry,` or `done,`.
" Requiring end-of-line is what separates a label from a record field such as
" `quantity, d4`. A label sharing its line with a statement is not matched.
syn match SynergyDblLabel /^\s*\zs\h\w*\ze,\s*\%(;.*\)\?$/

" ---------------------------------------------------------------------------
" I/O control clauses and line continuation
" ---------------------------------------------------------------------------
" Example: open(7, i, "sample.txt") [err=missing_file]
" The '=' is what distinguishes this from an array subscript such as [10] or
" [ix], so ordinary subscripts are left alone. The '=' is part of the match so
" that nextgroup lands on the target label.
syn match SynergyDblIoClause /\[\zs\h\w*\s*=/ skipwhite nextgroup=SynergyDblLabelRef

" A continuation line begins with '&' as its first non-blank character.
syn match SynergyDblContinuation /^\s*\zs&/

" No syntax item spans more than one line, so resynchronising a single line
" back is always sufficient and keeps large files fast.
syn sync minlines=1

" ---------------------------------------------------------------------------
" Default highlighting
" ---------------------------------------------------------------------------
" Default links let a colourscheme redefine any SynergyDbl* group.
hi def link SynergyDblComment       Comment
hi def link SynergyDblTodo          Todo
hi def link SynergyDblString        String
hi def link SynergyDblNumber        Number
hi def link SynergyDblKeyword       Statement
hi def link SynergyDblStructure     Structure
hi def link SynergyDblStorageClass  StorageClass
hi def link SynergyDblDirective     PreProc
hi def link SynergyDblPreProc       PreCondit
hi def link SynergyDblType          Type
hi def link SynergyDblFunction      Function
hi def link SynergyDblIntrinsic     Special
hi def link SynergyDblOperator      Operator
hi def link SynergyDblLabel         Label
hi def link SynergyDblContinuation  Special
hi def link SynergyDblIoClause      Special

" Chained on purpose: overriding SynergyDblLabel or SynergyDblFunction in a
" colourscheme also restyles these, while :Inspect still names the finer group.
hi def link SynergyDblLabelRef      SynergyDblLabel
hi def link SynergyDblCallTarget    SynergyDblFunction

let b:current_syntax = 'synergydbl'

let &cpo = s:cpo_save
unlet s:cpo_save
