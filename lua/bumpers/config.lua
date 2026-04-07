local M = {}

M.options = {
  provider = "anthropic", -- "anthropic" or "gemini"
  model = "claude-opus-4-6", -- Default for Anthropic; if gemini, use e.g., "gemini-3.1-pro-preview"
  api_keys = {
    -- Default will evaluate to nil, which is fine until evaluated via get_api_key
    anthropic = nil,
    gemini = nil,
  },
  lsp_timeout_ms = 1000, -- Timeout for synchronous LSP hover requests
  large_prompt_threshold = 100000, -- Warn if prompt size in characters exceeds this value
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
