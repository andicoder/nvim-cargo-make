# CLAUDE.md — nvim-cargo-make project conventions

This file is loaded automatically by Claude Code when working in this repo. It complements the user-level global CLAUDE.md; use both.

## Discipline

- **TDD.** Red → green → refactor. Add or change a failing test BEFORE adding production code. The exception is purely mechanical edits (rename, typo, formatting) and exploratory spikes that get reverted.
- **Clean-code.** Small functions, intention-revealing names, single responsibility. If a function reads top-down, no helpers needed; reach for extraction when the same chunk recurs or the body grows past the soft limit below.
- **Code size limits — soft targets, applied by judgement (no linter wired in yet).**
  - **Line length: ~100.** PEP 8's 79 is too tight; >120 makes side-by-side diffs unreadable.
  - **Function body: ~25 LOC.** Extract a helper when the body grows past that or when the same chunk recurs.
  - **Function arguments: max 5.** Bundle related collaborators into a table (`opts`, `config`) and pass the bundle as a single param. The plugin already does this for `M.run_task(task_name, opts)` and `terminal.run(task_name, cmd, root, config, on_exit)`.
- **Comments — light, at critical spots.** Trivial WHAT-comments (`-- set the buffer`) and multi-paragraph docblocks stay forbidden. But brief comments are encouraged where the WHY is genuinely non-obvious from the code: Neovim API quirks, terminal buffer lifecycle, ANSI stripping, parser pairing logic, async job teardown. One short line is usually enough; two if needed. If a clearer name would remove the need for the comment, prefer the name.
- **PRs, commits and issues are English.** Even when the conversation is in another language, issue titles, issue bodies, PR titles, PR bodies, commit subjects and commit bodies are written in English.

## Stack

- Neovim 0.7+, Lua 5.1 / LuaJIT runtime.
- Plugin layout: `lua/cargo-make/` (modules), `plugin/cargo-make.vim` (commands), `autoload/cargo_make.vim` (completion helper), `spec/` (tests).
- Tests: [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)'s busted-style runner. Spec files live in `spec/` and are named `<module>_spec.lua`.
- Optional runtime deps: [snacks.nvim](https://github.com/folke/snacks.nvim) for the `:CargoMakeErrors` picker.
- External tool: [cargo-make](https://github.com/sagiegurari/cargo-make) — the plugin shells out to `cargo make`.

## Local workflow

```sh
# Run tests (hot path) — requires plenary.nvim available on the lazy path
cargo make test

# Equivalent direct invocation
nvim --headless -u spec/minimal_init.lua \
  -c "PlenaryBustedDirectory spec/ {minimal_init = 'spec/minimal_init.lua'}"

# Try the plugin against a real Rust project
nvim path/to/rust/project/src/main.rs
# :CargoMake build
# :CargoMakeErrors
```

## Issue / PR workflow

- One issue → one branch → one PR. Do not bundle multiple GitHub issues into one branch, even when the diffs would be small. Each PR references the issue it closes in the body (`Fixes #N`).
- Branch names: `fix/<slug>`, `feat/<slug>`, `chore/<slug>`, `docs/<slug>`. Slug is short, kebab-case, and reflects the change, not the ticket number.
- The test that proves the fix and the fix itself land in the same PR (TDD: red → green in the same branch, not split across PRs).
- Branch from `main`. Do not chain issue branches; rebase on `main` if it moves while the PR is open.

## Conventions specific to this codebase

- **Public API is `lua/cargo-make/init.lua`.** Anything `require('cargo-make').*` calls is the user-facing surface; everything else (`terminal`, `diagnostics`, `tasks`) is internal. Don't break the public surface without a deliberate reason.
- **Pure parsers, side-effect-free.** `diagnostics.parse(lines)` and `diagnostics.parse_with_locations(lines)` take a list of ANSI-stripped lines and return data — no `vim.*` calls, no buffer reads. Keeps them trivially testable from busted.
- **One persistent output buffer.** `terminal.lua` reuses a single scratch buffer across runs (`M._buf`). Don't create per-task buffers — clearing is part of the contract.
- **Diagnostics flow:** terminal captures lines → strip ANSI → `diagnostics.parse*` → `vim.diagnostic.set(ns, buf, ...)` and `M._items` for the picker. The output buffer is the source of truth for line numbers.
- **No hard dependency on snacks.nvim.** `M.show_errors()` is the only code path that touches `Snacks.*`; everything else must work without it. Fail with a clear `vim.notify` message, never with a runtime error.
- **Commands are declared in `plugin/cargo-make.vim`.** Completion functions live in `autoload/cargo_make.vim` so they're only loaded when needed.

## Tests

- One spec file per Lua module under `spec/<module>_spec.lua`.
- Use plenary's busted-style `describe` / `it` / `assert.are.equal`. The minimal init in `spec/minimal_init.lua` puts plenary on the rtp and adds the plugin root.
- Parser tests should hit `diagnostics.parse` / `diagnostics.parse_with_locations` directly with hand-crafted line arrays — don't spin up jobs.
- Tests that exercise `terminal.lua` are allowed to create buffers; clean them up at the end of the test.
- Coverage isn't enforced numerically; the rule is *every behavior change has an accompanying test*.

## Out of scope (for now)

- Non-Rust build systems. The plugin assumes `cargo make` as the entry point.
- Quickfix integration — intentionally removed in favor of `vim.diagnostic` + the Snacks picker (see `795a8b6`, `a95cf3e`). Don't re-add it without discussion.
- Windows support. Path handling and `jobstart` flags assume Unix.
