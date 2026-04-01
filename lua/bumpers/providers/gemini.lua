local M = {}

function M.build_request(opts)
  local headers = {
    ["Content-Type"] = "application/json",
  }

  local payload = {
    systemInstruction = {
      parts = { { text = opts.system_prompt } },
    },
    contents = {
      {
        role = "user",
        parts = { { text = opts.user_prompt } },
      },
    },
  }

  return {
    url = string.format(
      "https://generativelanguage.googleapis.com/v1beta/models/%s:streamGenerateContent?alt=sse&key=%s",
      opts.model,
      opts.api_key
    ),
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
    
    local ok, data = pcall(vim.fn.json_decode, data_str)
    if ok and data and data.candidates and #data.candidates > 0 then
      local candidate = data.candidates[1]
      if candidate.content and candidate.content.parts and #candidate.content.parts > 0 then
        return candidate.content.parts[1].text
      end
    end
  end
  return nil
end

return M
