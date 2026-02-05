" Autoload functions for cargo-make completion

function! cargo_make#complete(ArgLead, CmdLine, CursorPos) abort
  return luaeval('require("cargo-make").get_task_names()')
endfunction
