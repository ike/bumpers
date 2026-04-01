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
local function extract_tokens(start_row, end_row)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row - 1, end_row, false)
  
  local tokens = {}
  local seen = {}
  
  for i, line in ipairs(lines) do
    local row = start_row + i - 1
    
    -- Iterate through all word-like tokens using Lua pattern matching
    -- `()` captures the starting index
    for start_idx, word in line:gmatch("()([%a_][%w_]*)") do
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
  if #clients == 0 then
    return "No active LSP clients."
  end
  
  local tokens = extract_tokens(start_row, end_row)
  local hover_info = {}
  
  -- Gather hover requests synchronously
  for _, token in ipairs(tokens) do
    local params = {
      textDocument = vim.lsp.util.make_text_document_params(),
      -- position is 0-indexed in LSP
      position = { line = token.row - 1, character = token.col - 1 }
    }
    
    local results = vim.lsp.buf_request_sync(bufnr, 'textDocument/hover', params, 1000)
    
    if results then
      for client_id, res in pairs(results) do
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
          end
          
          -- Once we get a successful hover response for a token, stop querying other clients for this token
          break
        end
      end
    end
  end
  
  if #hover_info == 0 then
    return "No hover/type information found."
  end
  
  return table.concat(hover_info, "\n---\n")
end

return M
