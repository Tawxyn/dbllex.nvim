-- Filetype plugin for Synergy DBL.
--
-- Everything here is buffer-local. No global options, no mappings, no
-- autocommands. b:undo_ftplugin restores the buffer if the filetype changes.

if vim.b.did_ftplugin then
  return
end
vim.b.did_ftplugin = true

local bo = vim.bo
local opt_local = vim.opt_local

-- ';' is the only DBL comment introducer.
bo.commentstring = "; %s"

-- Longest prefix first, so pressing `o` on a ';;;' banner line continues with
-- ';;;' rather than a bare ';'.
bo.comments = ":;;;,:;;,:;"

-- Continue comments with <Enter>/o/O and allow `gq`, but never auto-wrap plain
-- code lines - DBL statements continue with a '&' line, which reflowing would
-- break.
opt_local.formatoptions:remove("t")
opt_local.formatoptions:append("croql")

-- Treat '%' as part of a word so `%sample_open` is a single keyword for w/b, `*`,
-- and :Inspect. '^' is deliberately NOT added: making ^NULL one word costs more
-- in everyday word motions than it buys.
opt_local.iskeyword:append("%")

-- Include navigation with `gf` and `[i`, for example .include "example.def".
bo.suffixesadd = ".dbl,.def,.dbh"
bo.include = [==[^\s*\.include\s\+["']]==]

-- Indentation defaults, applied only when the buffer still carries Neovim's
-- own defaults (sw=8, sts=0, noexpandtab). If the user has expressed any
-- preference - globally or via an editorconfig/modeline that already ran - it
-- is left alone. Set g:synergydbl_set_indent_defaults = false to opt out
-- entirely.
--
-- 'tabstop' is intentionally left at 8 so that hard-tab sources render the same
-- width the compiler and other editors see.
if vim.g.synergydbl_set_indent_defaults ~= false then
  if bo.shiftwidth == 8 and bo.softtabstop == 0 and bo.expandtab == false then
    bo.shiftwidth = 4
    bo.softtabstop = 4
    bo.expandtab = true
  end
end

-- matchit: only pairs that can be recognised reliably from a single line.
-- `if`/`else` is excluded on purpose - a DBL `if` with no `begin` has no
-- closing token, so % would jump to the wrong place as often as the right one.
-- \<end\> cannot match inside `endrecord` (no word boundary), so the plain
-- begin/end pair is safe alongside the more specific ones.
vim.b.match_ignorecase = 1
vim.b.match_words = table.concat({
  [[\<begin\>:\<end\>]],
  [[\<record\>:\<endrecord\>]],
  [[\<group\>:\<endgroup\>]],
  [[\<structure\>:\<endstructure\>]],
  [[\<literal\>:\<endliteral\>]],
  [[\<enum\>:\<endenum\>]],
  [[\<class\>:\<endclass\>]],
  [[\<interface\>:\<endinterface\>]],
  [[\<namespace\>:\<endnamespace\>]],
  [[\<method\>:\<endmethod\>]],
  [[\<global\>:\<endglobal\>]],
  [[\<main\>:\<endmain\>]],
  [[\<case\>:\<endcase\>]],
  [[\<using\>:\<endusing\>]],
  [[\<try\>:\<catch\>:\<endtry\>]],
  [[\.ifdef\>\|\.ifndef\>\|\.if\>:\.else\>:\.endc\>]],
  [[\.region\>:\.endregion\>]],
}, ",")

vim.b.undo_ftplugin = table.concat({
  "setlocal commentstring< comments< formatoptions< iskeyword<",
  "setlocal suffixesadd< include<",
  "setlocal shiftwidth< softtabstop< expandtab<",
  "unlet! b:match_words b:match_ignorecase b:did_ftplugin",
}, " | ")
