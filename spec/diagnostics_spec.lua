local diag  = require('cargo-make.diagnostics')
local ERROR = vim.diagnostic.severity.ERROR
local WARN  = vim.diagnostic.severity.WARN

-- Shorthand: parse a list of lines and return the first (and often only) entry.
local function first(lines)
  return diag.parse(lines)[1]
end

describe('diagnostics.parse()', function()

  -- =========================================================================
  -- errors
  -- =========================================================================
  describe('errors', function()

    -- GREEN: plain `error:` (e.g. warning promoted via -D warnings)
    it('plain  error: <msg>', function()
      local d = first { 'error: unused variable: `f`' }
      assert.are.equal(ERROR, d.severity)
      assert.are.equal('unused variable: `f`', d.message)
      assert.are.equal(0, d.lnum)
    end)

    -- GREEN: standard rustc error with code
    it('error[E0308]: mismatched types', function()
      local d = first { 'error[E0308]: mismatched types' }
      assert.are.equal(ERROR, d.severity)
      assert.are.equal('mismatched types', d.message)
    end)

    -- GREEN: error code + backticks in message
    it('error[E0382]: borrow of moved value with backtick in msg', function()
      local d = first { 'error[E0382]: borrow of moved value: `s`' }
      assert.are.equal(ERROR, d.severity)
      assert.are.equal('borrow of moved value: `s`', d.message)
    end)

    -- GREEN: non-exhaustive match
    it('error[E0004]: non-exhaustive patterns', function()
      local d = first { 'error[E0004]: non-exhaustive patterns: `None` not covered' }
      assert.are.equal(ERROR, d.severity)
      assert.are.equal('non-exhaustive patterns: `None` not covered', d.message)
    end)

    -- GREEN: cannot borrow as mutable
    it('error[E0596]: cannot borrow as mutable', function()
      local d = first { 'error[E0596]: cannot borrow `x` as mutable, as it is not declared as mutable' }
      assert.are.equal(ERROR, d.severity)
      assert.are.equal('cannot borrow `x` as mutable, as it is not declared as mutable', d.message)
    end)

    -- GREEN: summary "aborting" line is still surfaced as a diagnostic
    it('error: aborting summary line is captured', function()
      local d = first { 'error: aborting due to 3 previous errors; 2 warnings emitted' }
      assert.are.equal(ERROR, d.severity)
      assert.are.equal('aborting due to 3 previous errors; 2 warnings emitted', d.message)
    end)

    -- GREEN: "could not compile" summary
    it('error: could not compile summary is captured', function()
      local d = first { 'error: could not compile `mypkg` due to previous error' }
      assert.are.equal(ERROR, d.severity)
      assert.are.equal('could not compile `mypkg` due to previous error', d.message)
    end)

  end)

  -- =========================================================================
  -- warnings
  -- =========================================================================
  describe('warnings', function()

    -- GREEN: plain unused variable
    it('plain  warning: unused variable', function()
      local d = first { 'warning: unused variable: `x`' }
      assert.are.equal(WARN, d.severity)
      assert.are.equal('unused variable: `x`', d.message)
      assert.are.equal(0, d.lnum)
    end)

    -- GREEN: unused import with :: path in the message
    it('warning: unused import with :: in message', function()
      local d = first { 'warning: unused import: `std::collections::HashMap`' }
      assert.are.equal(WARN, d.severity)
      assert.are.equal('unused import: `std::collections::HashMap`', d.message)
    end)

    -- GREEN: dead code
    it('warning: function is never used', function()
      local d = first { 'warning: function `foo` is never used' }
      assert.are.equal(WARN, d.severity)
      assert.are.equal('function `foo` is never used', d.message)
    end)

    -- RED → GREEN: `%[%w+%]` does not match `clippy::` because `:` is not %w.
    -- Fixed by widening the bracket pattern to `%[[^%]]+%]`.
    it('warning[clippy::needless_pass_by_value]: strips clippy prefix', function()
      local d = first { 'warning[clippy::needless_pass_by_value]: this argument is passed by value, but not consumed' }
      assert.are.equal(WARN, d.severity)
      assert.are.equal('this argument is passed by value, but not consumed', d.message)
    end)

    -- RED → GREEN (same root fix)
    it('warning[clippy::unwrap_used]: strips clippy prefix', function()
      local d = first { 'warning[clippy::unwrap_used]: used `unwrap()` on a `Result` value' }
      assert.are.equal(WARN, d.severity)
      assert.are.equal('used `unwrap()` on a `Result` value', d.message)
    end)

    -- GREEN: numeric warn code still works after the broader pattern
    it('warning[W0001]: numeric warn code', function()
      local d = first { 'warning[W0001]: some rustc internal warning' }
      assert.are.equal(WARN, d.severity)
      assert.are.equal('some rustc internal warning', d.message)
    end)

  end)

  -- =========================================================================
  -- non-matching lines must be silently ignored
  -- =========================================================================
  describe('non-matching lines', function()

    it('ignores  -->  location lines', function()
      assert.are.same({}, diag.parse { '   --> src/main.rs:10:5' })
    end)

    it('ignores pipe context lines', function()
      assert.are.same({}, diag.parse {
        '    |',
        '10  |     let x: i32 = "hello";',
        '    |                   ^^^^^^^',
      })
    end)

    it('ignores  = note: lines', function()
      assert.are.same({}, diag.parse {
        '    = note: `#[warn(unused_variables)]` on by default',
      })
    end)

    it('ignores  = help: lines', function()
      assert.are.same({}, diag.parse {
        '    = help: for further information visit https://rust-lang.github.io/rust-clippy',
      })
    end)

    it('ignores cargo status lines like  Compiling foo v0.1.0', function()
      assert.are.same({}, diag.parse {
        '   Compiling foo v0.1.0 (/tmp/foo)',
        '    Finished dev [unoptimized + debuginfo] target(s) in 0.42s',
      })
    end)

    it('ignores summary lines that start with a digit', function()
      assert.are.same({}, diag.parse {
        '1 error emitted',
        '3 warnings emitted',
      })
    end)

  end)

  -- =========================================================================
  -- line numbers
  -- =========================================================================
  describe('lnum placement', function()

    it('lnum is 0-based index into the buffer lines list', function()
      local lines = {
        '',                                         -- idx 0 – ignored
        'error: unused variable: `x`',              -- idx 1
        '   --> src/main.rs:5:9',                   -- idx 2 – ignored
        '',                                         -- idx 3 – ignored
        'warning: function `bar` is never used',    -- idx 4
      }
      local r = diag.parse(lines)
      assert.are.equal(2, #r)
      assert.are.equal(1, r[1].lnum)
      assert.are.equal(4, r[2].lnum)
    end)

    it('first line (lnum 0) is correct', function()
      local d = first { 'error[E0308]: mismatched types' }
      assert.are.equal(0, d.lnum)
    end)

  end)

  -- =========================================================================
  -- metadata fields
  -- =========================================================================
  describe('diagnostic fields', function()

    it('source is always "cargo-make"', function()
      local d = first { 'error: some error' }
      assert.are.equal('cargo-make', d.source)
    end)

    it('col is always 0', function()
      local d = first { 'warning: some warning' }
      assert.are.equal(0, d.col)
    end)

  end)

  -- =========================================================================
  -- edge cases
  -- =========================================================================
  describe('edge cases', function()

    it('empty input returns empty list', function()
      assert.are.same({}, diag.parse({}))
    end)

    it('only non-matching lines returns empty list', function()
      assert.are.same({}, diag.parse {
        '   --> src/lib.rs:1:1',
        '    |',
        '    = note: something',
      })
    end)

    it('multiple errors and warnings collected in order', function()
      local r = diag.parse {
        'error[E0308]: mismatched types',
        '   --> src/lib.rs:12:5',
        '',
        'warning[clippy::unwrap_used]: used `unwrap()` on a `Result` value',
        '   --> src/lib.rs:20:9',
        '',
        'error: aborting due to 1 previous error; 1 warning emitted',
      }
      assert.are.equal(3, #r)
      assert.are.equal(ERROR, r[1].severity)
      assert.are.equal(WARN,  r[2].severity)
      assert.are.equal(ERROR, r[3].severity)
    end)

  end)

end)
