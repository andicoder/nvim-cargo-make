describe('init', function()
  before_each(function()
    -- Force a fresh load of the main module so config starts from defaults
    package.loaded['cargo-make'] = nil
  end)

  describe('setup()', function()
    it('overrides defaults with custom values', function()
      local cargo_make = require('cargo-make')
      cargo_make.setup({ output_height = 20, show_output = false })

      assert.are.equal(20, cargo_make.config.output_height)
      assert.are.equal(false, cargo_make.config.show_output)
      -- Unspecified key keeps its default
      assert.are.equal('bottom', cargo_make.config.output_position)
    end)

    it('leaves defaults unchanged when called with empty opts', function()
      local cargo_make = require('cargo-make')
      cargo_make.setup({})

      assert.are.equal(true, cargo_make.config.show_output)
      assert.are.equal(15, cargo_make.config.output_height)
      assert.are.equal('bottom', cargo_make.config.output_position)
    end)

    it('leaves defaults unchanged when called with no args', function()
      local cargo_make = require('cargo-make')
      cargo_make.setup()

      assert.are.equal(true, cargo_make.config.show_output)
      assert.are.equal(15, cargo_make.config.output_height)
      assert.are.equal('bottom', cargo_make.config.output_position)
    end)
  end)

  describe('get_task_names()', function()
    it('returns a flat list of task names', function()
      -- Stub tasks.get_tasks on the cached module table so the fresh require sees it
      local tasks_mod = require('cargo-make.tasks')
      local orig_get_tasks = tasks_mod.get_tasks
      tasks_mod.get_tasks = function()
        return {
          { name = 'build', description = 'Build the project' },
          { name = 'test',  description = 'Run tests' },
          { name = 'lint',  description = nil },
        }
      end

      local cargo_make = require('cargo-make')
      local names = cargo_make.get_task_names()

      tasks_mod.get_tasks = orig_get_tasks

      assert.are.same({ 'build', 'test', 'lint' }, names)
    end)

    it('returns empty table when there are no tasks', function()
      local tasks_mod = require('cargo-make.tasks')
      local orig_get_tasks = tasks_mod.get_tasks
      tasks_mod.get_tasks = function() return {} end

      local cargo_make = require('cargo-make')
      local names = cargo_make.get_task_names()

      tasks_mod.get_tasks = orig_get_tasks

      assert.are.same({}, names)
    end)
  end)
end)
