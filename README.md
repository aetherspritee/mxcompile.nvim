# mxcompile.nvim

A Neovim plugin inspired by Emacs `M-x compile`.

## Features

- Configurable default compile commands per file type.
- Repeat the last compile command easily.
- Asynchronous execution (using `vim.system`).
- Interruptible running commands.
- Compilation output in a split or floating window.
- Temporary windows by default (close with `q`), can be "promoted" to permanent.
- Command history with `snacks.nvim` picker integration.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "mxcompile.nvim",
  dependencies = { "folke/snacks.nvim" }, -- Optional, for history picker
  config = function()
    require("mxcompile").setup({
      -- Default configuration
      commands = {
        go = "go run %",
        python = "python %",
        rust = "cargo run",
        -- ... add more as needed
      },
      window = {
        type = "split", -- "split", "vsplit", or "float"
        size = 15,
      },
      close_keymap = "q",
      promote_keymap = "<C-p>",
    })
  end,
  keys = {
    { "<leader>mc", ":MxCompile<CR>", desc = "Compile (Default)" },
    { "<leader>mf", function() require("mxcompile").compile(nil, { window = { type = "float" } }) end, desc = "Compile (Float)" },
    { "<leader>mv", function() require("mxcompile").compile(nil, { window = { type = "vsplit" } }) end, desc = "Compile (VSplit)" },
    { "<leader>mr", ":MxRepeat<CR>", desc = "Repeat Last Compile" },
    { "<leader>mh", ":MxHistory<CR>", desc = "Compile History" },
    { "<leader>mi", ":MxInterrupt<CR>", desc = "Interrupt Compile" },
  }
}
```

## Advanced Usage

You can override any configuration option when calling the Lua API directly:

```lua
-- Repeat the last command in a floating window regardless of default config
require("mxcompile").repeat_last({ window = { type = "float" } })
```

## Commands

- `:MxCompile [command]`: Run a compile command. If no command is provided, prompts for one with a default based on file type.
- `:MxRepeat`: Repeat the last compile command.
- `:MxHistory`: Show history of compile commands using `snacks.nvim` (or `vim.ui.select`).
- `:MxInterrupt`: Kill the currently running compile job.
- `:MxPromote`: Promote the current temporary compilation window to a permanent one.

## Window Management

When the compilation window is open:
- `q`: Close the window (default).
- `<C-p>`: Promote the window to permanent (it will no longer close on `q` and will be listed in your buffers).
