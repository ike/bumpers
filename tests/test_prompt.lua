local test_runner = dofile("tests/test_runner.lua")

-- Mock just the specific modules needed by prompt.lua
package.loaded["bumpers.visual"] = {
  get_visual_selection = function()
    return {
      text = "local x = 'AKIAIOSFODNN7EXAMPLE'",
      start_row = 1, start_col = 1, end_row = 1, end_col = 35
    }
  end,
  get_buffer_context = function()
    return "-- Buffer with AWS key AKIAIOSFODNN7EXAMPLE"
  end,
  get_open_buffers_context = function()
    return "Other file content with github token ghp_1234567890abcdefghijklmnopqrstuvwxyz"
  end
}

package.loaded["bumpers.lsp"] = {
  get_diagnostics = function() return "No diagnostics for AKIAIOSFODNN7EXAMPLE" end,
  get_hover_info = function() return "Type string for AKIAIOSFODNN7EXAMPLE" end
}

local prompt = require("bumpers.prompt")

print("--- Running tests for bumpers.prompt ---")

local instruction = "Fix this code using token AKIAIOSFODNN7EXAMPLE"
local mode = "rewrite"
local include_buffers = true

local system_prompt, user_prompt, selection = prompt.build(instruction, mode, include_buffers)

-- Test 1: AWS Key redacted from instruction
test_runner.assert_match("%[REDACTED_SECRET%]", user_prompt, "Instruction should be redacted")

-- String match returns nil if not found, our assert_false expects the actual value to literally be 'false'.
-- Let's change the assertion to expect nil.
test_runner.assert_equals(nil, string.match(user_prompt, "AKIAIOSFODNN7EXAMPLE"), "Raw AWS key should not be in user prompt")

-- Test 2: GitHub token redacted from buffers
test_runner.assert_equals(nil, string.match(user_prompt, "ghp_1234567890abcdefghijklmnopqrstuvwxyz"), "Raw GitHub token should not be in user prompt")

test_runner.report()
