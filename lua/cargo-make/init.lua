local M = {}

local tasks = require('cargo-make.tasks')
local quickfix = require('cargo-make.quickfix')

-- Run a cargo-make task
function M.run_task(task_name)
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

  -- Run the command and capture output
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
