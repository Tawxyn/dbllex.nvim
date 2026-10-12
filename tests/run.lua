-- Headless test suite for the synergydbl plugin.
--
--   nvim --headless --noplugin -u tests/minimal_init.lua -l tests/run.lua
--
-- Exits 0 when every check passes, 1 otherwise. No test framework, no
-- dependencies.

local root = vim.g.synergydbl_test_root
  or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local fixtures = root .. "/tests/fixtures"

-- ---------------------------------------------------------------------------
-- Tiny harness
-- ---------------------------------------------------------------------------
local passed, failures = 0, {}

local function ok(cond, name, detail)
  if cond then
    passed = passed + 1
    io.write("ok   - " .. name .. "\n")
  else
    failures[#failures + 1] = name
    io.write("FAIL - " .. name .. "\n")
    if detail then
      io.write("       " .. (tostring(detail):gsub("\n", "\n       ")) .. "\n")
    end
  end
end

local function eq(actual, expected, name)
  ok(actual == expected, name, string.format("expected %s, got %s",
    vim.inspect(expected), vim.inspect(actual)))
end

local function section(title)
  io.write("\n# " .. title .. "\n")
end

-- ---------------------------------------------------------------------------
-- Global state snapshot, taken before any DBL buffer exists
-- ---------------------------------------------------------------------------
local GLOBAL_OPTS = {
  "commentstring", "comments", "iskeyword", "suffixesadd", "include",
  "formatoptions", "shiftwidth", "softtabstop", "expandtab",
  "indentexpr", "indentkeys",
}

local function snapshot_globals()
  local snap = {}
  for _, name in ipairs(GLOBAL_OPTS) do
    snap[name] = vim.go[name]
  end
  snap["<maps>"] = vim.fn.execute("map") .. vim.fn.execute("map!")
  return snap
end

local before = snapshot_globals()

-- ---------------------------------------------------------------------------
-- Syntax inspection helpers
-- ---------------------------------------------------------------------------
-- Line number for an anchor. An exact whole-line match wins, so short anchors
-- such as ".end" cannot be stolen by ".endc"; otherwise the first line
-- containing the anchor as plain text is used.
local function lineno(anchor)
  local last = vim.fn.line("$")
  for l = 1, last do
    if vim.fn.getline(l) == anchor then
      return l
    end
  end
  for l = 1, last do
    if vim.fn.getline(l):find(anchor, 1, true) then
      return l
    end
  end
  return nil
end

-- Highlight group at the first occurrence of `needle` on the first line that
-- contains `anchor`. Anchoring by text rather than by line number keeps the
-- assertions readable and survives edits to the fixtures.
local function group_is(anchor, needle, expected, label)
  label = label or (needle .. " -> " .. expected)
  local l = lineno(anchor)
  if not l then
    ok(false, label, "anchor not found: " .. anchor)
    return
  end
  local text = vim.fn.getline(l)
  local col = text:find(needle, 1, true)
  if not col then
    ok(false, label, "needle not found on line " .. l .. ": " .. needle)
    return
  end
  local got = vim.fn.synIDattr(vim.fn.synID(l, col, 1), "name")
  ok(got == expected, label, string.format(
    "expected %q, got %q\n  line %d col %d: %s", expected, got, l, col, text))
end

-- Force the syntax engine over every character of the current buffer. A
-- malformed pattern surfaces here rather than silently producing no highlight.
local function paint_whole_buffer()
  for l = 1, vim.fn.line("$") do
    local width = #vim.fn.getline(l)
    for c = 1, math.max(width, 1) do
      vim.fn.synID(l, c, 1)
    end
  end
end

local function scratch_dbl(lines)
  vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(false, true))
  vim.bo.filetype = "synergydbl"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

-- ===========================================================================
section("File detection")
-- ===========================================================================
eq(vim.filetype.match({ filename = "probe.dbl" }), "synergydbl",
  "vim.filetype.match() maps .dbl to synergydbl")
eq(vim.filetype.match({ filename = "src/SAMPLE.DBL" }), "synergydbl",
  "detection is case-insensitive on the extension")

-- Compiled artifacts and undetected extensions must not be claimed.
ok(vim.filetype.match({ filename = "program.dbo" }) ~= "synergydbl",
  ".dbo (compiled object) is not claimed")
