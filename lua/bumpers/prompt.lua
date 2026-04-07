local visual = require("bumpers.visual")
local lsp = require("bumpers.lsp")

local M = {}

---Assembles the prompt containing context, diagnostics, types, and the instruction
---@param instruction string The user's rewrite or review instruction
---@param mode string The mode, either "rewrite" or "review"
---@param include_buffers boolean Whether to include other visible buffers
---@return string System prompt
---@return string User prompt
---@return table Selection table
function M.build(instruction, mode, include_buffers)
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

  local other_buffers_context = ""
  if include_buffers then
    other_buffers_context = string.format([[

<other_visible_files_context>
%s
</other_visible_files_context>]], visual.get_open_buffers_context())
  end

  local system_prompt
  if mode == "review" then
    system_prompt = [[
You are an expert software engineer. Your task is to review the provided code snippet exactly as instructed.
You will be provided with:
- The full file context.
- LSP diagnostics (errors/warnings) overlapping with the selection.
- LSP hover information (types and docs) for tokens in the selection.
- The user's specific review instruction.
- The specific selection of code to review.
- (Optional) Context from other visible files in the editor.

IMPORTANT:
- Return a helpful, concise code review using standard Markdown.
- Focus directly on answering the user's instruction or questions.
- If suggesting code, use standard Markdown code blocks.
- Keep it relatively brief, as this will be displayed in a popup window.
]]
  else
    system_prompt = [[
You are an expert software engineer. Your task is to rewrite the provided code snippet exactly as instructed.
You will be provided with:
- The full file context.
- LSP diagnostics (errors/warnings) overlapping with the selection.
- LSP hover information (types and docs) for tokens in the selection.
- The user's specific rewrite instruction.
- The specific selection of code to rewrite.
- (Optional) Context from other visible files in the editor.

IMPORTANT:
- Return ONLY the raw code replacement.
- DO NOT wrap the response in markdown blocks (e.g., no ```lua ... ```).
- DO NOT explain the code or add conversation.
- Output MUST be immediately drop-in ready to replace the selection.
]]
  end

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
</lsp_hover_types>%s

<selection_to_process>
%s
</selection_to_process>
]], instruction, buffer_content, diagnostics, hover_info, other_buffers_context, selection.text)

  return system_prompt, user_prompt, selection
end

return M
