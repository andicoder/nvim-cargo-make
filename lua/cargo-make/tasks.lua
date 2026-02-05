local M = {}

-- Find the root directory containing Makefile.toml
function M.find_makefile_root()
  local current_dir = vim.fn.getcwd()
  local max_depth = 10
  local depth = 0

  while depth < max_depth do
    local makefile_path = current_dir .. '/Makefile.toml'
    if vim.fn.filereadable(makefile_path) == 1 then
      return current_dir
    end

    local parent = vim.fn.fnamemodify(current_dir, ':h')
    if parent == current_dir then
      break
    end
    current_dir = parent
    depth = depth + 1
  end

  return nil
end

-- Parse tasks from Makefile.toml
function M.get_tasks()
  local root = M.find_makefile_root()
  if not root then
    return {}
  end

  local makefile_path = root .. '/Makefile.toml'

  -- Use cargo-make to list tasks
  local cmd = 'cd ' .. vim.fn.shellescape(root) .. ' && cargo make --list-all-steps 2>&1'
  local handle = io.popen(cmd)
  if not handle then
    return {}
  end

  local result = handle:read('*a')
  handle:close()

  -- Parse the output
  local tasks = {}
  for line in result:gmatch('[^\r\n]+') do
    -- Skip info lines, category headers, and separator lines
    if not line:match('^%[cargo%-make%]') and
       not line:match('^%-+$') and
       not line:match('^%s*$') then
      -- cargo-make --list-all-steps outputs lines like:
      -- "build - Build the project"
      -- "build-flow - Full sanity testing flow."
      local name, desc = line:match('^([%w%-_]+)%s*%-%s*(.+)$')
      if name and desc then
        -- Filter out "No Description." entries for cleaner list
        if desc ~= 'No Description.' then
          table.insert(tasks, { name = name, description = desc })
        else
          table.insert(tasks, { name = name, description = nil })
        end
      end
    end
  end

  return tasks
end

return M
