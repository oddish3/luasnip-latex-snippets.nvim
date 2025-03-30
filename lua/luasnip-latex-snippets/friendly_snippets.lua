local ls = require("luasnip")
local M = {}

-- Function to apply context-aware conditions to friendly-snippets
-- This prevents them from being used in math zones or code blocks
M.setup = function()
  -- Get reference to our main module
  local latex_snippets = require("luasnip-latex-snippets")
  
  -- Create our condition function to prevent expansion in math or code blocks
  local function not_in_math_or_code()
    return not latex_snippets.is_in_math() and not latex_snippets.is_in_code_block()
  end
  
  -- Add this condition to LuaSnip
  if ls.add_condition then
    ls.add_condition("not_in_math_or_code", {
      condition = not_in_math_or_code,
      type = "always",
      desc = "Only expand outside math and code blocks",
    })
  end
  
  -- Apply this condition to all friendly-snippets (loaded from VSCode)
  -- Hook into the LuaSnip loader to modify snippets as they're loaded
  local vscode_loader = require("luasnip.loaders.from_vscode")
  local original_load = vscode_loader.load
  
  -- Override the load function to add our condition
  vscode_loader.load = function(opts)
    -- Call the original function
    original_load(opts)
    
    -- Get all loaded snippets
    local snippets = ls.get_snippets()
    
    -- Iterate through all filetypes and snippets
    for ft, ft_snippets in pairs(snippets) do
      -- Only apply to markdown/tex/quarto
      if ft == "markdown" or ft == "tex" or ft == "quarto" or ft == "latex" then
        for _, snippet in ipairs(ft_snippets) do
          -- Skip snippets that already have a condition
          if not snippet.condition then
            -- Set the condition to check for math/code
            snippet.condition = not_in_math_or_code
          end
        end
      end
    end
  end
end

return M