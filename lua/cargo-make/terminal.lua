local M = {}

M._term_buf = nil
M._term_win = nil

local function scroll_to_bottom(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  vim.api.nvim_buf_call(buf, function()
    if vim.bo.buftype == 'terminal' then
      vim.cmd('normal! G')
    end
  end)
end

local function get_split_cmd(position)
  if position == 'top' then return 'topleft'
  elseif position == 'left' then return 'topleft vertical'
  elseif position == 'right' then return 'botright vertical'
  else return 'botright'
  end
end

-- Run a command in a terminal split.
-- config: { output_position, output_height }
-- on_exit: function(exit_code)
function M.run(task_name, cmd, root, config, on_exit)
  local current_win = vim.api.nvim_get_current_win()
  local term_buf
  local term_win = M._term_win
  local can_reuse = false

  if term_win and vim.api.nvim_win_is_valid(term_win) then
    local ok = pcall(function()
      if M._term_buf and vim.api.nvim_buf_is_valid(M._term_buf) then
        vim.api.nvim_buf_delete(M._term_buf, { force = true })
      end
      term_buf = vim.api.nvim_create_buf(false, true)
      M._term_buf = term_buf
      vim.api.nvim_win_set_buf(term_win, term_buf)
      vim.api.nvim_set_current_win(term_win)
    end)
    if ok then
      can_reuse = true
    else
      M._term_win = nil
    end
  end

  if not can_reuse then
    local split_cmd = get_split_cmd(config.output_position)
    vim.cmd(string.format('%s %dnew', split_cmd, config.output_height))
    term_buf = vim.api.nvim_get_current_buf()
    term_win = vim.api.nvim_get_current_win()
    M._term_buf = term_buf
    M._term_win = term_win
  end

  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = term_buf })
  vim.api.nvim_set_option_value('buflisted', false, { buf = term_buf })
  vim.api.nvim_set_option_value('scrollback', 10000, { buf = term_buf })

  vim.keymap.set('n', 'q', ':close<CR>', { buffer = term_buf, noremap = true, silent = true })
  vim.keymap.set('n', '<Esc>', ':close<CR>', { buffer = term_buf, noremap = true, silent = true })

  pcall(function()
    vim.api.nvim_buf_set_name(term_buf, string.format('[Cargo Make: %s]', task_name))
  end)

  local full_cmd = string.format('cd %s && %s 2>&1', vim.fn.shellescape(root), cmd)

  local augroup_name = 'CargoMakeTerminal_' .. term_buf
  local augroup = vim.api.nvim_create_augroup(augroup_name, { clear = true })

  vim.api.nvim_create_autocmd('TermDataReceived', {
    group = augroup,
    buffer = term_buf,
    callback = function() scroll_to_bottom(term_buf) end,
  })

  local job_id = vim.fn.termopen(full_cmd, {
    on_exit = function(_, exit_code)
      vim.schedule(function()
        scroll_to_bottom(term_buf)
        pcall(vim.api.nvim_del_augroup_by_name, augroup_name)
        if on_exit then on_exit(exit_code) end
      end)
    end,
  })

  if job_id <= 0 then
    vim.notify('Failed to start cargo-make', vim.log.levels.ERROR)
    vim.api.nvim_set_current_win(current_win)
    return
  end

  vim.api.nvim_set_current_win(current_win)
end

return M