ok(vim.filetype.match({ filename = "target.dbr" }) ~= "synergydbl",
  ".dbr (compiled executable) is not claimed")
ok(vim.filetype.match({ filename = "thing.dbc" }) ~= "synergydbl",
  ".dbc is not claimed (documented decision, see README)")

vim.cmd("edit! " .. vim.fn.fnameescape(fixtures .. "/traditional.dbl"))
eq(vim.bo.filetype, "synergydbl", ":edit of a .dbl file sets the filetype")

-- ===========================================================================
section("Syntax file loads and applies")
-- ===========================================================================
eq(vim.b.current_syntax, "synergydbl", "b:current_syntax is set")

vim.v.errmsg = ""
paint_whole_buffer()
eq(vim.v.errmsg, "", "no error raised while highlighting traditional.dbl")

-- ===========================================================================
section("Highlight groups: traditional DBL")
-- ===========================================================================
-- Comments win over anything later on the line, so prose punctuation cannot
-- open a string.
group_is("deliberately contains an apostrophe", "don't", "SynergyDblComment",
  "apostrophe inside a comment stays comment")
group_is("stray \" and a ;", "\"", "SynergyDblComment",
  "quote inside a comment stays comment")
group_is("stray \" and a ;", "; should", "SynergyDblComment",
  "second semicolon inside a comment stays comment")

-- Inline comment after code.
group_is(";text buffer", ";text", "SynergyDblComment",
  "inline comment after a declaration")

-- Strings: doubled-delimiter escape and embedded punctuation.
group_is("He said", "\"\"", "SynergyDblString",
  "doubled quote is an escape, not a string boundary")
group_is("He said", "; next", "SynergyDblString",
  "semicolon inside a string does not start a comment")
group_is("He said", "'visitor'", "SynergyDblString",
  "nested single quotes stay inside the double-quoted string")

-- Field specifications.
group_is("mode,", "d1", "SynergyDblType", "field spec d1")
group_is(";text buffer", "a64", "SynergyDblType", "field spec a64")
group_is("d6.5", "d6.5", "SynergyDblType", "implied-decimal field spec d6.5")
group_is("[ITEM_LIMIT]i4", "i4", "SynergyDblType",
  "field spec after an array dimension")
group_is("bare type letter", "a    ;", "SynergyDblType",
  "bare type letter in a group declaration")

-- Numbers.
group_is("xcall sample_hook(8642", "8642", "SynergyDblNumber", "numeric literal")
group_is("note(13:12)", "12", "SynergyDblNumber", "number in a substring reference")

-- Directives and conditional compilation.
group_is(".include \"examples.def", ".include", "SynergyDblDirective", ".include")
group_is(".main", ".main", "SynergyDblDirective", ".main")
group_is(".align", ".align", "SynergyDblDirective", ".align")
group_is(".end", ".end", "SynergyDblDirective", ".end")
group_is(".define ITEM_LIMIT", ".define", "SynergyDblPreProc", ".define")
group_is(".ifdef SAMPLE_FLAG", ".ifdef", "SynergyDblPreProc", ".ifdef")
group_is(".endc", ".endc", "SynergyDblPreProc", ".endc")

-- Operators: both delimiting dots belong to the operator.
group_is("total .eq. 0", ".eq.", "SynergyDblOperator", ".eq.")
group_is("total .eq. 0", ".and.", "SynergyDblOperator", ".and.")
group_is("total .eq. 0", ".not.", "SynergyDblOperator", ".not.")
group_is("^size(note) .gt.", ".gt.", "SynergyDblOperator", ".gt.")

-- Routines and intrinsics.
group_is("%sample_check", "%sample_check", "SynergyDblFunction", "%routine")
group_is("%atrim(note)", "%atrim", "SynergyDblFunction", "%atrim")
group_is("xcall sample_hook(8642", "sample_hook", "SynergyDblCallTarget", "xcall target")
group_is("^size(note) .gt.", "^size", "SynergyDblIntrinsic", "^size intrinsic")

-- Statements and structure.
group_is("call print_summary", "call", "SynergyDblKeyword", "call")
group_is("for total from 1 thru", "thru", "SynergyDblKeyword", "thru")
group_is("record storage", "record", "SynergyDblStructure", "record")
group_is("endgroup", "endgroup", "SynergyDblStructure", "endgroup")
group_is("endrecord", "endrecord", "SynergyDblStructure", "endrecord")

