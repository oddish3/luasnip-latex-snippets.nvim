local M = {}

-- Keep track of all math-related snippet modules
-- Track which snippets we've already processed to avoid duplicates
local processed_snippets = {}

local math_snippet_modules = {
  "math_i",
  "math_iA",
  "math_wrA",
  "math_iA_no_backslash",
  "math_wA_no_backslash",
  "math_rA_no_backslash",
  "math_wRA_no_backslash",
  "greek_letters",
  "matrix"
}

-- Function to get all math-context snippets as regular snippets
M.get_math_snippets_for_completion = function(is_math)
  local ls = require("luasnip")
  local all_snippets = {}
  local init_module = require("luasnip-latex-snippets")
  
  -- Clear the processed snippets tracker for this new call
  processed_snippets = {}
  
  for _, module_name in ipairs(math_snippet_modules) do
    local ok, module = pcall(require, "luasnip-latex-snippets." .. module_name)
    if ok then
      local snippets = module.retrieve(is_math)
      for _, snippet in ipairs(snippets) do
        -- Only add if we haven't seen this trigger before
        if not processed_snippets[snippet.trigger] then
          -- Mark with math context
          snippet.context = { math = true }
          -- Register in our registry for filtering
          if init_module.register_snippet then
            init_module.register_snippet(snippet.trigger)
          end
          -- Add to our list of snippets
          table.insert(all_snippets, snippet)
          -- Mark as processed
          processed_snippets[snippet.trigger] = true
        end
      end
    end
  end
  
  -- We don't process bwA snippets here to avoid duplicates
  -- bwA snippets are handled separately in the _autosnippets function
  
  return all_snippets
end

-- Setup function to load all math snippets with proper context
M.setup_math_snippets = function(filetypes)
  local ls = require("luasnip")
  local utils = require("luasnip-latex-snippets.util.utils")
  local is_math = utils.with_opts(utils.is_math, true)
  
  -- Get all math snippets
  local math_snippets = M.get_math_snippets_for_completion(is_math)
  
  -- Add them to each filetype
  for _, ft in ipairs(filetypes) do
    ls.add_snippets(ft, math_snippets, { default_priority = 0 })
  end
end

return M