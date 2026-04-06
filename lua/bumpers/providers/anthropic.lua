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
    stream = false,
  }

  return {
    url = "https://api.anthropic.com/v1/messages",
    headers = headers,
    body = vim.json.encode(payload),
  }
end

---Parses the full JSON response and returns the text
---@param json_str string The JSON response
---@return string|nil
function M.parse_response(json_str)
  if not json_str or json_str == "" then return nil end
  
  local ok, data = pcall(vim.json.decode, json_str)
  if ok and data and data.content and #data.content > 0 then
    for _, block in ipairs(data.content) do
      if block.type == "text" and block.text then
        return block.text
      end
    end
  end
  return nil
end

return M