-- Labels: definition, reference and I/O clause target.
group_is("print_summary,", "print_summary", "SynergyDblLabel", "label definition")
group_is("goto halt_example", "halt_example", "SynergyDblLabelRef", "goto target")
group_is("onerror halt_example", "halt_example", "SynergyDblLabelRef", "onerror target")
group_is("[err=input_missing]", "err=", "SynergyDblIoClause", "I/O clause keyword")
group_is("[err=input_missing]", "input_missing]", "SynergyDblLabelRef", "I/O clause target label")

-- The finer-grained groups must resolve, through their default links, to the
-- documented top-level groups a colourscheme is expected to override.
eq(vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("SynergyDblLabelRef")), "name"),
  vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("Label")), "name"),
  "SynergyDblLabelRef follows Label by default")

-- False-positive guards: ordinary identifiers must stay unhighlighted.
group_is("= \"empty\"", "note", "", "plain identifier is unhighlighted")
group_is("total .eq. 0", "total", "",
  "identifier is not mistaken for a type")
group_is("total,", "total", "",
  "record field name is not mistaken for a label")

-- Line continuation.
group_is("%string(total))", "&", "SynergyDblContinuation",
  "continuation ampersand")

-- ===========================================================================
section("Highlight groups: Synergy .NET DBL")
-- ===========================================================================
vim.cmd("edit! " .. vim.fn.fnameescape(fixtures .. "/dotnet.dbl"))
eq(vim.bo.filetype, "synergydbl", "dotnet fixture is detected")

vim.v.errmsg = ""
paint_whole_buffer()
eq(vim.v.errmsg, "", "no error raised while highlighting dotnet.dbl")

group_is(";;; Synthetic", ";;;", "SynergyDblComment", ";;; comment")
group_is("import System.Threading", "import", "SynergyDblKeyword", "import")
group_is("namespace FixtureDemo", "namespace", "SynergyDblStructure", "namespace")
group_is("class Gauge", "class", "SynergyDblStructure", "class")
group_is("public current", "public", "SynergyDblStorageClass", "public")
group_is("public current", "i4", "SynergyDblType", "modifier plus field spec")
group_is(",string", "string", "SynergyDblType",
  "named scalar type in declaration position")
group_is("public enum Stage", "enum", "SynergyDblStructure", "enum")
group_is("endenum", "endenum", "SynergyDblStructure", "endenum")
group_is("public method Update", "method", "SynergyDblStructure", "method")
group_is("public method Update", "void", "SynergyDblType",
  "method return type")
group_is("        proc", "proc", "SynergyDblStructure", "proc")
group_is("endmethod", "endmethod", "SynergyDblStructure", "endmethod")
group_is("endclass", "endclass", "SynergyDblStructure", "endclass")
group_is("endnamespace", "endnamespace", "SynergyDblStructure", "endnamespace")
group_is("endmain", "endmain", "SynergyDblStructure", "endmain")
group_is("        try", "try", "SynergyDblKeyword", "try")
group_is("@System.Exception", "@System", "SynergyDblType",
  "object type prefix")
group_is("        endtry", "endtry", "SynergyDblKeyword", "endtry")
group_is("%datetime", "%datetime", "SynergyDblFunction", "%datetime")
group_is("data gauge = new", "new", "SynergyDblKeyword", "new")
group_is("sleep 2", "sleep", "SynergyDblKeyword", "sleep")
group_is("label_text,", "a96", "SynergyDblType",
  "field spec with a string initialiser")
group_is("label_text,", "\"synthetic", "SynergyDblString", "string initialiser")

-- Declaration context must survive keywords and numbers before the type.
scratch_dbl({
  "field, [3]i4",
  "    matrix, [2, MAX_ROWS]d6.5",
  "public static channel, i4",
  "    public static readonly message, a256",
  "    public ordinary, i4",
  "    ids, [3]i4, 1, d8, 3",
  "    d8 = 1",
  "label,",
})
group_is("field,", "i4", "SynergyDblType", "type after a numeric array dimension")
group_is("field,", "3", "SynergyDblNumber", "numeric array dimension keeps its highlight")
group_is("matrix,", "d6.5", "SynergyDblType", "type after mixed array dimensions")
group_is("public static channel", "i4", "SynergyDblType", "type after multiple modifiers at column zero")
group_is("readonly message", "a256", "SynergyDblType", "type after three indented modifiers")
group_is("readonly message", "static", "SynergyDblStorageClass", "declaration modifiers keep their highlight")
group_is("public ordinary", "i4", "SynergyDblType", "type after a single modifier")
group_is("ids,", "d8", "", "type-shaped initialiser is not a type")
group_is("d8 =", "d8", "", "type-shaped variable in a statement is not a type")
group_is("label,", "label", "SynergyDblLabel", "declaration matching leaves labels intact")

