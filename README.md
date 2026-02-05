# nvim-cargo-make

A Neovim plugin for seamless integration with [cargo-make](https://github.com/sagiegurari/cargo-make), the Rust task runner and build tool.

## Features

- ✅ Execute cargo-make tasks directly from Neovim
- ✅ Tab completion for task names
- ✅ Asynchronous task execution (non-blocking)
- ✅ Automatic error parsing and quickfix integration
- ✅ Jump to errors directly from quickfix window
- ✅ Interactive task selection with descriptions
- ✅ Supports all cargo-make tasks and custom Makefile.toml configurations

## Requirements

- Neovim 0.7+
- [cargo-make](https://github.com/sagiegurari/cargo-make) installed (`cargo install cargo-make`)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'andicoder/nvim-cargo-make',
  ft = 'rust',
  cmd = { 'CargoMake', 'CargoMakeList' },
  keys = {
    { '<leader>mc', ':CargoMake check<CR>', desc = 'Cargo Make: Check' },
    { '<leader>mb', ':CargoMake build<CR>', desc = 'Cargo Make: Build' },
    { '<leader>mt', ':CargoMake test<CR>', desc = 'Cargo Make: Test' },
    { '<leader>mr', ':CargoMake run<CR>', desc = 'Cargo Make: Run' },
    { '<leader>ml', ':CargoMakeList<CR>', desc = 'Cargo Make: List Tasks' },
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

- `:CargoMake <task-name>` - Run a specific cargo-make task
  - Supports tab completion for task names
  - Example: `:CargoMake build`

- `:CargoMakeList` - Open an interactive task selector
  - Shows all available tasks with descriptions
  - Select a task to run

### Quickfix Integration

After running a task:
- Errors and warnings are automatically parsed
- Quickfix window opens if there are errors
- Navigate through errors with:
  - `:cnext` / `:cprev` - Next/previous error
  - `:cfirst` / `:clast` - First/last error
  - `Enter` on a quickfix entry to jump to the location

### Example Workflows

**Quick build and error navigation:**
```vim
:CargoMake build         " Build the project
:copen                   " Open quickfix window (auto-opens on errors)
:cnext                   " Jump to next error
:cprev                   " Jump to previous error
```

**Interactive task selection:**
```vim
:CargoMakeList           " Opens a picker with all tasks and descriptions
" Select a task and press Enter to run it
```

**Using tab completion:**
```vim
:CargoMake <Tab>         " Shows all available task names
:CargoMake bui<Tab>      " Completes to 'build'
```

## Configuration

### Recommended Keymaps

Add these to your Neovim config for quick access to common tasks:

```lua
-- Cargo Make shortcuts
vim.keymap.set('n', '<leader>mc', ':CargoMake check<CR>', { desc = 'Cargo Make: Check' })
vim.keymap.set('n', '<leader>mb', ':CargoMake build<CR>', { desc = 'Cargo Make: Build' })
vim.keymap.set('n', '<leader>mt', ':CargoMake test<CR>', { desc = 'Cargo Make: Test' })
vim.keymap.set('n', '<leader>mr', ':CargoMake run<CR>', { desc = 'Cargo Make: Run' })
vim.keymap.set('n', '<leader>mf', ':CargoMake fmt<CR>', { desc = 'Cargo Make: Format' })
vim.keymap.set('n', '<leader>ml', ':CargoMakeList<CR>', { desc = 'Cargo Make: List tasks' })

-- Quickfix navigation
vim.keymap.set('n', '<leader>qo', ':copen<CR>', { desc = 'Open quickfix' })
vim.keymap.set('n', '<leader>qc', ':cclose<CR>', { desc = 'Close quickfix' })
vim.keymap.set('n', ']q', ':cnext<CR>', { desc = 'Next quickfix item' })
vim.keymap.set('n', '[q', ':cprev<CR>', { desc = 'Previous quickfix item' })
```

## How it Works

1. **Task Discovery**: The plugin searches for `Makefile.toml` in the current directory and parent directories
2. **Task Listing**: Uses `cargo make --list-all-steps` to enumerate all available tasks with descriptions
3. **Async Execution**: Runs tasks asynchronously using Neovim's `jobstart()` for non-blocking operation
4. **Error Parsing**: Captures stdout/stderr and parses Rust compiler error format (`error[E0xxx]`, file locations, etc.)
5. **Quickfix Integration**: Populates the quickfix list with parsed errors including file:line:col information
6. **Auto-open**: Automatically opens the quickfix window when errors are detected

## Troubleshooting

**Plugin not loading:**
- Make sure the plugin is in your `runtimepath`
- Check that commands are available with `:command CargoMake`

**Tasks not found:**
- Ensure `Makefile.toml` exists in your project
- Verify cargo-make is installed: `cargo install cargo-make`
- Check that you're in a directory with a Makefile.toml or its subdirectory

**Quickfix not populating:**
- The plugin currently parses Rust compiler output format
- For custom task output, errors must follow standard compiler format

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

MIT

## Author

Created by [andicoder](https://github.com/andicoder)
