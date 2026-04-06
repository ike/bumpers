local M = {}

local function url_encode(str)
  if str then
    str = string.gsub(str, "\n", "\r\n")
    str = string.gsub(str, "([^%w %-%_%.%~])",
      function(c) return string.format("%%%02X", string.byte(c)) end)
    str = string.gsub(str, " ", "%%20")
  end
  return str
end

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
      "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s",
      url_encode(opts.model),
      url_encode(opts.api_key)
    ),
    headers = headers,
    body = vim.json.encode(payload),
  }
end

---Parses the full JSON response and returns the generated text
---@param json_str string The JSON response body
---@return string|nil
function M.parse_response(json_str)
  if not json_str or json_str == "" then return nil end
  
  local ok, data = pcall(vim.json.decode, json_str)
  if ok and data and data.candidates and #data.candidates > 0 then
    local candidate = data.candidates[1]
    if candidate.content and candidate.content.parts and #candidate.content.parts > 0 then
      return candidate.content.parts[1].text
    end
  end
  return nil
end

return M
