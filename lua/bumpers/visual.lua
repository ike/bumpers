local M = {}

---Gets the current visual selection coordinates and text
---@return table|nil { text: string, start_row: number, start_col: number, end_row: number, end_col: number }
function M.get_visual_selection()
  -- Using standard marks for visual selection '< and '>
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  if not start_pos or not end_pos then
    return nil
  end

  -- Coordinates from getpos are 1-indexed (bufnum, row, col, off)
  local start_row = start_pos[2]
  local start_col = start_pos[3]
  local end_row = end_pos[2]
  local end_col = end_pos[3]

  -- Normalization in case selection was backwards
  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  -- Get the actual text
  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
  if #lines == 0 then return nil end

  -- Adjust for character selection within the lines
  local mode = vim.fn.visualmode()
  
  if mode == "v" or mode == "\22" then
    -- standard visual or visual block (treating block as standard for now)
    if #lines == 1 then
      -- If start and end are on the same line, just extract the substring
      -- vim columns are byte-indexed, lua string.sub is byte-indexed.
      -- However, getpos() returns 1-based col, so we need to be careful with end_col
      lines[1] = string.sub(lines[1], start_col, end_col)
    else
      -- Truncate first and last lines
      lines[1] = string.sub(lines[1], start_col)
      lines[#lines] = string.sub(lines[#lines], 1, end_col)
    end
  elseif mode == "V" then
    -- line visual mode, no truncation needed
    start_col = 1
    end_col = vim.fn.col({end_row, "$"}) - 1
  end

  return {
    text = table.concat(lines, "\n"),
    start_row = start_row,
    start_col = start_col,
    end_row = end_row,
    end_col = end_col,
  }
end

---Gets the entire buffer's text content
---@return string
function M.get_buffer_context()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  return table.concat(lines, "\n")
end

---Gets the content of other visible buffers
---@return string
function M.get_open_buffers_context()
  local current_bufnr = vim.api.nvim_get_current_buf()
  local wins = vim.api.nvim_list_wins()
  local seen_bufs = { [current_bufnr] = true }
  local context_parts = {}

  for _, win in ipairs(wins) do
    local bufnr = vim.api.nvim_win_get_buf(win)
    if not seen_bufs[bufnr] then
      seen_bufs[bufnr] = true
      
      -- Ensure it's a normal file buffer
      local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")
      if buftype == "" then
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        -- Fallback if buffer has no name
        if bufname == "" then
          bufname = "[No Name]"
        else
          -- Try to make it relative to cwd
          local cwd = vim.fn.getcwd()
          if vim.startswith(bufname, cwd) then
            bufname = string.sub(bufname, string.len(cwd) + 2)
          end
        end

        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        local content = table.concat(lines, "\n")

        table.insert(context_parts, string.format("File: %s\n```\n%s\n```", bufname, content))
      end
    end
  end

  if #context_parts == 0 then
    return ""
  end

  return table.concat(context_parts, "\n\n")
end

return M
