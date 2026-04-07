-- Minimal test runner for headless Neovim
local M = {}

M.tests = 0
M.passed = 0
M.failed = 0

function M.assert_equals(expected, actual, msg)
  M.tests = M.tests + 1
  if expected == actual then
    M.passed = M.passed + 1
  else
    M.failed = M.failed + 1
    print(string.format("FAIL: %s\n  Expected: %s\n  Got:      %s", msg or "Assertion failed", tostring(expected), tostring(actual)))
  end
end

function M.assert_true(actual, msg)
  M.assert_equals(true, actual, msg)
end

function M.assert_false(actual, msg)
  M.assert_equals(false, actual, msg)
end

function M.assert_match(pattern, actual, msg)
  M.tests = M.tests + 1
  if string.match(actual, pattern) then
    M.passed = M.passed + 1
  else
    M.failed = M.failed + 1
    print(string.format("FAIL: %s\n  Pattern: %s\n  Got:     %s", msg or "Pattern not matched", tostring(pattern), tostring(actual)))
  end
end

function M.report()
  print(string.format("\nTests: %d | Passed: %d | Failed: %d", M.tests, M.passed, M.failed))
  if M.failed > 0 then
    -- Exit with error code in headless mode
    os.exit(1)
  end
end

return M
