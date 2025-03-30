local M = {}

-- This module prevents friendly-snippets from working in math/code blocks

-- Store a registry of our own snippets
local our_snippet_registry = {}

-- Register a snippet as one of our own
M.register_snippet = function(trigger)
  our_snippet_registry[trigger] = true
end

-- Setup function to apply the filter
M.setup = function()
  -- Get LuaSnip
  local ls = require("luasnip")
  local latex_snippets = require("luasnip-latex-snippets")
  
  -- Original functions
  local original_expand_or_jumpable = ls.expand_or_jumpable
  local original_expandable = ls.expandable
  local original_jumpable = ls.jumpable  -- Save original jumpable function
  
  -- Check if we should preserve jumping functionality
  local should_preserve_jumps = true
  if _G.__luasnip_latex_snippets_opts and _G.__luasnip_latex_snippets_opts.preserve_jumps ~= nil then
    should_preserve_jumps = _G.__luasnip_latex_snippets_opts.preserve_jumps
  end

  -- This function checks if the current trigger would pass our filter
  local function should_allow_snippet_at_cursor()
    -- Get current context
    local in_math = latex_snippets.is_in_math()
    local in_code = latex_snippets.is_in_code_block()
    
    if not (in_math or in_code) then
      -- Outside math/code blocks, allow all
      return true
    end
    
    -- We're in math or code, extract trigger
    local line = vim.api.nvim_get_current_line()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local col = cursor[2]
    
    -- Try to extract what looks like a trigger
    local start_idx = col
    while start_idx > 0 and line:sub(start_idx, start_idx):match("[%w_]") do
      start_idx = start_idx - 1
    end
    
    -- Extract the trigger candidate
    local trigger_candidate = line:sub(start_idx + 1, col)
    
    -- In math zone
    if in_math then
      -- If this is one of our snippets and it's a math snippet, allow expansion
      if our_snippet_registry[trigger_candidate] and 
         latex_snippets.is_math_snippet(trigger_candidate, vim.bo.filetype) then
        return true
      else
        -- This is either a friendly-snippet or a non-math snippet
        return false
      end
    end
    
    -- In code block
    if in_code then
      -- Only allow mk/dm type snippets
      return trigger_candidate == "mk" or trigger_candidate == "dm" or 
             trigger_candidate == "Mk" or trigger_candidate == "Dm"
    end
    
    return false  -- Shouldn't get here
  end
  
  -- Override the expand_or_jumpable function
  ls.expand_or_jumpable = function()
    -- Check if we're in a jump sequence - if so, allow jumping
    if should_preserve_jumps and original_jumpable() then
      return true
    end
    
    -- Check if we should allow the current snippet
    if should_allow_snippet_at_cursor() then
      return original_expand_or_jumpable()
    else
      return false
    end
  end
  
  -- Also override expandable
  ls.expandable = function()
    -- Check if we should allow the current snippet
    if should_allow_snippet_at_cursor() then
      return original_expandable()
    else
      return false
    end
  end
  
  -- Preserve original jumpable function for tab navigation to work
  -- We don't modify the jumpable function at all
  
  -- Add a filter for nvim-cmp
  M.filter_completion = function(entry, ctx)
    local kind = entry:get_kind()
    local is_snippet = kind == 15 -- kinds.Snippet = 15
    
    -- If not a snippet, allow all other completion types
    if not is_snippet then
      return true
    end
    
    -- Get context information
    local in_math = latex_snippets.is_in_math()
    local in_code = latex_snippets.is_in_code_block()
    
    -- Get the snippet trigger/label
    local completion_item = entry:get_completion_item()
    local trigger = completion_item.label
    
    -- Is this one of our snippets?
    local is_our_snippet = our_snippet_registry[trigger] or false
    
    -- Is this a math snippet according to pattern matching?
    local is_math_snippet = latex_snippets.is_math_snippet(trigger, vim.bo.filetype)
    
    -- Inside math zones:
    if in_math then
      -- Show our math snippets in math zones
      if is_our_snippet then
        return is_math_snippet -- Only show our MATH snippets
      end
      -- Block friendly-snippets in math
      return false
    end
    
    -- Inside code blocks:
    if in_code then
      -- Block all snippets in code blocks, except mk/dm 
      if trigger == "mk" or trigger == "dm" or trigger == "Mk" or trigger == "Dm" then
        return true
      end
      return false
    end
    
    -- Outside math/code, allow all non-math snippets
    if is_math_snippet then
      return false
    end
    return true
  end
end

return M