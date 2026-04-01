local M = {}

---Gets LSP diagnostics intersecting the visual selection
---@param start_row number (1-indexed)
---@param end_row number (1-indexed)
---@return string
function M.get_diagnostics(start_row, end_row)
  local bufnr = vim.api.nvim_get_current_buf()
  
  -- vim.diagnostic works with 0-indexed namespaces/lines
  local diagnostics = vim.diagnostic.get(bufnr)
  
  local relevant = {}
  for _, diag in ipairs(diagnostics) do
    local d_lnum = diag.lnum + 1 -- convert to 1-indexed
    
    if d_lnum >= start_row and d_lnum <= end_row then
      local severity_map = { "ERROR", "WARN", "INFO", "HINT" }
      local severity = severity_map[diag.severity] or "UNKNOWN"
      
      table.insert(relevant, string.format("Line %d: [%s] %s", d_lnum, severity, diag.message))
    end
  end
  
  if #relevant == 0 then
    return "No relevant LSP diagnostics."
  end
  
  return table.concat(relevant, "\n")
end

---Extracts token coordinates within the selection for hover lookup
---@param start_row number
---@param start_col number
---@param end_row number
---@param end_col number
---@return table { word = string, row = number, col = number }
local function extract_tokens(start_row, start_col, end_row, end_col)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row - 1, end_row, false)
  
  local tokens = {}
  local seen = {}
  
  for i, line in ipairs(lines) do
    local row = start_row + i - 1
    
    local line_start = 1
    local line_end = #line
    
    if i == 1 then
      line_start = start_col
    end
    if i == #lines then
      line_end = end_col
    end
    
    -- Iterate through all word-like tokens using Lua pattern matching
    -- `()` captures the starting index
    for start_idx, word in line:gmatch("()([%a_][%w_]*)") do
      local word_end = start_idx + #word - 1
      -- Ensure the token falls within our column bounds
      if start_idx >= line_start and word_end <= line_end then
        if not seen[word] then
          seen[word] = true
          table.insert(tokens, {
            word = word,
            row = row,
            col = start_idx
          })
        end
      end
    end
  end
  
  return tokens
end

---Queries LSP synchronously for hover info on tokens
---@param start_row number
---@param start_col number
---@param end_row number
---@param end_col number
---@return string
function M.get_hover_info(start_row, start_col, end_row, end_col)
  local bufnr = vim.api.nvim_get_current_buf()
  
  -- Check if there are any active clients for this buffer
  local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
  local clients = get_clients({ bufnr = bufnr })
  
  local hover_clients = {}
  for _, client in ipairs(clients) do
    -- Neovim 0.11+ client.supports_method takes a second argument for bufnr
    -- Neovim 0.12 deprecates client.supports_method in favor of client:supports_method()
    local supports = false
    if type(client.supports_method) == "function" then
      -- Call as a method on the client object (works in 0.12+ and avoids deprecation warning)
      supports = client:supports_method("textDocument/hover", { bufnr = bufnr })
    elseif client.server_capabilities and client.server_capabilities.hoverProvider then
      supports = true
    end
    
    if supports then
      table.insert(hover_clients, client)
    end
  end
  
  if #hover_clients == 0 then
    return "No active LSP clients supporting hover."
  end
  
  local tokens = extract_tokens(start_row, start_col, end_row, end_col)
  local hover_info = {}
  
  -- Gather hover requests synchronously
  for _, token in ipairs(tokens) do
    local params = {
      textDocument = vim.lsp.util.make_text_document_params(bufnr),
      -- position is 0-indexed in LSP
      position = { line = token.row - 1, character = token.col - 1 }
    }
    
    local token_hovered = false
    for _, client in ipairs(hover_clients) do
      -- In Neovim 0.12+, client.request_sync throws a hard lua error if the server internally 
      -- rejects the method despite capabilities saying otherwise. We must wrap it in pcall.
      local ok, res, err = true, nil, nil
      
      if type(client.request_sync) == "function" then
        ok, res, err = pcall(client.request_sync, client, 'textDocument/hover', params, 1000, bufnr)
      else
        ok, res, err = pcall(vim.lsp.buf_request_sync, bufnr, 'textDocument/hover', params, 1000)
        if ok and res then
          res = res[client.id]
        end
      end
      
      if not ok or not res then
        goto continue_client
      end
      
      if res.result and res.result.contents then
        local contents = res.result.contents
        local md_lines = {}
        
        if type(contents) == 'table' then
          if contents.kind == 'markdown' or contents.kind == 'plaintext' then
             md_lines = { contents.value }
          elseif contents.language then
             md_lines = { "```" .. contents.language .. "\n" .. contents.value .. "\n```" }
          elseif type(contents) == 'table' and contents[1] then
             for _, c in ipairs(contents) do
               if type(c) == 'string' then
                 table.insert(md_lines, c)
               elseif type(c) == 'table' and c.value then
                 table.insert(md_lines, c.value)
               end
             end
          end
        elseif type(contents) == 'string' then
          md_lines = { contents }
        end
        
        if #md_lines > 0 then
          table.insert(hover_info, string.format("### Token: %s\n%s\n", token.word, table.concat(md_lines, "\n")))
          token_hovered = true
          break -- We got the hover from one client, no need to ask others
        end
      end
      
      ::continue_client::
    end
  end
  
  if #hover_info == 0 then
    return "No hover/type information found."
  end
  
  return table.concat(hover_info, "\n---\n")
end

return M
