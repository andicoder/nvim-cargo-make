local diag  = require('cargo-make.diagnostics')
local ERROR = vim.diagnostic.severity.ERROR
local WARN  = vim.diagnostic.severity.WARN

-- Shorthand for parse_with_locations
local function pwl(lines)
  return diag.parse_with_locations(lines)
end

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

  -- =========================================================================
  -- dx / dioxus tool-wrapped output
  --
  -- dx prefixes every rustc line with a floating-point timestamp and an
  -- uppercase log level before forwarding them:
  --
  --   "   3.671s  INFO  warning: ..."
  --   "   5.234s  INFO  error[E0432]: ..."
  --   "   5.463s  WARN error: could not compile ..."
  --   "   0.699s ERROR 🚫dx and dioxus versions are incompatible!"
  --
  -- All four cases were RED until the timestamp-prefix branch was added.
  -- =========================================================================
  describe('dx / dioxus tool-wrapped output', function()

    -- RED → GREEN: dx forwards rustc warnings under INFO
    it('INFO-wrapped  warning: strips timestamp+level, keeps message', function()
      local d = first { '   3.671s  INFO  warning: unused import: `std::error::Error`' }
      assert.are.equal(WARN, d.severity)
      assert.are.equal('unused import: `std::error::Error`', d.message)
    end)

    -- RED → GREEN: dx forwards rustc errors under INFO
    it('INFO-wrapped  error[code]: strips timestamp+level, keeps message', function()
      local d = first { '   5.234s  INFO  error[E0432]: unresolved import `nwa_data_source::DataSourceActor`' }
      assert.are.equal(ERROR, d.severity)
      assert.are.equal('unresolved import `nwa_data_source::DataSourceActor`', d.message)
    end)

    -- RED → GREEN: cargo error summary forwarded under dx WARN
    it('WARN-wrapped  error: could not compile  is an error', function()
      local d = first { '   5.463s  WARN error: could not compile `mypkg` due to previous error' }
      assert.are.equal(ERROR, d.severity)
      assert.are.equal('could not compile `mypkg` due to previous error', d.message)
    end)

    -- RED → GREEN: cargo warning forwarded under dx WARN
    it('WARN-wrapped  warning: build failed  is a warning', function()
      local d = first { '   5.463s  WARN warning: build failed, waiting for other jobs to finish...' }
      assert.are.equal(WARN, d.severity)
      assert.are.equal('build failed, waiting for other jobs to finish...', d.message)
    end)

    -- RED → GREEN: dx-level ERROR (no rustc prefix, just a bare message)
    it('ERROR log-level line captures the message verbatim', function()
      local d = first { '   0.699s ERROR 🚫dx and dioxus versions are incompatible!' }
      assert.are.equal(ERROR, d.severity)
      assert.are.equal('🚫dx and dioxus versions are incompatible!', d.message)
    end)

    -- GREEN: compilation progress lines must be ignored
    it('INFO Compiled progress lines are ignored', function()
      assert.are.same({}, diag.parse {
        '   1.606s  INFO Compiled [  1/311]: unicode_ident',
        '  12.916s  INFO Bundling app...',
      })
    end)

    -- GREEN: dx WARN lines that are not error/warning prefixed must be ignored
    it('WARN Caused by: and process detail lines are ignored', function()
      assert.are.same({}, diag.parse {
        '   5.463s  WARN Caused by:',
        "   5.463s  WARN   process didn't exit successfully: `/usr/bin/rustc` (exit status: 1)",
      })
    end)

    -- GREEN: cargo-make INFO log lines must be ignored
    it('[cargo-make] INFO lines are ignored', function()
      assert.are.same({}, diag.parse {
        '[cargo-make] INFO - cargo make 0.37.24',
        '[cargo-make][1] INFO - Project: nwa_dso_bin',
      })
    end)

    -- RED → GREEN: correct lnum in mixed dx+rustc output
    it('lnum is correct across mixed dx-prefixed and raw lines', function()
      local lines = {
        '   1.606s  INFO Compiled [  1/311]: unicode_ident',        -- 0 ignored
        '   3.671s  INFO  warning: unused import: `std::fmt`',      -- 1 → WARN
        ' --> packages/foo/src/lib.rs:1:5',                          -- 2 ignored
        '   5.234s  INFO  error[E0432]: unresolved import `Bar`',   -- 3 → ERROR
      }
      local r = diag.parse(lines)
      assert.are.equal(2, #r)
      assert.are.equal(1, r[1].lnum)
      assert.are.equal(WARN,  r[1].severity)
      assert.are.equal(3, r[2].lnum)
      assert.are.equal(ERROR, r[2].severity)
    end)

  end)

end)

