local M = {}

local ERROR = vim.diagnostic.severity.ERROR
local WARN  = vim.diagnostic.severity.WARN

-- Parse a list of ANSI-stripped output lines from cargo / rustc and return
-- a list of diagnostic entries ready for vim.diagnostic.set().
--
-- Each entry:
--   { lnum (0-based), col, severity, message, source }
--
-- Only lines that start with "error" or "warning" are turned into
-- diagnostics; location lines, context pipes, notes, etc. are ignored.
function M.parse(lines)
  local diags = {}

  for i, line in ipairs(lines) do
    local severity, msg

    if line:match('^error') then
      severity = ERROR
      -- Strip  error[any::code]:  or  error:  from the front.
      -- %[[^%]]+%]  matches bracket groups like [E0308] and [clippy::foo].
      msg = line:gsub('^error%[[^%]]+%]:%s*', ''):gsub('^error:%s*', '')

    elseif line:match('^warning') then
      severity = WARN
      msg = line:gsub('^warning%[[^%]]+%]:%s*', ''):gsub('^warning:%s*', '')
    end

    if severity and msg and msg ~= '' then
      table.insert(diags, {
        lnum     = i - 1,
        col      = 0,
        severity = severity,
        message  = msg,
        source   = 'cargo-make',
      })
    end
  end

  return diags
end

return M
