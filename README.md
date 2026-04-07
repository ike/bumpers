# Bumpers

Bumpers is a Neovim plugin that intelligently rewrites your visually selected code using LLMs (Anthropic Claude 4.6, Gemini 3.1) by contextually analyzing your current file and tapping into your local Language Server Protocol (LSP).

## Features
- **LSP Context**: Grabs relevant diagnostics (errors, warnings) and hover type information for symbols directly inside your selection to feed the LLM accurate context.
- **Streamed Replacement**: Code is streamed in real-time right into your buffer.
- **Single-Step Undo**: Using `undojoin`, standard Vim undo (`u`) reverts the entire LLM generation at once.
- **Config-Driven**: Define your API keys and default models in your `setup()` without disruptive UI prompts.

## Prerequisites
- Neovim >= 0.9.0
- `nvim-lua/plenary.nvim` installed

## Installation

### Local Development

If you are developing this plugin locally and want to use it immediately without pushing to GitHub or relying on Neovim 0.12's `vim.pack` cloning behavior, the best practice is to directly prepend the path to your Neovim `runtimepath`:

```lua
-- In your init.lua
-- 1. Ensure the dependency is available
vim.pack.add({ "nvim-lua/plenary.nvim" })

-- 2. Prepend your local path
vim.opt.runtimepath:prepend("/Users/ike/code/personal/bumpers")

-- 3. Set up your configuration
require("bumpers").setup({
  provider = "anthropic",
  model = "claude-opus-4-6", 
  api_keys = {
    anthropic = function() return os.getenv("BUMPERS_API_KEY") end,
    gemini = function() return os.getenv("GEMINI_API_KEY") end,
  },
})

vim.keymap.set("v", "<leader>bb", ":Bump<CR>", { desc = "Bumpers Rewrite" })
```

### Using lazy.nvim (Pre-0.12 or preferred)

```lua
{
  "ike/bumpers",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    -- Choose "anthropic" or "gemini"
    provider = "anthropic",
    
    -- Pick your preferred model
    model = "claude-opus-4-6", 
    
    -- Load keys from environment variables
    api_keys = {
      anthropic = os.getenv("ANTHROPIC_API_KEY"),
      gemini = os.getenv("GEMINI_API_KEY"),
    },
    
    -- How long to wait for synchronous LSP type queries (ms)
    lsp_timeout_ms = 1000,
  },
  keys = {
    { "<leader>bb", ":Bump<CR>", mode = "v", desc = "Bumpers Rewrite" }
  }
}
```

## Usage
1. Visually select a block of code (e.g., using `v` or `V`).
2. Run `:Bump` (or your mapped keybinding like `<leader>bb`).
3. Type an instruction like *"Refactor to use async/await"* or *"Fix these LSP errors"*.
4. Watch the code rewrite itself directly in your buffer!

### Review Mode
If you prepend your instruction with `#review`, Bumpers will not rewrite your code. Instead, it will analyze your selection, file context, and LSP data to answer your question or perform a code review, displaying the result in a floating markdown popup window.
- Example: `#review is this function thread safe?`
- Example: `#review what does this do?`
