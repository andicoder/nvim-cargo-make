# nvim-cargo-make

[![test](https://github.com/andicoder/nvim-cargo-make/actions/workflows/test.yml/badge.svg)](https://github.com/andicoder/nvim-cargo-make/actions/workflows/test.yml)

> A lightweight Neovim plugin for seamless [cargo-make](https://github.com/sagiegurari/cargo-make) integration with real-time terminal output and smart window management.

Execute cargo-make tasks directly from Neovim with live output streaming, intelligent terminal reuse, and adaptive auto-scrolling. Built for Rust developers who want their build tools to stay out of the way.

## Why nvim-cargo-make?

- ⚡ **Real-time feedback** - See build output as it happens
- 🔄 **Smart terminal reuse** - One window for all tasks, automatically cleared between builds
- 📜 **Adaptive scrolling** - Auto-follows output, pauses when you scroll up to investigate
- ⌨️  **Tab completion** - Quickly find and run tasks
- 🔍 **Error picker** - Browse all errors and warnings in a searchable list with file preview
- 🎯 **Zero config** - Works out of the box, configure if you want
- 🚀 **Non-blocking** - Async execution never freezes your editor

## Features

- ✅ Execute cargo-make tasks directly from Neovim
- ✅ **Real-time build output** in terminal split
- ✅ **Smart terminal reuse** - clears and reuses the same window for multiple builds
- ✅ **Smart auto-scrolling** - follows output while allowing free navigation
- ✅ Tab completion for task names
- ✅ Asynchronous task execution (non-blocking)
- ✅ Interactive task selection with descriptions
- ✅ Supports all cargo-make tasks and custom Makefile.toml configurations
- ✅ Configurable output display (terminal or silent mode)
- ✅ **Error picker** - searchable list of errors/warnings with source file preview ([snacks.nvim](https://github.com/folke/snacks.nvim) required)

## Requirements

- Neovim 0.7+
- [cargo-make](https://github.com/sagiegurari/cargo-make) installed (`cargo install cargo-make`)
- [snacks.nvim](https://github.com/folke/snacks.nvim) (optional, required for `:CargoMakeErrors`)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'andicoder/nvim-cargo-make',
  ft = 'rust',
  cmd = { 'CargoMake', 'CargoMakeList', 'CargoMakeErrors' },
  keys = {
    { '<leader>mc', ':CargoMake check<CR>',   desc = 'Cargo Make: Check' },
    { '<leader>mb', ':CargoMake build<CR>',   desc = 'Cargo Make: Build' },
    { '<leader>mt', ':CargoMake test<CR>',    desc = 'Cargo Make: Test' },
    { '<leader>mr', ':CargoMake run<CR>',     desc = 'Cargo Make: Run' },
    { '<leader>ml', ':CargoMakeList<CR>',     desc = 'Cargo Make: List Tasks' },
    { '<leader>me', ':CargoMakeErrors<CR>',   desc = 'Cargo Make: Error Picker' },
  },
}
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use 'andicoder/nvim-cargo-make'
```

Using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'andicoder/nvim-cargo-make'
```

## Usage

### Commands

- `:CargoMake <task-name>` - Run a specific cargo-make task with terminal output
  - Supports tab completion for task names
  - Shows real-time build output in a terminal split
  - Example: `:CargoMake build`

- `:CargoMakeSilent <task-name>` - Run a task without terminal output
  - Runs in background, only shows notifications on completion
  - Useful for quick checks or scripts

- `:CargoMakeList` - Open an interactive task selector
  - Shows all available tasks with descriptions
  - Select a task to run

- `:CargoMakeErrors` - Open a searchable picker of all errors and warnings from the last build
  - Shows `●` for errors and `▲` for warnings with filename and line number
  - Preview pane shows the source file at the exact error location
  - Press `Enter` to jump directly to the error in your editor
  - Requires [snacks.nvim](https://github.com/folke/snacks.nvim)

### Terminal Navigation

In the terminal output window:
- Navigate freely with vim motions (`j`/`k`, `gg`/`G`, etc.)
- Search with `/pattern` and navigate with `n`/`N`
- Scroll up to read earlier output (auto-scroll pauses)
- Scroll back to bottom to resume auto-scroll
- Press `q` or `<Esc>` to close the terminal window
- Press `e` to open the error picker

### Example Workflows

**Quick build with real-time output:**
```vim
:CargoMake build         " Build the project (shows output in terminal split)
" Watch the build progress in real-time!
" Terminal auto-scrolls to show latest output
" Navigate freely - scroll up to read earlier output
" Auto-scroll pauses when you scroll up, resumes when near bottom

:CargoMake test          " Run another task - reuses the same terminal window!
" Terminal is automatically cleared before each build

" Navigate in the terminal:
" j/k - scroll up/down
" gg/G - jump to top/bottom
" /pattern - search for text
" q or <Esc> - close terminal
```

**Silent mode (background execution):**
```vim
:CargoMakeSilent check   " Run check without terminal output
" Only get a notification when done
```

**Interactive task selection:**
```vim
:CargoMakeList           " Opens a picker with all tasks and descriptions
" Select a task and press Enter to run it
```

**Browse errors after a failed build:**
```vim
:CargoMake build         " Build fails — output pane shows errors
:CargoMakeErrors         " Opens error picker (or press 'e' in the output pane)
" ● error[E0308]: mismatched types  src/main.rs:10
" ▲ warning: unused variable: `x`  src/lib.rs:42
" Fuzzy-search by message text, preview the file, Enter to jump
```

**Using tab completion:**
```vim
:CargoMake <Tab>         " Shows all available task names
:CargoMake bui<Tab>      " Completes to 'build'
```

## Configuration

### Plugin Setup (Optional)

You can configure the plugin behavior in your Neovim config:

```lua
require('cargo-make').setup({
  show_output = true,        -- Show output in terminal split (default: true)
  output_height = 15,        -- Height of output window (default: 15)
  output_position = 'bottom' -- Position: 'bottom', 'top', 'left', 'right' (default: 'bottom')
})
```

### Recommended Keymaps

Add these to your Neovim config for quick access to common tasks:

```lua
-- Cargo Make shortcuts
vim.keymap.set('n', '<leader>mc', ':CargoMake check<CR>', { desc = 'Cargo Make: Check' })
vim.keymap.set('n', '<leader>mb', ':CargoMake build<CR>', { desc = 'Cargo Make: Build' })
vim.keymap.set('n', '<leader>mt', ':CargoMake test<CR>', { desc = 'Cargo Make: Test' })
vim.keymap.set('n', '<leader>mr', ':CargoMake run<CR>', { desc = 'Cargo Make: Run' })
vim.keymap.set('n', '<leader>mf', ':CargoMake fmt<CR>', { desc = 'Cargo Make: Format' })
vim.keymap.set('n', '<leader>ml', ':CargoMakeList<CR>',   { desc = 'Cargo Make: List tasks' })
vim.keymap.set('n', '<leader>me', ':CargoMakeErrors<CR>', { desc = 'Cargo Make: Error picker' })

-- Window navigation
vim.keymap.set('n', '<C-w>w', '<C-w>w', { desc = 'Switch to next window' })
vim.keymap.set('n', '<C-w>q', ':q<CR>', { desc = 'Close current window' })
```

## How it Works

1. **Task Discovery**: The plugin searches for `Makefile.toml` in the current directory and parent directories
2. **Task Listing**: Uses `cargo make --list-all-steps` to enumerate all available tasks with descriptions
3. **Async Execution**: Runs tasks asynchronously using Neovim's terminal for non-blocking operation
4. **Terminal Output**: Shows real-time output in a terminal split with smart auto-scrolling
   - Auto-scrolls to bottom when you're viewing the end of output
   - Pauses auto-scroll when you scroll up to read earlier output
   - Resumes when you scroll back near the bottom
5. **Terminal Reuse**: Automatically reuses the same terminal window for multiple builds
   - Creates a fresh buffer in the same window position
   - Updates the window title to show current task
   - No more terminal window clutter!
6. **Smart Notifications**: Shows completion message with success/failure status

## Troubleshooting

**Plugin not loading:**
- Make sure the plugin is in your `runtimepath`
- Check that commands are available with `:command CargoMake`

**Tasks not found:**
- Ensure `Makefile.toml` exists in your project
- Verify cargo-make is installed: `cargo install cargo-make`
- Check that you're in a directory with a Makefile.toml or its subdirectory


## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

Run the test suite with:

```sh
make test
```

Requires Neovim with [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) installed (the spec init expects it under `~/.local/share/nvim/lazy/plenary.nvim`).

## License

MIT License - see [LICENSE](LICENSE) file for details

Copyright (c) 2026 andicoder

## Author

Created by [andicoder](https://github.com/andicoder)
