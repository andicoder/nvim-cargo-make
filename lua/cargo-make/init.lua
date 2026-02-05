local M = {}

local tasks = require('cargo-make.tasks')
local quickfix = require('cargo-make.quickfix')

-- Configuration
M.config = {
  show_output = true,  -- Show output in terminal split
  output_height = 15,  -- Height of the output window
  output_position = 'bottom',  -- 'bottom', 'top', 'left', 'right'
}

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

  -- Create a new split for the terminal
  local split_cmd = M.config.output_position == 'bottom' and 'botright'
    or M.config.output_position == 'top' and 'topleft'
    or M.config.output_position == 'left' and 'topleft vertical'
    or M.config.output_position == 'right' and 'botright vertical'
    or 'botright'

  vim.cmd(string.format('%s %dnew', split_cmd, M.config.output_height))
  local term_buf = vim.api.nvim_get_current_buf()
  local term_win = vim.api.nvim_get_current_win()

  -- Set buffer name
  vim.api.nvim_buf_set_name(term_buf, string.format('[Cargo Make: %s]', task_name))

  -- Capture output for quickfix
  local output = {}
  local temp_file = vim.fn.tempname()

  -- Run command with tee to show output and capture it
  local full_cmd = string.format('cd %s && %s 2>&1 | tee %s; exit ${PIPESTATUS[0]}',
    vim.fn.shellescape(root),
    cmd,
    vim.fn.shellescape(temp_file))

  -- Start terminal job
  local job_id = vim.fn.termopen(full_cmd, {
    on_exit = function(_, exit_code)
      -- Read captured output
      if vim.fn.filereadable(temp_file) == 1 then
        local file = io.open(temp_file, 'r')
        if file then
          for line in file:lines() do
            table.insert(output, line)
          end
          file:close()
          vim.fn.delete(temp_file)
        end
      end

      -- Parse output and populate quickfix
      quickfix.populate_from_output(output, root)

      -- Show result
      vim.schedule(function()
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
      end)
    end,
  })

  if job_id <= 0 then
    vim.notify('Failed to start cargo-make', vim.log.levels.ERROR)
    vim.api.nvim_win_close(term_win, true)
    return
  end

  -- Set buffer options
  vim.api.nvim_buf_set_option(term_buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(term_buf, 'buflisted', false)

  -- Set up keymaps for the terminal buffer
  vim.api.nvim_buf_set_keymap(term_buf, 'n', 'q', ':close<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(term_buf, 'n', '<Esc>', ':close<CR>', { noremap = true, silent = true })

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
      -- Parse output and populate quickfix
      quickfix.populate_from_output(output, root)

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
