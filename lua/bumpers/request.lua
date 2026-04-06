local curl = require("plenary.curl")
local config = require("bumpers.config")

local M = {}

---@class BumpersSelection
---@field start_row number 1-indexed
---@field start_col number 1-indexed
---@field end_row number 1-indexed
---@field end_col number 1-indexed
---@field text string

---Resolves the API key from config or environment variables
---@param opts table
---@return string|nil
local function get_api_key(opts)
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

  return api_key_val
end

---Sets up the logging file and returns the path and initial content
---@param model string
---@param provider string
---@param system_prompt string
---@param user_prompt string
---@return string, table
local function setup_logging(model, provider, system_prompt, user_prompt)
  local log_dir = vim.fn.stdpath("data") .. "/bumpers/logs"
  if vim.fn.isdirectory(log_dir) == 0 then
    vim.fn.mkdir(log_dir, "p")
  end
  local log_file = log_dir .. "/bump_" .. os.date("%Y%m%d_%H%M%S") .. ".log"
  local log_content = {
    "--- BUMP REQUEST ---",
    "Time: " .. os.date("%Y-%m-%d %H:%M:%S"),
    "Model: " .. model,
    "Provider: " .. provider,
    "\n=== SYSTEM PROMPT ===",
    system_prompt,
    "\n=== USER PROMPT ===",
    user_prompt,
    "\n=== RESPONSE ===",
  }
  return log_file, log_content
end

---Creates the extmark representing where the text should be inserted
---@param bufnr number
---@param selection BumpersSelection
---@return number|nil extmark_id
---@return number ns_id
local function setup_insertion_extmark(bufnr, selection)
  local start_row = selection.start_row - 1
  local start_col = selection.start_col - 1
  local end_row = selection.end_row - 1
  local end_col = selection.end_col

  local ns_id = vim.api.nvim_create_namespace("bumpers_request")
  
  -- Create the initial undo point by deleting the selection
  vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, {""})
  
  local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, start_row, start_col, {})
  return extmark_id, ns_id
end

---Inserts text at the extmark position
---@param bufnr number
---@param ns_id number
---@param extmark_id number
---@param text string
local function insert_text(bufnr, ns_id, extmark_id, text)
  local mark = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns_id, extmark_id, {})
  if not mark or #mark == 0 then 
    vim.notify("bumpers text insert error: extmark not found", vim.log.levels.ERROR)
    return 
  end
  
  local r = mark[1]
  local c = mark[2]
  
  local new_lines = vim.split(text, "\n", { plain = true })
  
  -- Indentation matching
  if c > 0 and #new_lines > 1 then
    local indent = string.rep(" ", c)
    for i = 2, #new_lines do
      if new_lines[i] ~= "" then
        new_lines[i] = indent .. new_lines[i]
      end
    end
  end
  
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

---Converts headers into a dictionary of strings for plenary.curl
---@param req table
---@return table
local function format_headers(req)
  local headers_dict = {}
  for k, v in pairs(req.headers) do
    if type(v) == "function" then
      headers_dict[k] = tostring(v())
    else
      headers_dict[k] = tostring(v)
    end
  end
  return headers_dict
end

---Initiates the request and handles inline replacement
function M.start(system_prompt, user_prompt, selection)
  local opts = config.get()
  
  local api_key_val = get_api_key(opts)
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

  local req = provider_module.build_request({
    api_key = api_key_val,
    model = opts.model,
    system_prompt = system_prompt,
    user_prompt = user_prompt,
  })

  local bufnr = vim.api.nvim_get_current_buf()
  local log_file, log_content = setup_logging(opts.model, opts.provider, system_prompt, user_prompt)

  local extmark_id, ns_id = setup_insertion_extmark(bufnr, selection)
  if not extmark_id then
    vim.notify("bumpers: Failed to create insertion extmark.", vim.log.levels.ERROR)
    return
  end

  local headers_dict = format_headers(req)
  vim.notify("bumpers: Requesting " .. opts.provider .. "...", vim.log.levels.INFO)

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

      if res.body and type(res.body) == "string" then
        local full_text = provider_module.parse_response(res.body)
        
        if full_text and full_text ~= "" then
          table.insert(log_content, full_text)
          vim.fn.writefile(vim.split(table.concat(log_content, "\n"), "\n", {plain=true}), log_file)
          
          insert_text(bufnr, ns_id, extmark_id, full_text)
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
