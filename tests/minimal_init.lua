-- Minimal, isolated init for the headless tests.
--
-- Replaces 'runtimepath' outright so no user config, site directory or plugin
-- manager can influence the result, then enables filetype and syntax handling
-- explicitly rather than relying on defaults.
--
-- Order matters: the plugin root has to be on 'runtimepath' before
-- `filetype plugin indent on`, otherwise ftdetect/synergydbl.lua is never
-- sourced.

local this_file = debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(this_file, ":p:h:h")

vim.opt.runtimepath = { vim.env.VIMRUNTIME, root }
vim.opt.packpath = {}

vim.g.synergydbl_test_root = root

vim.cmd("filetype plugin indent on")
vim.cmd("syntax enable")
