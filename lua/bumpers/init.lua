local config = require("bumpers.config")

local M = {}

---Setup the bumpers plugin configuration
---@param opts table User configuration
function M.setup(opts)
  config.setup(opts)
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
  vim.ui.input({ prompt = "Rewrite instruction: " }, function(instruction)
    if not instruction or instruction == "" then
      vim.notify("bumpers: No instruction provided. Aborting.", vim.log.levels.WARN)
      return
    end
    
    -- Defer to next tick so vim.ui window closes properly and visual marks update
    vim.schedule(function()
      local mode = "rewrite"
      local actual_instruction = instruction
      if instruction:match("^#review") then
        mode = "review"
        actual_instruction = instruction:gsub("^#review%s*", "")
      end

      local ok, system_prompt, user_prompt, selection = pcall(prompt.build, actual_instruction, mode)
      if not ok then
        vim.notify("bumpers: Error building prompt: " .. tostring(system_prompt), vim.log.levels.ERROR)
        return
      end

      request.start(system_prompt, user_prompt, selection, mode)
    end)
  end)
end

return M
