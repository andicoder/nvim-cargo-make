" cargo-make.vim - Cargo Make integration for Neovim

if exists('g:loaded_cargo_make')
  finish
endif
let g:loaded_cargo_make = 1

" Main command - runs with terminal output
command! -nargs=1 -complete=customlist,cargo_make#complete CargoMake lua require('cargo-make').run_task(<f-args>)

" Silent mode - no terminal output, only quickfix
command! -nargs=1 -complete=customlist,cargo_make#complete CargoMakeSilent lua require('cargo-make').run_task(<f-args>, { show_output = false })

" Interactive task list
command! CargoMakeList lua require('cargo-make').list_tasks()
