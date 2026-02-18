local M = {}

local tasks = require('cargo-make.tasks')
local terminal = require('cargo-make.terminal')

-- Configuration
M.config = {
  show_output = true,     -- Show output in terminal split
  output_height = 15,     -- Height of the output window
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

  local root = tasks.find_makefile_root()
  if not root then
    vim.notify('Makefile.toml not found in current directory or parents', vim.log.levels.ERROR)
    return
  end

  local cmd = string.format('cargo make %s', task_name)

  vim.notify(string.format('Running: %s', cmd), vim.log.levels.INFO)

  if show_output then
    terminal.run(task_name, cmd, root, M.config, function(exit_code)
      if exit_code == 0 then
        vim.notify(string.format('Task "%s" completed successfully', task_name), vim.log.levels.INFO)
      else
        vim.notify(string.format('Task "%s" failed with exit code %d', task_name, exit_code), vim.log.levels.ERROR)
      end
    end)
  else
    M.run_task_silent(task_name, cmd, root)
  end
end

-- Run task silently (no terminal window)
function M.run_task_silent(task_name, cmd, root)
  local output = {}
  local job_id = vim.fn.jobstart(cmd, {
    cwd = root,
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then vim.list_extend(output, data) end
    end,
    on_stderr = function(_, data)
      if data then vim.list_extend(output, data) end
    end,
    on_exit = function(_, exit_code)
      if exit_code == 0 then
        vim.notify(string.format('Task "%s" completed successfully', task_name), vim.log.levels.INFO)
      else
        vim.notify(string.format('Task "%s" failed with exit code %d', task_name, exit_code), vim.log.levels.ERROR)
      end

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
