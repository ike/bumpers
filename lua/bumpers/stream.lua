local curl = require("plenary.curl")
local config = require("bumpers.config")

local M = {}

---Buffers and parses SSE lines from raw chunk stream
-- Note: plenary.curl stream callback receives data already split into lines without \n
local function make_sse_parser(provider_module, callback, debug_chunks)
  return function(err, line)
    if err then 
      if debug_chunks then
        vim.notify("STREAM ERR: " .. tostring(err), vim.log.levels.ERROR)
      end
      return 
    end
    
    -- In plenary.curl (which uses plenary.job), the streaming callback is fundamentally broken
    -- for incomplete lines or JSON payloads spanning multiple lines because it silently buffers
    -- and mangles newlines internally. But the `FULL RES BODY` always holds the complete
    -- raw HTTP response body when the curl job exits!
    --
    -- We are removing the broken live SSE parsing and replacing it with a full-body parse
    -- at the end of the request.
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
  local api_key_val = opts.api_keys and opts.api_keys[opts.provider]
  
  if not api_key_val or api_key_val == "" then
    if opts.provider == "anthropic" then
      api_key_val = os.getenv("ANTHROPIC_API_KEY")
    elseif opts.provider == "gemini" then
      api_key_val = os.getenv("GEMINI_API_KEY")
    end
  end

  if type(api_key_val) == "function" then
    api_key_val = api_key_val()
  end

  if not api_key_val or api_key_val == "" then
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

  -- Enable debug mode globally to log chunks if we are failing silently
  local debug_chunks = false

  local req = provider_module.build_request({
    api_key = api_key_val,
    model = opts.model,
    system_prompt = system_prompt,
    user_prompt = user_prompt,
  })

  -- Dump the full request to see what's being sent
  if debug_chunks then
    vim.notify("REQUEST URL: " .. vim.inspect(req.url), vim.log.levels.INFO)
    vim.notify("REQUEST BODY: " .. string.sub(vim.inspect(req.body), 1, 300) .. "...", vim.log.levels.INFO)
  end

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

  -- Capture whether we successfully deleted the text.
  -- The extmark tracks exactly where we need to put the new text.
  if not extmark_id then
    vim.notify("bumpers: Failed to create insertion extmark.", vim.log.levels.ERROR)
    return
  end

  local function insert_text(text)
    local mark = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns_id, extmark_id, {})
    if not mark or #mark == 0 then 
      vim.notify("bumpers text insert error: extmark not found", vim.log.levels.ERROR)
      return 
    end
    
    local r = mark[1]
    local c = mark[2]
    
    local new_lines = vim.split(text, "\n", { plain = true })
    
    pcall(vim.cmd, "undojoin")
    
    local ok, err = pcall(vim.api.nvim_buf_set_text, bufnr, r, c, r, c, new_lines)
    if not ok then
      vim.notify("bumpers text insert error: " .. tostring(err) .. " at pos " .. tostring(r) .. ":" .. tostring(c), vim.log.levels.ERROR)
      return
    end
    
    local new_r = r + #new_lines - 1
    local new_c = (#new_lines == 1) and (c + string.len(new_lines[1])) or string.len(new_lines[#new_lines])
    
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, new_r, new_c, { id = extmark_id })
  end

  local parser = make_sse_parser(provider_module, insert_text, debug_chunks)

  -- Plenary curl expects headers as an array of strings like { "Content-Type: application/json" }
  -- or a dictionary like { ["Content-Type"] = "application/json" }
  -- But we must ensure the *values* are strictly strings, not functions
  local headers_dict = {}
  for k, v in pairs(req.headers) do
    if type(v) == "function" then
      headers_dict[k] = tostring(v())
    else
      headers_dict[k] = tostring(v)
    end
  end

  vim.notify("bumpers: Requesting " .. opts.provider .. "...", vim.log.levels.INFO)

  -- We will not use the streaming callback because Plenary's job handler aggressively
  -- buffers and destroys newline sequences inside SSE payloads making live parsing impossible.
  -- Instead, we let curl download the entire response body and parse it exactly once.
  curl.post(req.url, {
    headers = headers_dict,
    body = req.body,
    callback = vim.schedule_wrap(function(res)
      if res.status < 200 or res.status >= 300 then
        local err_msg = "bumpers: Error " .. res.status
        if res.body and res.body ~= "" then
          err_msg = err_msg .. " - " .. vim.inspect(res.body)
        end
        vim.notify(err_msg, vim.log.levels.ERROR)
        vim.api.nvim_buf_del_extmark(bufnr, ns_id, extmark_id)
        return
      end

      -- The complete SSE payload is perfectly preserved in res.body
      if res.body and type(res.body) == "string" then
        local full_text = ""
        -- Now we can safely split on exactly \n and parse every line
        for line in res.body:gmatch("([^\n]*)\n?") do
          if line ~= "" then
            -- Remove trailing carriage return
            line = line:gsub("\r$", "")
            local parsed = provider_module.parse_sse(line)
            if parsed then
              full_text = full_text .. parsed
            end
          end
        end
        
        if full_text ~= "" then
          -- Run insertion logic exactly once
          insert_text(full_text)
        else
          vim.notify("bumpers: No text extracted from LLM response body.", vim.log.levels.WARN)
        end
      else
        vim.notify("bumpers: No body payload returned from LLM.", vim.log.levels.WARN)
      end

      vim.notify("bumpers: Rewrite complete.", vim.log.levels.INFO)
    end)
  })
end

return M
