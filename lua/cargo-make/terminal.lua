local M = {}

M._buf   = nil  -- persistent output buffer
M._win   = nil  -- last known window (may have been closed)
M._job   = nil  -- current running job id
M._root  = nil  -- project root from last run
M._items = {}   -- parsed error/warning items from last build

local ns          = vim.api.nvim_create_namespace('cargo-make')
local diagnostics = require('cargo-make.diagnostics')

local function get_split_cmd(position)
  if position == 'top' then return 'topleft'
  elseif position == 'left' then return 'topleft vertical'
  elseif position == 'right' then return 'botright vertical'
  else return 'botright'
  end
end

-- Strip ANSI CSI escape sequences (colours, cursor moves, etc.).
local function strip_ansi(s)
  return s:gsub('\27%[[%d;]*[A-Za-z]', '')
end

local function scroll_to_bottom(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
      break
    end
  end
end

-- Append a jobstart data chunk to the buffer and scroll.
local function append_output(buf, data)
  if not data or not vim.api.nvim_buf_is_valid(buf) then return end
  -- jobstart appends a trailing '' when output ends with \n — drop it.
  local lines = data
  if #lines > 0 and lines[#lines] == '' then
    lines = vim.list_slice(lines, 1, #lines - 1)
  end
  if #lines == 0 then return end
  for i, line in ipairs(lines) do
    lines[i] = strip_ansi(line)
  end
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
  scroll_to_bottom(buf)
end

-- Apply vim.diagnostics to the output buffer so the user can navigate with
-- ]d / [d while in that window. Reads lines directly from the buffer so lnum
-- indices are always correct. Also builds M._items for the picker.
local function apply_diagnostics(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  vim.diagnostic.reset(ns, buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  vim.diagnostic.set(ns, buf, diagnostics.parse(lines))
  -- Build items for the Snacks picker
  local raw = diagnostics.parse_with_locations(lines)
  M._items = {}
  for _, item in ipairs(raw) do
    if item.file and M._root then
      item.file = M._root .. '/' .. item.file
    end
    table.insert(M._items, item)
  end
end

function M.get_items() return M._items end

-- Return (buf, win), creating the persistent buffer and split on first call.
local function ensure_buf(config)
  local split_cmd = get_split_cmd(config.output_position)

  if M._buf and vim.api.nvim_buf_is_valid(M._buf) then
    if not M._win or not vim.api.nvim_win_is_valid(M._win) then
      vim.cmd(string.format('%s %dsp', split_cmd, config.output_height))
      local new_win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(new_win, M._buf)
      M._win = new_win
    end
    return M._buf, M._win
  end

  vim.cmd(string.format('%s %dnew', split_cmd, config.output_height))
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()

  vim.api.nvim_set_option_value('buftype',   'nofile', { buf = buf })
  vim.api.nvim_set_option_value('bufhidden', 'hide',   { buf = buf })
  vim.api.nvim_set_option_value('buflisted', false,    { buf = buf })

  vim.keymap.set('n', 'q',     ':close<CR>', { buffer = buf, noremap = true, silent = true })
  vim.keymap.set('n', '<Esc>', ':close<CR>', { buffer = buf, noremap = true, silent = true })
  vim.keymap.set('n', 'e', function() require('cargo-make').show_errors() end,
    { buffer = buf, noremap = true, silent = true, desc = 'cargo-make: open errors picker' })

  M._buf = buf
  M._win = win
  return buf, win
end

-- Run a command in a persistent output split.
-- config: { output_position, output_height }
-- on_exit: function(exit_code)
function M.run(task_name, cmd, root, config, on_exit)
  local current_win = vim.api.nvim_get_current_win()
  M._root = root

  local buf = ensure_buf(config)

  pcall(function()
    vim.api.nvim_buf_set_name(buf, string.format('[Cargo Make: %s]', task_name))
  end)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

  if M._job then
    vim.fn.jobstop(M._job)
    M._job = nil
  end

  local job_id = vim.fn.jobstart({ 'sh', '-c', cmd }, {
    cwd         = root,
    on_stdout   = function(_, data) append_output(buf, data) end,
    on_stderr   = function(_, data) append_output(buf, data) end,
    on_exit     = function(_, exit_code)
      M._job = nil
      apply_diagnostics(buf)
      if on_exit then on_exit(exit_code) end
    end,
  })

  if job_id <= 0 then
    vim.notify('cargo-make: failed to start job', vim.log.levels.ERROR)
    vim.api.nvim_set_current_win(current_win)
    return
  end

  M._job = job_id
  vim.api.nvim_set_current_win(current_win)
end

return M
