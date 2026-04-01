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

### Neovim 0.12+ (Built-in `vim.pack`)

If you are using Neovim 0.12 or newer, you can use the native package manager:

```lua
-- Add plenary dependency
vim.pack.add({ "nvim-lua/plenary.nvim" })

-- Add bumpers from your local directory (or GitHub URL when published)
vim.pack.add({ 
  {
    "ike/bumpers",
    -- If testing locally, override the src path to point to your directory:
    -- src = "/Users/ike/code/personal/bumpers",
    config = function()
      require("bumpers").setup({
        provider = "anthropic",
        model = "claude-opus-4-6", 
        api_keys = {
          anthropic = os.getenv("ANTHROPIC_API_KEY"),
          gemini = os.getenv("GEMINI_API_KEY"),
        },
        lsp_timeout_ms = 1000,
      })
      
      -- Map your trigger key
      vim.keymap.set("v", "<leader>bb", ":Bump<CR>", { desc = "Bumpers Rewrite" })
    end
  }
})
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
