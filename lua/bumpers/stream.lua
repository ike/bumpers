local curl = require("plenary.curl")
local config = require("bumpers.config")

local M = {}

---Buffers and parses SSE lines from raw chunk stream
local function make_sse_parser(provider_module, callback)
  local buffer = ""
  return function(_, chunk)
    if chunk then
      buffer = buffer .. chunk
      local lines = {}
      for line in buffer:gmatch("([^\r\n]+)\r?\n") do
        table.insert(lines, line)
      end
      
      -- Keep the incomplete line in the buffer
      local last_newline = buffer:find("[^\r\n]*$")
      if last_newline then
        buffer = buffer:sub(last_newline)
      else
        buffer = ""
      end

      for _, line in ipairs(lines) do
        local text = provider_module.parse_sse(line)
        if text and text ~= "" then
          vim.schedule(function()
            callback(text)
          end)
        end
      end
    end
  end
end

---Splits text into an array of lines, handling newlines correctly
local function split_lines(text)
  local lines = {}
  for line in text:gmatch("([^\n]*)\n?") do
    table.insert(lines, line)
  end
  -- remove the trailing empty string from gmatch if text ends with \n
  if #lines > 1 and lines[#lines] == "" then
    table.remove(lines)
  end
  return lines
end

---Initiates the stream and handles inline replacement
function M.start(system_prompt, user_prompt, selection)
  local opts = config.get()
  
  -- The API key can be explicitly provided as a string in opts.api_keys, 
  -- or we dynamically fallback to the default env var names if omitted.
  local api_key = opts.api_keys and opts.api_keys[opts.provider]
  
  -- If it's still empty, it might be that the user provided an empty string or it's not set.
  -- But if the user provided a *different* env var name in their config via os.getenv("CUSTOM_NAME"),
  -- it should have been captured during setup. If not, fallback to standard names.
  if not api_key or api_key == "" then
    if opts.provider == "anthropic" then
      api_key = os.getenv("ANTHROPIC_API_KEY")
    elseif opts.provider == "gemini" then
      api_key = os.getenv("GEMINI_API_KEY")
    end
  end

  -- We need to evaluate the config explicitly if the user passed a function 
  -- or string that resolves to the key.
  if type(api_key) == "function" then
    api_key = api_key()
  end

  if not api_key or api_key == "" then
    vim.notify("bumpers: Missing API key for " .. opts.provider .. ". Set it in setup() or via os.getenv()", vim.log.levels.ERROR)
    return
  end

  local provider_module
  if opts.provider == "anthropic" then
    provider_module = require("bumpers.providers.anthropic")
  elseif opts.provider == "gemini" then
    provider_module = require("bumpers.providers.gemini")
  else
    vim.notify("bumpers: Unknown provider " .. opts.provider, vim.log.levels.ERROR)
    return
  end

  local req = provider_module.build_request({
    api_key = api_key,
    model = opts.model,
    system_prompt = system_prompt,
    user_prompt = user_prompt,
  })

  local bufnr = vim.api.nvim_get_current_buf()
  local start_row = selection.start_row - 1
  local start_col = selection.start_col - 1
  local end_row = selection.end_row - 1
  local end_col = selection.end_col

  -- Prepare insertion mark using extmarks
  local ns_id = vim.api.nvim_create_namespace("bumpers_stream")
  
  -- Create the initial undo point by deleting the selection
  -- This creates the first action in the undo block
  vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, {""})
  
  local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, start_row, start_col, {})

  local function insert_text(text)
    local mark = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns_id, extmark_id, {})
    if not mark or #mark == 0 then return end
    
    local r = mark[1]
    local c = mark[2]
    
    local new_lines = vim.split(text, "\n", { plain = true })
    if #new_lines == 0 then return end
    
    -- Crucial: Join this edit to the previous one in the undo tree
    pcall(vim.cmd, "undojoin")
    
    vim.api.nvim_buf_set_text(bufnr, r, c, r, c, new_lines)
    
    -- Manually update extmark to the end of the newly inserted text
    local new_r = r + #new_lines - 1
    local new_c = (#new_lines == 1) and (c + string.len(new_lines[1])) or string.len(new_lines[#new_lines])
    
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, new_r, new_c, { id = extmark_id })
  end

  local parser = make_sse_parser(provider_module, insert_text)

  local headers = {}
  for k, v in pairs(req.headers) do
    table.insert(headers, string.format("%s: %s", k, v))
  end

  vim.notify("bumpers: Requesting " .. opts.provider .. "...", vim.log.levels.INFO)

  curl.post(req.url, {
    headers = req.headers,
    body = req.body,
    stream = parser,
    callback = vim.schedule_wrap(function(res)
      vim.api.nvim_buf_del_extmark(bufnr, ns_id, extmark_id)
      
      if res.status < 200 or res.status >= 300 then
        vim.notify("bumpers: Error " .. res.status .. " - " .. (res.body or ""), vim.log.levels.ERROR)
      else
        vim.notify("bumpers: Rewrite complete.", vim.log.levels.INFO)
      end
    end)
  })
end

return M
