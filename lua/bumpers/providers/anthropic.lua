local M = {}

function M.build_request(opts)
  local headers = {
    ["x-api-key"] = opts.api_key,
    ["anthropic-version"] = "2023-06-01",
    ["content-type"] = "application/json",
  }

  local payload = {
    -- Important: Claude 3.7 models are named `claude-3-7-sonnet-20250219`
    -- The user will pass this in through opts.model
    model = opts.model,
    system = opts.system_prompt,
    messages = {
      { role = "user", content = opts.user_prompt },
    },
    max_tokens = 8192, -- increased max tokens for 3.7
    stream = true,
  }

  return {
    url = "https://api.anthropic.com/v1/messages",
    headers = headers,
    body = vim.fn.json_encode(payload),
  }
end

---Parses an SSE chunk and returns the delta text if any
---@param line string The SSE line
---@return string|nil
function M.parse_sse(line)
  if not line or line == "" then return nil end
  
  if line:match("^data: ") then
    local data_str = line:sub(7)
    if data_str == "[DONE]" then return nil end
    
    local ok, data = pcall(vim.fn.json_decode, data_str)
    if ok and data then
      if data.type == "content_block_delta" and data.delta and data.delta.text then
        return data.delta.text
      end
    end
  end
  return nil
end

return M
