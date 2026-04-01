local M = {}

M.options = {
  provider = "anthropic", -- "anthropic" or "gemini"
  model = "claude-opus-4-6", -- Default for Anthropic; if gemini, use e.g., "gemini-3.1-pro-preview"
  api_keys = {
    anthropic = os.getenv("ANTHROPIC_API_KEY"),
    gemini = os.getenv("GEMINI_API_KEY"),
  },
  lsp_timeout_ms = 1000, -- Timeout for synchronous LSP hover requests
}

function M.setup(user_opts)
  if user_opts then
    M.options = vim.tbl_deep_extend("force", M.options, user_opts)
  end
end

function M.get()
  return M.options
end

return M
