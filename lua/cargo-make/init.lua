local M = {}

local tasks = require('cargo-make.tasks')
-- local quickfix = require('cargo-make.quickfix')  -- Disabled for now

-- Configuration
M.config = {
  show_output = true,  -- Show output in terminal split
  output_height = 15,  -- Height of the output window
  output_position = 'bottom',  -- 'bottom', 'top', 'left', 'right'
}

-- Store terminal buffer and window for reuse
M._term_buf = nil
M._term_win = nil
M._scroll_timer = nil

-- Setup function for user configuration
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
end

-- Run a cargo-make task
function M.run_task(task_name, opts)
  opts = opts or {}
  local show_output = opts.show_output ~= nil and opts.show_output or M.config.show_output

  if not task_name or task_name == '' then
    vim.notify('Please specify a task name', vim.log.levels.ERROR)
    return
  end

  -- Find the root directory (where Makefile.toml is located)
  local root = tasks.find_makefile_root()
  if not root then
    vim.notify('Makefile.toml not found in current directory or parents', vim.log.levels.ERROR)
    return
  end

  -- Build the command
  local cmd = string.format('cargo make %s', task_name)

  vim.notify(string.format('Running: %s', cmd), vim.log.levels.INFO)

  if show_output then
    -- Run with terminal output
    M.run_task_with_terminal(task_name, cmd, root)
  else
    -- Run silently (old behavior)
    M.run_task_silent(task_name, cmd, root)
  end
end

