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

return M
