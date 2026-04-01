local visual = require("bumpers.visual")
local lsp = require("bumpers.lsp")

local M = {}

---Assembles the prompt containing context, diagnostics, types, and the instruction
---@param instruction string The user's rewrite instruction
---@return string System prompt
---@return string User prompt
function M.build(instruction)
  local selection = visual.get_visual_selection()
  if not selection then
    error("No visual selection found.")
  end

  local buffer_content = visual.get_buffer_context()
  local diagnostics = lsp.get_diagnostics(selection.start_row, selection.end_row)
  
  -- Gather hover info
  local hover_info = lsp.get_hover_info(
    selection.start_row, selection.start_col,
    selection.end_row, selection.end_col
  )

  local system_prompt = [[
You are an expert software engineer. Your task is to rewrite the provided code snippet exactly as instructed.
You will be provided with:
- The full file context.
- LSP diagnostics (errors/warnings) overlapping with the selection.
- LSP hover information (types and docs) for tokens in the selection.
- The user's specific rewrite instruction.
- The specific selection of code to rewrite.

IMPORTANT:
- Return ONLY the raw code replacement.
- DO NOT wrap the response in markdown blocks (e.g., no ```lua ... ```).
- DO NOT explain the code or add conversation.
- Output MUST be immediately drop-in ready to replace the selection.
]]

  local user_prompt = string.format([[
<instruction>
%s
</instruction>

<file_context>
%s
</file_context>

<lsp_diagnostics>
%s
</lsp_diagnostics>

<lsp_hover_types>
%s
</lsp_hover_types>

<selection_to_rewrite>
%s
</selection_to_rewrite>
]], instruction, buffer_content, diagnostics, hover_info, selection.text)

  return system_prompt, user_prompt, selection
end

return M