-- =============================================================================
-- parse_with_locations()
-- =============================================================================
describe('diagnostics.parse_with_locations()', function()

  -- ===========================================================================
  -- basic pairing (GREEN)
  -- ===========================================================================
  describe('pairing error/warning with -->', function()

    -- GREEN: plain error immediately followed by location
    it('error + location: file/lnum/col are populated', function()
      local r = pwl {
        'error[E0308]: mismatched types',
        '   --> src/main.rs:10:5',
      }
      assert.are.equal(1, #r)
      assert.are.equal(ERROR,              r[1].severity)
      assert.are.equal('mismatched types', r[1].message)
      assert.are.equal('src/main.rs',      r[1].file)
      assert.are.equal(10,                 r[1].lnum)
      assert.are.equal(5,                  r[1].col)
    end)

    -- GREEN: warning immediately followed by location
    it('warning + location: file/lnum/col are populated', function()
      local r = pwl {
        'warning: unused variable: `x`',
        '   --> packages/foo/src/lib.rs:42:9',
      }
      assert.are.equal(1, #r)
      assert.are.equal(WARN,                   r[1].severity)
      assert.are.equal('packages/foo/src/lib.rs', r[1].file)
      assert.are.equal(42,                     r[1].lnum)
      assert.are.equal(9,                      r[1].col)
    end)

    -- GREEN: multiple errors each with their own location
    it('two errors with locations: both paired independently', function()
      local r = pwl {
        'error[E0308]: mismatched types',
        '   --> src/main.rs:10:5',
        '',
        'error[E0382]: borrow of moved value: `s`',
        '   --> src/main.rs:20:9',
      }
      assert.are.equal(2, #r)
      assert.are.equal('src/main.rs', r[1].file)
      assert.are.equal(10,            r[1].lnum)
      assert.are.equal('src/main.rs', r[2].file)
      assert.are.equal(20,            r[2].lnum)
    end)

    -- GREEN: mixed error+warning each with locations
    it('error then warning: severities and locations preserved', function()
      local r = pwl {
        'error[E0308]: mismatched types',
        '   --> src/a.rs:5:1',
        'warning: unused import: `std::fmt`',
        '   --> src/b.rs:3:5',
      }
      assert.are.equal(2, #r)
      assert.are.equal(ERROR,     r[1].severity)
      assert.are.equal('src/a.rs', r[1].file)
      assert.are.equal(WARN,      r[2].severity)
      assert.are.equal('src/b.rs', r[2].file)
    end)

  end)

  -- ===========================================================================
  -- tool-wrapped --> lines (GREEN)
  -- ===========================================================================
  describe('tool-wrapped --> lines', function()

    -- GREEN: dx/cargo-make timestamps the --> line just like the error line
    it('timestamp-prefixed --> is matched and paired', function()
      local r = pwl {
        '   3.671s  INFO  warning: unused import: `std::error::Error`',
        '   3.672s  INFO    --> packages/foo/src/lib.rs:16:5',
      }
      assert.are.equal(1, #r)
      assert.are.equal(WARN,                   r[1].severity)
      assert.are.equal('packages/foo/src/lib.rs', r[1].file)
      assert.are.equal(16, r[1].lnum)
      assert.are.equal(5,  r[1].col)
    end)

    -- GREEN: raw --> paired with tool-wrapped error
    it('raw --> paired with tool-wrapped error', function()
      local r = pwl {
        '   5.234s  INFO  error[E0432]: unresolved import `Bar`',
        '   --> src/lib.rs:1:5',
      }
      assert.are.equal(1, #r)
      assert.are.equal(ERROR,      r[1].severity)
      assert.are.equal('src/lib.rs', r[1].file)
      assert.are.equal(1,          r[1].lnum)
    end)

  end)

  -- ===========================================================================
  -- items without a location (GREEN)
  -- ===========================================================================
  describe('errors/warnings with no following -->', function()

    -- GREEN: error with no --> following it still emitted, file is nil
    it('summary error with no location: item emitted with nil file', function()
      local r = pwl { 'error: could not compile `mypkg` due to previous error' }
      assert.are.equal(1, #r)
      assert.are.equal(ERROR, r[1].severity)
      assert.is_nil(r[1].file)
      assert.is_nil(r[1].lnum)
    end)

    -- GREEN: filler line between error and --> flushes error without location;
    -- the --> line then has no pending to attach to and is discarded.
    it('context pipe line between error and --> flushes error with no file', function()
      local r = pwl {
        'error[E0308]: mismatched types',
        '    |',                        -- non-location, non-error → flushes pending
        '   --> src/main.rs:10:5',      -- pending is nil → dropped
      }
      assert.are.equal(1, #r)
      assert.is_nil(r[1].file)
    end)

    -- GREEN: two consecutive errors — first gets no location, second gets the -->
    it('two consecutive errors: first has no location, second has one', function()
      local r = pwl {
        'error[E0308]: mismatched types',
        'error[E0382]: borrow of moved value: `s`',
        '   --> src/main.rs:20:9',
      }
      assert.are.equal(2, #r)
      assert.is_nil(r[1].file)
      assert.are.equal('src/main.rs', r[2].file)
      assert.are.equal(20,            r[2].lnum)
    end)

  end)

  -- ===========================================================================
  -- orphan location lines must NOT produce an item (RED intent)
  -- ===========================================================================
  describe('orphan location lines produce no output', function()

    -- A --> line with no preceding error/warning is silently dropped.
    it('standalone --> without preceding error: no items', function()
      local r = pwl { '   --> src/main.rs:5:3' }
      assert.are.same({}, r)
    end)

    it('multiple standalone --> lines: no items', function()
      local r = pwl {
        '   --> src/main.rs:5:3',
        '   --> src/lib.rs:10:1',
      }
      assert.are.same({}, r)
    end)

  end)

  -- ===========================================================================
  -- output_lnum (GREEN)
  -- ===========================================================================
  describe('output_lnum', function()

    -- output_lnum is the 0-based index of the error/warning line itself
    it('output_lnum tracks the 0-based line index', function()
      local r = pwl {
        '',                                    -- line 1 (idx 0) – ignored
        'error[E0308]: mismatched types',      -- line 2 (idx 1) → output_lnum = 1
        '   --> src/main.rs:10:5',
        '',
        'warning: unused variable: `x`',       -- line 5 (idx 4) → output_lnum = 4
        '   --> src/lib.rs:3:9',
      }
      assert.are.equal(2, #r)
      assert.are.equal(1, r[1].output_lnum)
      assert.are.equal(4, r[2].output_lnum)
    end)

  end)

  -- ===========================================================================
  -- edge cases (GREEN)
  -- ===========================================================================
  describe('edge cases', function()

    it('empty input returns empty list', function()
      assert.are.same({}, pwl({}))
    end)

    it('only location lines returns empty list', function()
      assert.are.same({}, pwl {
        '   --> src/main.rs:1:1',
        '   --> src/lib.rs:5:3',
      })
    end)

    it('only ignored filler lines returns empty list', function()
      assert.are.same({}, pwl {
        '    |',
        '    = note: something',
        '   Compiling foo v0.1.0',
      })
    end)

    -- trailing pending: last line is an error with no --> after it
    it('error at end of output with no --> is still emitted', function()
      local r = pwl { 'error: aborting due to 1 previous error' }
      assert.are.equal(1, #r)
      assert.are.equal(ERROR, r[1].severity)
      assert.is_nil(r[1].file)
    end)

  end)

end)
