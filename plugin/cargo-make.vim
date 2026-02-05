" cargo-make.vim - Cargo Make integration for Neovim

if exists('g:loaded_cargo_make')
  finish
endif
let g:loaded_cargo_make = 1

command! -nargs=1 -complete=customlist,cargo_make#complete CargoMake lua require('cargo-make').run_task(<f-args>)
command! CargoMakeList lua require('cargo-make').list_tasks()
