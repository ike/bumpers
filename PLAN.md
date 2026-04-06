# Plan: Remove Deprecations & Modernize API Usage (Neovim 0.12+)

## Objective
Update the `bumpers` plugin to exclusively use modern Neovim 0.12+ APIs, removing legacy polyfills and deprecated functions. This will improve performance and maintainability by eliminating compatibility layers.

## 1. Performance Optimization: JSON Parsing
Replace legacy Vimscript JSON functions with native Lua/CJSON bindings in both providers.
- **Files**:
  - `lua/bumpers/providers/anthropic.lua`
  - `lua/bumpers/providers/gemini.lua`
- **Changes**:
  - Replace `vim.fn.json_encode` with `vim.json.encode`
  - Replace `vim.fn.json_decode` with `vim.json.decode`

## 2. Maintainability: LSP API Modernization (Neovim 0.12+)
Remove all backwards-compatibility code for Neovim versions prior to 0.12.
- **File**: `lua/bumpers/lsp.lua`
- **Changes**:
  - **Client Retrieval**: Remove `vim.lsp.get_active_clients` fallback. Use `vim.lsp.get_clients({ bufnr = bufnr })` directly.
  - **Method Support Check**: Remove the `type(client.supports_method) == "function"` check and the fallback to `client.server_capabilities.hoverProvider`. Assume `client:supports_method("textDocument/hover", { bufnr = bufnr })` is always available as a method on the client object.
  - **Synchronous Request**: Remove the `type(client.request_sync) == "function"` check and the fallback to `vim.lsp.buf_request_sync`. Assume `client:request_sync('textDocument/hover', params, 1000, bufnr)` is always available as a method on the client object.

## Execution Strategy
1. Wait for user approval of this plan.
2. Edit `anthropic.lua` and `gemini.lua` to update JSON parsing.
3. Edit `lsp.lua` to strip legacy polyfills and streamline the hover request logic.
