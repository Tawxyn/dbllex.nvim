# DBLLex

I like using Neovim for Synergy development, so I put together this small plugin.
I hope you find it useful too.

Synergy DBL syntax highlighting, indentation, and filetype support for Neovim.

Requires Neovim 0.9 or later. No external dependencies.

## Features

- Detects `.dbl` files, including uppercase extensions.
- Highlights traditional DBL and Synergy .NET syntax.
- Recognizes comments, strings, field types, directives, labels, and routines.
- Provides buffer-local comment settings, include navigation, and matchit pairs.
- Applies conservative indentation while preserving comments and continuations.

Support is lexical. There is no language server or completion.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "Tawxyn/dbllex.nvim",
  ft = "synergydbl",
}
```

No `setup()` call is needed.

## Usage

Open a `.dbl` file. Its filetype should be `synergydbl`:

```vim
:set filetype?
```

Use `:Inspect` to check highlighting and `gg=G` to reindent the buffer.
Highlight colors follow your colorscheme.

Only `.dbl` files are detected automatically. For a DBL include file with another
extension, use `:set filetype=synergydbl`.

## Settings

Both settings are optional. Set them before opening a DBL file.

```lua
-- Disable the indent script.
vim.g.synergydbl_no_indent = 1

-- Keep your own indentation defaults.
vim.g.synergydbl_set_indent_defaults = false
```

The default indentation is four spaces when the buffer still has Neovim's
standard indentation settings. Existing preferences are preserved.

## Tests

The fixtures are synthetic examples written for this plugin's tests.

Run from the repository root:

```powershell
.\tests\run.ps1
```

Or run Neovim directly:

```sh
nvim --headless --noplugin -u tests/minimal_init.lua -l tests/run.lua
```

## License

[MIT](LICENSE)
