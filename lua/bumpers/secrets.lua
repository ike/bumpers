local patterns = require("bumpers.patterns")

local M = {}

---Calculates Shannon entropy of a string
---@param str string
---@return number
function M.calculate_entropy(str)
  if not str or #str == 0 then return 0 end
  
  local counts = {}
  local len = #str
  
  for i = 1, len do
    local char = string.sub(str, i, i)
    counts[char] = (counts[char] or 0) + 1
  end
  
  local entropy = 0
  for _, count in pairs(counts) do
    local p = count / len
    -- Using math.log(p) / math.log(2) for base 2 logarithm
    entropy = entropy - (p * (math.log(p) / math.log(2)))
  end
  
  return entropy
end

---Obfuscates secrets based on patterns and high entropy
---@param text string
---@return string
function M.obfuscate(text)
  if not text or text == "" then
    return text
  end

  local result = text

  -- Pass 1: Pattern matching via vim.fn.substitute
  for _, pattern in ipairs(patterns.secrets) do
    result = vim.fn.substitute(result, pattern, "[REDACTED_SECRET]", "g")
  end

  -- Pass 2: Entropy matching
  -- We look for contiguous alphanumeric strings (+ some symbols like _ and -) longer than 20 chars
  result = string.gsub(result, "[a-zA-Z0-9_-]+", function(word)
    if #word > 20 then
      local entropy = M.calculate_entropy(word)
      if entropy > 4.5 then
        return "[REDACTED_ENTROPY]"
      end
    end
    return word
  end)

  return result
end

return M
