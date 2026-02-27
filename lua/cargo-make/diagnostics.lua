local M = {}

local ERROR = vim.diagnostic.severity.ERROR
local WARN  = vim.diagnostic.severity.WARN

-- Strip an "error[code]:" or "error:" prefix from s.
-- Returns (ERROR, message) when a prefix was found, else nil.
local function try_error(s)
  local msg = s:gsub('^error%[[^%]]+%]:%s*', ''):gsub('^error:%s*', '')
  if s ~= msg then return ERROR, msg end
end

-- Strip a "warning[code]:" or "warning:" prefix from s.
-- Returns (WARN, message) when a prefix was found, else nil.
local function try_warning(s)
  local msg = s:gsub('^warning%[[^%]]+%]:%s*', ''):gsub('^warning:%s*', '')
  if s ~= msg then return WARN, msg end
end

-- Return (severity, message) for one output line, or (nil, nil) if the line
-- should be ignored.
--
-- Two families of lines are recognised:
--
-- 1. Raw rustc/cargo lines — start with "error" or "warning" at column 0.
--
-- 2. Tool-wrapped lines — dx (dioxus CLI), cargo-make, and similar tools
--    prefix each forwarded rustc line with a timestamp and a log level:
--
--      "   3.671s  INFO  warning: unused import: ..."
--      "   5.234s  INFO  error[E0432]: unresolved import ..."
--      "   5.463s  WARN error: could not compile ..."
--      "   0.699s ERROR 🚫dx and dioxus versions are incompatible!"
--
--    Pattern:  %s* <digits>.<digits> s  %s+  LEVEL  %s+  <rest>
local function parse_line(line)
  -- ── family 1: raw rustc/cargo ──────────────────────────────────────────
  if line:match('^error') then
    local sev, msg = try_error(line)
    if sev then return sev, msg end
  elseif line:match('^warning') then
    local sev, msg = try_warning(line)
    if sev then return sev, msg end
  end

  -- ── family 2: timestamp-prefixed tool output ───────────────────────────
  local level, rest = line:match('^%s*%d+%.%d+s%s+(%u+)%s+(.+)$')
  if not level then return nil, nil end

  if rest:match('^error') then
    local sev, msg = try_error(rest)
    if sev then return sev, msg end
  elseif rest:match('^warning') then
    local sev, msg = try_warning(rest)
    if sev then return sev, msg end
  elseif level == 'ERROR' then
    -- Bare tool-level error: the whole rest is the message
    -- (e.g. "🚫dx and dioxus versions are incompatible!")
    if rest ~= '' then return ERROR, rest end
  end

  return nil, nil
end

-- Parse a list of ANSI-stripped output lines from cargo / rustc / dx and
-- return a list of diagnostic entries ready for vim.diagnostic.set().
--
-- Each entry: { lnum (0-based), col, severity, message, source }
function M.parse(lines)
  local diags = {}

  for i, line in ipairs(lines) do
    local severity, msg = parse_line(line)
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
