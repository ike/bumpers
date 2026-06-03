local config = require("bumpers.config")
local name = "bumpers"

local M = {}

---Setup the bumpers plugin configuration
---@param opts table User configuration
function M.setup(opts)
  config.setup(opts)
end

local function get_multiline_input(callback)
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.6)
  local height = 10
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
    title = " Rewrite instruction (submit: <C-CR> or :w) ",
  })

  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].filetype = "markdown"

  local function submit()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    vim.api.nvim_win_close(win, true)
    vim.api.nvim_buf_delete(buf, { force = true })
    local text = table.concat(lines, "\n")
    callback(text)
  end

  vim.keymap.set("n", "<C-CR>", submit, { buffer = buf })
  vim.keymap.set("i", "<C-CR>", submit, { buffer = buf })
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
    vim.api.nvim_buf_delete(buf, { force = true })
    callback(nil)
  end, { buffer = buf })

  -- Also support :w to submit
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    once = true,
    callback = function() submit() end,
  })

  vim.cmd("startinsert")
end

---Run the main rewrite logic
---@param cmd_opts table Configuration from user command
function M.run(cmd_opts)
  local prompt = require("bumpers.prompt")
  local request = require("bumpers.request")

  -- If range is provided (0 = no range, 1 = one line, 2 = range)
  if cmd_opts and cmd_opts.range == 0 then
    vim.notify("bumpers: No visual selection made. Please select code to rewrite.", vim.log.levels.WARN)
    return
  end

  -- Use vim.ui.input to get user instruction
  get_multiline_input(function(instruction)
    if not instruction or instruction == "" then
      vim.notify("bumpers: No instruction provided. Aborting.", vim.log.levels.WARN)
      return
    end

    -- Defer to next tick so vim.ui window closes properly and visual marks update
    vim.schedule(function()
      local mode = "rewrite"
      local actual_instruction = instruction
      local include_buffers = false

      if actual_instruction:match("!buffers") then
        include_buffers = true
        actual_instruction = actual_instruction:gsub("!buffers%s*", "")
      end

      if actual_instruction:match("^#lastreview") then
        local request = require("bumpers.request")
        request.show_last_review()
        return
      end

      if actual_instruction:match("^#review") then
        mode = "review"
        actual_instruction = actual_instruction:gsub("^#review%s*", "")
      end

      local ok, system_prompt, user_prompt, selection = pcall(prompt.build, actual_instruction, mode, include_buffers)
      if not ok then
        vim.notify("bumpers: Error building prompt: " .. tostring(system_prompt), vim.log.levels.ERROR)
        return
      end

      local total_size = #system_prompt + #user_prompt
      local threshold = config.get().large_prompt_threshold
      if threshold and total_size > threshold then
        local kb = math.floor(total_size / 1024)
        local choice = vim.fn.confirm("Prompt size is " .. kb .. " KB (threshold: " .. math.floor(threshold / 1024) .. " KB). Send anyway?", "&Yes\n&No", 2)
        if choice ~= 1 then
          vim.notify("bumpers: Request aborted by user due to prompt size.", vim.log.levels.INFO)
          return
        end
      end

      request.start(system_prompt, user_prompt, selection, mode)
    end)
  end)
end

return M
