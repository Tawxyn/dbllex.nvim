-- Synergy DBL filetype detection.
--
-- The extension table below is the single place to extend detection. Deliberate
-- omissions:
--   * .dbo / .dbr / .dbp are compiled artifacts.
--   * .def also names MSVC module-definition files.
--   * .dbc is not detected.
--
-- To add an extension, add one entry: e.g. dbh = "synergydbl".

vim.filetype.add({
  extension = {
    dbl = "synergydbl",
  },
  -- Neovim's `extension` lookup is case-sensitive. Also accept SAMPLE.DBL.
  -- Patterns are consulted after `extension`, preserving the lower-case path.
  pattern = {
    [".*%.[dD][bB][lL]"] = "synergydbl",
  },
})
