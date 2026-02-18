local plenary = vim.fn.stdpath('data') .. '/lazy/plenary.nvim'
assert(vim.fn.isdirectory(plenary) == 1, 'plenary.nvim not found at ' .. plenary)
vim.opt.rtp:prepend(plenary)
vim.opt.rtp:prepend('.')  -- plugin root
