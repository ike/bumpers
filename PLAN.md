# Bumpers - Implementation Plan

## Overview
`bumpers` is a Neovim plugin that leverages advanced LLMs (Anthropic Claude 4.6 and Gemini 3.1) to intelligently rewrite visually selected code. It distinguishes itself by enriching the LLM prompt with powerful local context, specifically the entire file buffer and relevant LSP data (diagnostics and hover/type signatures) associated with the selected text.

## Core Features
1. **Model Support**: Native support for Anthropic (e.g., `claude-opus-4-6`) and Gemini (e.g., `gemini-3.1-pro-preview`) via configuration.
2. **Context-Aware Prompting**:
   - Includes the full buffer text to understand the surrounding environment.
   - Extracts LSP diagnostics (errors, warnings) overlapping with the visual selection.
   - Extracts LSP hover information (type signatures, docs) for unique tokens within the selection.
3. **Streamed Inline Replacement**: Streams the LLM response directly into the buffer, replacing the original visual selection in real-time.
4. **Single-Step Undo**: Uses Neovim's `undojoin` during the streaming process so that the entire generated rewrite can be reverted with a single press of `u`.
5. **Minimal UI**: Model selection is handled entirely via `setup()` config. The only UI element is a `vim.ui.input` prompt asking for the specific rewrite instruction.

## Directory & File Structure
```text
/Users/ike/code/personal/bumpers/
├── lua/
│   └── bumpers/
│       ├── init.lua            # Plugin entry point: handles setup(opts) and creates the main command
│       ├── config.lua          # Default configuration (models, API keys)
│       ├── visual.lua          # Utilities for extracting visual selections and buffer text
│       ├── lsp.lua             # Logic for querying and formatting LSP diagnostics and hover info
│       ├── prompt.lua          # Assembles the XML-like prompt with context, LSP data, and user instruction
│       ├── stream.lua          # Handles SSE parsing and the `undojoin` streaming insertion
│       └── providers/
│           ├── anthropic.lua   # Formats payloads/headers for Anthropic Messages API
│           └── gemini.lua      # Formats payloads/headers for Gemini GenerateContent API (v1beta)
└── PLAN.md                     # This file
```

## Implementation Phases

### Phase 1: Foundation
- Create `lua/bumpers/config.lua` to define default options (provider, model, API keys).
- Create `lua/bumpers/init.lua` to provide the `setup()` function and register a command (e.g., `:Bump`).

### Phase 2: Neovim Utilities
- Implement `lua/bumpers/visual.lua`:
  - Function to get the current visual selection's text and its start/end coordinates.
  - Function to get the full content of the current buffer.

### Phase 3: LSP Context (The "Secret Sauce")
- Implement `lua/bumpers/lsp.lua`:
  - `get_diagnostics(start_row, end_row)`: Query `vim.diagnostic.get` and filter.
  - `get_hover_info(selection_text)`: Extract tokens, deduplicate, and run synchronous `textDocument/hover` requests to gather type signatures.

### Phase 4: Prompt Engineering
- Implement `lua/bumpers/prompt.lua`:
  - Build a structured prompt (e.g., using `<file_context>`, `<lsp_diagnostics>`, `<lsp_hover_types>`, `<selection_to_rewrite>`, `<instruction>`) to send to the LLMs.
  - Add system instructions to only output raw code without markdown wrapping (so it can be directly inserted).

### Phase 5: Providers & Streaming
- Implement `lua/bumpers/stream.lua`:
  - Core logic utilizing `plenary.curl` to handle SSE streams.
  - **Undo Trick**: Delete the original selection first, then use `vim.cmd('undojoin')` before inserting each new chunk from the stream.
- Implement `lua/bumpers/providers/anthropic.lua`: Request formatter and SSE chunk parser for Claude 4.6.
- Implement `lua/bumpers/providers/gemini.lua`: Request formatter and SSE chunk parser for Gemini 3.1.

## Dependencies
- `nvim-lua/plenary.nvim` (for HTTP requests via `plenary.curl`).
