local M = {}

-- Parse compiler output and populate quickfix list
function M.populate_from_output(output, cwd)
  if not output or #output == 0 then
    return
  end

  local qf_list = {}
  local current_error = nil
  local i = 1

  while i <= #output do
    local line = output[i]

    if line and line ~= '' then
      -- Pattern 1: error[Exxxx]: or warning: format (start of a new error/warning)
      local error_type, error_code, error_text = line:match('^%s*(error)(%[E%d+%]):%s*(.+)$')
      if not error_type then
        error_type, error_text = line:match('^%s*(warning):%s*(.+)$')
      end

      if error_type then
        current_error = {
          type = error_type:sub(1, 1):upper(),
          text = (error_code or '') .. (error_code and ': ' or '') .. error_text,
        }

        -- Look ahead for the arrow pointer line
        for j = i + 1, math.min(i + 5, #output) do
          local next_line = output[j]
          local file, lnum, col = next_line:match('^%s*%-%->%s*([^:]+):(%d+):(%d+)')
          if file and lnum then
            current_error.filename = file
            current_error.lnum = tonumber(lnum)
            current_error.col = tonumber(col) or 1
            break
          end
        end

        table.insert(qf_list, current_error)
        current_error = nil
      else
        -- Pattern 2: Direct file:line:col format
        local file, lnum, col, type_msg, text = line:match('^([^:]+):(%d+):(%d+):%s*(%w+):%s*(.+)$')
        if file and lnum then
          table.insert(qf_list, {
            filename = file,
            lnum = tonumber(lnum),
            col = tonumber(col) or 1,
            type = type_msg:sub(1, 1):upper(),
            text = text,
          })
        end

        -- Pattern 3: Standalone arrow pointer (in case error message was missed)
        local file2, lnum2, col2 = line:match('^%s*%-%->%s*([^:]+):(%d+):(%d+)')
        if file2 and lnum2 and #qf_list > 0 then
          local last_entry = qf_list[#qf_list]
          if not last_entry.filename then
            last_entry.filename = file2
            last_entry.lnum = tonumber(lnum2)
            last_entry.col = tonumber(col2) or 1
          end
        end
      end
    end

    i = i + 1
  end

  -- Filter out entries without filenames and set the quickfix list
  local filtered_qf = {}
  for _, entry in ipairs(qf_list) do
    if entry.filename then
      table.insert(filtered_qf, entry)
    end
  end

  -- Set the quickfix list
  vim.fn.setqflist({}, 'r', {
    title = 'Cargo Make Output',
    items = filtered_qf,
  })
end

return M
