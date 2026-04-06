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

---Extracts up to 10 unique, non-keyword token coordinates within the selection for hover lookup
---@param start_row number
---@param start_col number
---@param end_row number
---@param end_col number
---@return table { word = string, row = number, col = number }
local function extract_tokens(start_row, start_col, end_row, end_col)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row - 1, end_row, false)
  
  -- Basic set of common keywords to ignore across languages to save LSP requests
  local ignore_keywords = {
    ["if"]=true, ["else"]=true, ["elseif"]=true, ["for"]=true, ["while"]=true,
    ["return"]=true, ["function"]=true, ["local"]=true, ["const"]=true, ["let"]=true,
    ["var"]=true, ["import"]=true, ["export"]=true, ["from"]=true, ["class"]=true,
    ["struct"]=true, ["interface"]=true, ["type"]=true, ["public"]=true, ["private"]=true,
    ["protected"]=true, ["true"]=true, ["false"]=true, ["nil"]=true, ["null"]=true,
    ["undefined"]=true, ["and"]=true, ["or"]=true, ["not"]=true, ["in"]=true, ["of"]=true
  }

  local tokens = {}
  local seen = {}
  local token_count = 0
  local max_tokens = 10
  
  for i, line in ipairs(lines) do
    if token_count >= max_tokens then break end
    
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
      if token_count >= max_tokens then break end
      
      local word_end = start_idx + #word - 1
      -- Ensure the token falls within our column bounds and isn't a keyword
      if start_idx >= line_start and word_end <= line_end then
        if not seen[word] and not ignore_keywords[word] then
          seen[word] = true
          token_count = token_count + 1
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
  
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  
  local hover_clients = {}
  for _, client in ipairs(clients) do
    if client:supports_method("textDocument/hover", { bufnr = bufnr }) then
      table.insert(hover_clients, client)
    end
  end
  
  if #hover_clients == 0 then
    return "No active LSP clients supporting hover."
  end
  
  local tokens = extract_tokens(start_row, start_col, end_row, end_col)
  local hover_info = {}
  
  for _, token in ipairs(tokens) do
    local params = {
      textDocument = vim.lsp.util.make_text_document_params(bufnr),
      position = { line = token.row - 1, character = token.col - 1 }
    }
    
    for _, client in ipairs(hover_clients) do
      local ok, res, err = pcall(client.request_sync, client, 'textDocument/hover', params, 1000, bufnr)
      
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
          elseif contents[1] then
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
          break
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