-- Run task with terminal output
function M.run_task_with_terminal(task_name, cmd, root)
  -- Save the current window
  local current_win = vim.api.nvim_get_current_win()

  local term_win = M._term_win
  local term_buf
  local can_reuse = false

  -- Check if we can reuse existing terminal window
  if term_win and vim.api.nvim_win_is_valid(term_win) then
    -- Try to reuse the window
    local ok = pcall(function()
      -- Delete old buffer if it exists
      if M._term_buf and vim.api.nvim_buf_is_valid(M._term_buf) then
        vim.api.nvim_buf_delete(M._term_buf, { force = true })
      end

      -- Create new buffer without switching to the window
      term_buf = vim.api.nvim_create_buf(false, true)
      M._term_buf = term_buf

      -- Set the new buffer in the existing window
      vim.api.nvim_win_set_buf(term_win, term_buf)

      -- Now switch to that window to run termopen
      vim.api.nvim_set_current_win(term_win)
    end)

    if ok then
      can_reuse = true
    else
      -- Window became invalid, need to create new one
      M._term_win = nil
    end
  end

  if not can_reuse then
    -- Create new window and buffer
    local split_cmd = M.config.output_position == 'bottom' and 'botright'
      or M.config.output_position == 'top' and 'topleft'
      or M.config.output_position == 'left' and 'topleft vertical'
      or M.config.output_position == 'right' and 'botright vertical'
      or 'botright'

    vim.cmd(string.format('%s %dnew', split_cmd, M.config.output_height))
    term_buf = vim.api.nvim_get_current_buf()
    term_win = vim.api.nvim_get_current_win()

    M._term_buf = term_buf
    M._term_win = term_win
  end

  -- Set buffer options
  vim.api.nvim_buf_set_option(term_buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(term_buf, 'buflisted', false)
  vim.api.nvim_buf_set_option(term_buf, 'scrollback', 10000)

  -- Set up keymaps for the terminal buffer
  vim.api.nvim_buf_set_keymap(term_buf, 'n', 'q', ':close<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(term_buf, 'n', '<Esc>', ':close<CR>', { noremap = true, silent = true })

  -- Set buffer name
  pcall(function()
    vim.api.nvim_buf_set_name(term_buf, string.format('[Cargo Make: %s]', task_name))
  end)

  -- Run command directly without quickfix capture
  local full_cmd = string.format('cd %s && %s 2>&1',
    vim.fn.shellescape(root),
    cmd)

  -- Start terminal job
  local job_id = vim.fn.termopen(full_cmd, {
    on_exit = function(_, exit_code)
      -- Show result
      vim.schedule(function()
        if exit_code == 0 then
          vim.notify(string.format('Task "%s" completed successfully', task_name), vim.log.levels.INFO)
        else
          vim.notify(string.format('Task "%s" failed with exit code %d', task_name, exit_code), vim.log.levels.ERROR)
        end
      end)
    end,
  })

  if job_id <= 0 then
    vim.notify('Failed to start cargo-make', vim.log.levels.ERROR)
    return
  end

  -- Stop any existing scroll timer
  if M._scroll_timer then
    M._scroll_timer:stop()
    M._scroll_timer:close()
    M._scroll_timer = nil
  end

  -- Auto-scroll terminal to bottom as output comes in
  local augroup = vim.api.nvim_create_augroup('CargoMakeTerminal_' .. term_buf, { clear = true })
  vim.api.nvim_create_autocmd({'TermOpen', 'TermEnter'}, {
    group = augroup,
    buffer = term_buf,
    callback = function()
      vim.cmd('startinsert')
      if vim.api.nvim_win_is_valid(term_win) then
        pcall(function()
          vim.api.nvim_win_set_cursor(term_win, {vim.api.nvim_buf_line_count(term_buf), 0})
        end)
      end
    end,
  })

  -- Scroll to bottom periodically while job is running
  -- Only auto-scroll if user hasn't manually scrolled up
  M._scroll_timer = vim.loop.new_timer()
  M._scroll_timer:start(0, 100, vim.schedule_wrap(function()
    if vim.api.nvim_buf_is_valid(term_buf) and vim.api.nvim_win_is_valid(term_win) then
      -- Check if terminal is still running
      if vim.api.nvim_buf_get_option(term_buf, 'channel') > 0 then
        pcall(function()
          local line_count = vim.api.nvim_buf_line_count(term_buf)

          -- Only auto-scroll if:
          -- 1. User is not currently in the terminal window, OR
          -- 2. User is in the terminal window and near the bottom (within 3 lines)
          local current_win = vim.api.nvim_get_current_win()
          local should_scroll = false

          if current_win ~= term_win then
            -- User is in a different window, safe to auto-scroll
            should_scroll = true
          else
            -- User is in the terminal window, check if they're near the bottom
            local cursor = vim.api.nvim_win_get_cursor(term_win)
            local cursor_line = cursor[1]
            if line_count - cursor_line <= 3 then
              -- User is near the bottom, keep scrolling
              should_scroll = true
            end
            -- If user has scrolled up (more than 3 lines from bottom), don't auto-scroll
          end

          if should_scroll then
            vim.api.nvim_win_set_cursor(term_win, {line_count, 0})
          end
        end)
      else
        -- Job finished, stop timer
        if M._scroll_timer then
          M._scroll_timer:stop()
          M._scroll_timer:close()
          M._scroll_timer = nil
        end
      end
    else
      -- Buffer or window closed, stop timer
      if M._scroll_timer then
        M._scroll_timer:stop()
        M._scroll_timer:close()
        M._scroll_timer = nil
      end
    end
  end))

  -- Return to the original window
  vim.api.nvim_set_current_win(current_win)
end

-- Run task silently (original behavior)
function M.run_task_silent(task_name, cmd, root)
  local output = {}
  local job_id = vim.fn.jobstart(cmd, {
    cwd = root,
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        vim.list_extend(output, data)
      end
    end,
    on_stderr = function(_, data)
      if data then
        vim.list_extend(output, data)
      end
    end,
    on_exit = function(_, exit_code)
      if exit_code == 0 then
        vim.notify(string.format('Task "%s" completed successfully', task_name), vim.log.levels.INFO)
      else
        vim.notify(string.format('Task "%s" failed with exit code %d', task_name, exit_code), vim.log.levels.ERROR)
      end

      -- Open quickfix window if there are errors
      local qf_list = vim.fn.getqflist()
      if #qf_list > 0 then
        vim.cmd('copen')
      end
    end,
  })

  if job_id <= 0 then
    vim.notify('Failed to start cargo-make', vim.log.levels.ERROR)
  end
end

-- List all available tasks
function M.list_tasks()
  local task_list = tasks.get_tasks()
  if not task_list or #task_list == 0 then
    vim.notify('No tasks found in Makefile.toml', vim.log.levels.WARN)
    return
  end

  -- Display tasks in a floating window or use vim.ui.select
  vim.ui.select(task_list, {
    prompt = 'Select a cargo-make task:',
    format_item = function(item)
      return item.name .. (item.description and (' - ' .. item.description) or '')
    end,
  }, function(choice)
    if choice then
      M.run_task(choice.name)
    end
  end)
end

-- Get task names for completion
function M.get_task_names()
  local task_list = tasks.get_tasks()
  local names = {}
  for _, task in ipairs(task_list) do
    table.insert(names, task.name)
  end
  return names
end

return M