-- ===========================================================================
section("Buffer-local ftplugin settings")
-- ===========================================================================
eq(vim.bo.commentstring, "; %s", "commentstring")
eq(vim.bo.comments, ":;;;,:;;,:;", "comments")
eq(vim.bo.suffixesadd, ".dbl,.def,.dbh", "suffixesadd")
eq(vim.bo.include, [==[^\s*\.include\s\+["']]==], "include")
ok(vim.bo.iskeyword:find("%", 1, true) ~= nil, "iskeyword contains %",
  "iskeyword = " .. vim.bo.iskeyword)
ok(vim.bo.formatoptions:find("t", 1, true) == nil,
  "formatoptions has no 't'", "formatoptions = " .. vim.bo.formatoptions)
ok(vim.bo.formatoptions:find("q", 1, true) ~= nil,
  "formatoptions has 'q'", "formatoptions = " .. vim.bo.formatoptions)
eq(vim.bo.shiftwidth, 4, "shiftwidth default applied")
eq(vim.bo.expandtab, true, "expandtab default applied")
eq(vim.bo.tabstop, 8, "tabstop is left at 8 for hard-tab sources")
ok(vim.b.undo_ftplugin ~= nil and vim.b.undo_ftplugin ~= "",
  "b:undo_ftplugin is defined")
eq(vim.b.match_ignorecase, 1, "b:match_ignorecase")
ok(vim.b.match_words ~= nil and vim.b.match_words:find("endrecord", 1, true) ~= nil,
  "b:match_words covers record/endrecord")
ok(vim.b.match_words:find("endmethod", 1, true) ~= nil,
  "b:match_words covers method/endmethod")
ok(vim.b.match_words:find([[\<if\>]], 1, true) == nil,
  "b:match_words deliberately omits if/else")
eq(vim.bo.indentexpr, "synergydbl#GetIndent()", "indentexpr")
ok(vim.b.undo_indent ~= nil and vim.b.undo_indent ~= "",
  "b:undo_indent is defined")

-- The settings must be buffer-local. A buffer created straight from the global
-- defaults must show none of them.
local scratch = vim.api.nvim_create_buf(false, true)
eq(vim.bo[scratch].commentstring, before.commentstring,
  "a fresh buffer keeps the default commentstring")
eq(vim.bo[scratch].indentexpr, "", "a fresh buffer has no indentexpr")
eq(vim.bo[scratch].suffixesadd, before.suffixesadd,
  "a fresh buffer keeps the default suffixesadd")

-- b:undo_ftplugin / b:undo_indent restore the buffer when the filetype changes.
vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(false, true))
vim.bo.filetype = "synergydbl"
eq(vim.bo.commentstring, "; %s", "ftplugin applies on a filetype= assignment")
vim.bo.filetype = "synergydbl_no_such_filetype"
eq(vim.bo.commentstring, before.commentstring,
  "b:undo_ftplugin restores commentstring")
eq(vim.bo.indentexpr, "", "b:undo_indent restores indentexpr")

-- ===========================================================================
section("Indentation")
-- ===========================================================================
local function reindent(path)
  vim.cmd("edit! " .. vim.fn.fnameescape(path))
  vim.bo.shiftwidth = 4
  vim.bo.softtabstop = 4
  vim.bo.expandtab = true
  vim.cmd("silent normal! gg=G")
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

local function compare(got, want, name)
  if #got ~= #want then
    ok(false, name, string.format("line count %d, expected %d", #got, #want))
    return
  end
  for i = 1, #want do
    if got[i] ~= want[i] then
      ok(false, name, string.format(
        "first difference at line %d\n  got:      %q\n  expected: %q",
        i, got[i], want[i]))
      return
    end
  end
  ok(true, name)
end

for _, case in ipairs({ "traditional", "dotnet" }) do
  local expected = vim.fn.readfile(fixtures .. "/" .. case .. ".dbl")
  compare(reindent(fixtures .. "/indent_input_" .. case .. ".dbl"), expected,
    "gg=G reproduces the expected indentation (" .. case .. ")")
  compare(reindent(fixtures .. "/" .. case .. ".dbl"), expected,
    "gg=G is idempotent on already-correct source (" .. case .. ")")
end

local indent_cases = {
  {
    name = "inline if call does not indent the next statement",
    lines = {
      ".proc",
      "    if (%check(ready)) writes(1, \"ready\")",
      "    writes(1, \"always\")",
      ".end",
    },
  },
  {
    name = "inline if/then call does not indent the next statement",
    lines = {
      ".proc",
      "    if (ready) then writes(1, \"ready\")",
      "    writes(1, \"always\")",
      ".end",
    },
  },
  {
    name = "nested single-statement if/else retains each level",
    lines = {
      ".proc",
      "    if (ready) then",
      "        if (valid) then",
      "            writes(1, \"yes\")",
      "        else",
      "            writes(1, \"no\")",
      "    else",
      "        writes(1, \"not ready\")",
      "    writes(1, \"always\")",
      ".end",
    },
  },
  {
    name = "nested begin aligns with its own controlling if",
    lines = {
      ".proc",
      "    if (ready) then",
      "        if (valid) then",
      "        begin",
      "            if (verbose)",
      "                writes(1, \"yes\")",
      "        end",
      "        else",
      "            writes(1, \"no\")",
      "    else",
      "        writes(1, \"not ready\")",
      "    writes(1, \"always\")",
      ".end",
    },
  },
  {
    name = "nested else-if chain aligns each branch",
    lines = {
      ".proc",
      "    if (ready) then",
      "        if (first) then",
      "            writes(1, \"first\")",
      "        else if (second)",
      "            writes(1, \"second\")",
      "        else",
      "            writes(1, \"neither\")",
      "    else",
      "        writes(1, \"not ready\")",
      ".end",
    },
  },
  {
    name = "condition parentheses ignore strings, comments and continuations",
    lines = {
      ".proc",
      "    if (%check(\")\")) ; condition ends here",
      "        ; preserve this comment",
      "        writes(1, \"yes\" +",
      "&           \"!\")",
      "    writes(1, \"always\")",
      ".end",
    },
  },
}

for _, case in ipairs(indent_cases) do
  local input = {}
  for i, line in ipairs(case.lines) do
    input[i] = line:match("^%s*[;&]") and line or line:gsub("^%s+", "")
  end
  scratch_dbl(input)
  vim.cmd("silent normal! gg=G")
  compare(vim.api.nvim_buf_get_lines(0, 0, -1, false), case.lines, case.name)
  vim.cmd("silent normal! gg=G")
  compare(vim.api.nvim_buf_get_lines(0, 0, -1, false), case.lines,
    case.name .. " (idempotent)")
end

-- Exercise Insert mode, not just the indentkeys string or the '=' operator.
for _, word in ipairs({ "end", "END", "End" }) do
  scratch_dbl({ ".proc", "    begin", "        " })
  vim.api.nvim_win_set_cursor(0, { 3, 8 })
  local keys = vim.api.nvim_replace_termcodes("A" .. word .. "<Esc>", true, false, true)
  vim.fn.feedkeys(keys, "xt")
  eq(vim.fn.getline(3), "    " .. word, "typing " .. word .. " dedents the closer")
end

-- The opt-out has to skip the indent script entirely.
vim.g.synergydbl_no_indent = 1
vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(false, true))
vim.bo.filetype = "synergydbl"
eq(vim.bo.indentexpr, "", "g:synergydbl_no_indent = 1 leaves indentexpr unset")
vim.g.synergydbl_no_indent = nil

-- ===========================================================================
section("No global option or mapping pollution")
-- ===========================================================================
local after = snapshot_globals()
for _, name in ipairs(GLOBAL_OPTS) do
  eq(after[name], before[name], "global '" .. name .. "' is unchanged")
end
eq(after["<maps>"], before["<maps>"], "no mappings were added")

-- ===========================================================================
io.write(string.format("\n%d passed, %d failed\n", passed, #failures))
if #failures > 0 then
  io.write("\nfailed checks:\n")
  for _, name in ipairs(failures) do
    io.write("  - " .. name .. "\n")
  end
end
os.exit(#failures == 0 and 0 or 1)
