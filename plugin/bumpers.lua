if vim.g.loaded_bumpers then
  return
end
vim.g.loaded_bumpers = true

-- Ensure the command is available immediately upon plugin load
vim.api.nvim_create_user_command("Bump", function(opts)
  require("bumpers").run(opts)
end, { range = true })
