local tasks = require('cargo-make.tasks')

-- Captured at load time while cwd is still the repo root
local repo_root = vim.fn.getcwd()
local fixtures_dir = repo_root .. '/spec/fixtures'

describe('tasks', function()
  describe('find_makefile_root()', function()
    it('returns the directory containing Makefile.toml', function()
      local root_dir = vim.fn.tempname()
      vim.fn.mkdir(root_dir, 'p')
      local subdir = root_dir .. '/subdir/nested'
      vim.fn.mkdir(subdir, 'p')

      local f = io.open(root_dir .. '/Makefile.toml', 'w')
      f:write('[tasks.test]\ndescription = "test"\n')
      f:close()

      local orig_cwd = vim.fn.getcwd()
      vim.fn.chdir(subdir)
      local result = tasks.find_makefile_root()
      vim.fn.chdir(orig_cwd)

      assert.are.equal(root_dir, result)
    end)

    it('returns nil when no Makefile.toml exists in the tree', function()
      -- /tmp is well outside the project; no Makefile.toml will be found walking up
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp, 'p')

      local orig_cwd = vim.fn.getcwd()
      vim.fn.chdir(tmp)
      local result = tasks.find_makefile_root()
      vim.fn.chdir(orig_cwd)

      assert.is_nil(result)
    end)
  end)

  describe('get_tasks()', function()
    it('parses tasks returned by cargo-make', function()
      -- Mock io.popen so the test does not require the cargo-make binary
      local orig_popen = io.popen
      io.popen = function(_cmd)
        local output = table.concat({
          '[cargo-make] INFO - cargo-make 0.37.0',
          'build - Build the project',
          'test - Run tests',
          'lint - Lint the code',
          '',
        }, '\n')
        return {
          read = function(_self, _mode) return output end,
          close = function(_self) end,
        }
      end

      local orig_cwd = vim.fn.getcwd()
      vim.fn.chdir(fixtures_dir)
      local result = tasks.get_tasks()
      vim.fn.chdir(orig_cwd)
      io.popen = orig_popen

      assert.is_not_nil(result)
      assert.are.equal(3, #result)

      local by_name = {}
      for _, t in ipairs(result) do
        by_name[t.name] = t.description
      end
      assert.are.equal('Build the project', by_name['build'])
      assert.are.equal('Run tests', by_name['test'])
      assert.are.equal('Lint the code', by_name['lint'])
    end)

    it('returns empty table when no Makefile.toml is found', function()
      local tmp = vim.fn.tempname()
      vim.fn.mkdir(tmp, 'p')

      local orig_cwd = vim.fn.getcwd()
      vim.fn.chdir(tmp)
      local result = tasks.get_tasks()
      vim.fn.chdir(orig_cwd)

      assert.are.same({}, result)
    end)
  end)
end)
