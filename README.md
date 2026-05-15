# nvim-cargo-make

[![test](https://github.com/andicoder/nvim-cargo-make/actions/workflows/test.yml/badge.svg)](https://github.com/andicoder/nvim-cargo-make/actions/workflows/test.yml)

Run [cargo-make](https://github.com/sagiegurari/cargo-make) tasks from Neovim. Output streams into a reusable terminal split; errors and warnings are parsed into `vim.diagnostic` entries and an optional [snacks.nvim](https://github.com/folke/snacks.nvim) picker.

## Features

- `:CargoMake <task>` — run a task, stream output into a terminal split that is reused and cleared across runs
- `:CargoMakeSilent <task>` — run in the background, notify on completion
- `:CargoMakeList` — pick a task interactively from `cargo make --list-all-steps`
- `:CargoMakeErrors` — open the last build's errors and warnings in a Snacks picker (requires `snacks.nvim`)
- Tab completion for task names
- Async execution (uses `jobstart`)
- Adaptive auto-scroll in the output buffer: follows new output, pauses when you scroll up

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
  cmd = { 'CargoMake', 'CargoMakeSilent', 'CargoMakeList', 'CargoMakeErrors' },
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

Run a task; run another. The output buffer is reused:

```vim
:CargoMake build
:CargoMake test
```

Tab completion expands task names:

```vim
:CargoMake <Tab>
:CargoMake bui<Tab>
```

Run without opening the output split:

```vim
:CargoMakeSilent check
```

Pick a task from `cargo make --list-all-steps`:

```vim
:CargoMakeList
```

Browse errors and warnings from the last build:

```vim
:CargoMake build
:CargoMakeErrors
```

The picker shows `●` for errors and `▲` for warnings with `file:line`, previews the source, and jumps on `<CR>`. Requires [snacks.nvim](https://github.com/folke/snacks.nvim).

### Keys in the output buffer

| Key        | Action                  |
| ---------- | ----------------------- |
| `j` / `k`  | scroll down / up        |
| `gg` / `G` | top / bottom            |
| `/pattern` | search                  |
| `n` / `N`  | next / previous match   |
| `q`, `<Esc>` | close                 |
| `e`        | open the error picker   |

Auto-scroll follows new output and pauses while you are scrolled up; it resumes when you return to the bottom.

## Configuration

`setup()` is optional. Defaults:

```lua
require('cargo-make').setup({
  show_output = true,         -- open the output split
  output_height = 15,         -- rows when position is 'bottom' or 'top'
  output_position = 'bottom', -- 'bottom' | 'top' | 'left' | 'right'
})
```

Example keymaps (if you are not using the lazy.nvim block above):

```lua
vim.keymap.set('n', '<leader>mc', ':CargoMake check<CR>',  { desc = 'Cargo Make: check' })
vim.keymap.set('n', '<leader>mb', ':CargoMake build<CR>',  { desc = 'Cargo Make: build' })
vim.keymap.set('n', '<leader>mt', ':CargoMake test<CR>',   { desc = 'Cargo Make: test' })
vim.keymap.set('n', '<leader>mr', ':CargoMake run<CR>',    { desc = 'Cargo Make: run' })
vim.keymap.set('n', '<leader>ml', ':CargoMakeList<CR>',    { desc = 'Cargo Make: list tasks' })
vim.keymap.set('n', '<leader>me', ':CargoMakeErrors<CR>',  { desc = 'Cargo Make: error picker' })
```

## How it works

- `Makefile.toml` is located by walking up from the current buffer's directory.
- Tasks are enumerated via `cargo make --list-all-steps`.
- The task itself runs in an async `jobstart` writing into a persistent scratch buffer that is reused and cleared across runs.
- Each build's stdout/stderr is parsed (ANSI stripped) into `vim.diagnostic` entries and an internal list backing `:CargoMakeErrors`.

## Troubleshooting

- **Commands not registered.** Confirm the plugin is on `runtimepath` and that `:command CargoMake` lists the commands. Lazy loaders need `:CargoMakeSilent` in the trigger list as well.
- **No tasks listed.** `Makefile.toml` must exist in the buffer's directory or a parent, and `cargo make` must be on `PATH`.

## Contributing

Run the test suite with `make test`. The spec runner expects [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) at `~/.local/share/nvim/lazy/plenary.nvim` (the path `spec/minimal_init.lua` asserts on).

Issues and pull requests welcome.

## License

MIT — see [LICENSE](LICENSE).
