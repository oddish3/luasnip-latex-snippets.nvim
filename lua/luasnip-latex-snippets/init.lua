local M = {}

local default_opts = {
  use_treesitter = false,
  allow_on_markdown = true,
  ignore_code_blocks = true, -- Option to control code block detection
  register_all_snippets = false, -- Option to force registration of all snippets
  preserve_jumps = true, -- Preserve tab jumping behavior even with filtering

  -- User-defined filter callbacks
  custom_math_snippet_filter = nil, -- function(trigger, filetype) -> boolean
  custom_code_snippet_filter = nil, -- function(trigger, filetype) -> boolean
}

-- Export the in_mathzone function as a global so user configs can use it
-- This will fix the "attempt to call global 'in_mathzone'" error
_G.in_mathzone = function()
  return M.is_in_math()
end

-- Expose utility functions to check context
-- Check if cursor is in a code block
M.is_in_code_block = function()
  local utils = require("luasnip-latex-snippets.util.utils")
  return utils.block_expansion()
end

-- Check if cursor is in a math zone
M.is_in_math = function()
  local utils = require("luasnip-latex-snippets.util.utils")
  -- Use treesitter by default for this public API
  return utils.is_math(true)
end

-- Keep a registry of known snippets from our plugin
local math_snippet_registry = {}

-- Helper for nvim-cmp to check if a snippet is a math snippet
M.is_math_snippet = function(trigger, filetype)
  -- First check our registry of known math snippets
  if math_snippet_registry[trigger] then
    return true
  end

  -- If user provided a custom filter, check it first
  if
    _G.__luasnip_latex_snippets_opts and _G.__luasnip_latex_snippets_opts.custom_math_snippet_filter
  then
    local user_result =
      _G.__luasnip_latex_snippets_opts.custom_math_snippet_filter(trigger, filetype)
    if user_result ~= nil then
      return user_result
    end
  end

  -- Common patterns for math snippets
  if
    trigger
    and (
            -- Greek letters
(trigger:match("^%u%u$") and not trigger:match("^ID$"))
      -- Common math operators 
      or trigger:match("^[<>=!].")
      -- Math decorators
      or trigger:match("bar$")
      or trigger:match("hat$")
      or trigger:match("dot$")
      -- Math functions
      or trigger:match("^\\%a+$")
      -- Other common math symbols
      or trigger:match("^[*/+-]$")
      or trigger == "**"
      or trigger == "//"
      or trigger == "ooo" -- infinity
      or trigger == "lll" -- ell
      -- Fraction
      or trigger == "td"
      or trigger == "rd"
      or trigger == "cb"
      or trigger == "sr"
      -- Letters with subscripts
      or trigger:match("^[xy][inj][inj]$")
      -- Matrix-related
      or trigger:match("^[bp]?mat")
      or trigger:match("^vmat")
      -- Greek letters triggers
      or trigger:match("^;%a+$")
      -- Common math symbols
      or trigger == "EE"
      or trigger == "AA"
      or trigger == "norm"
      or trigger == ".."
      or trigger == "!>"
      or trigger == "iff"
      -- Math sets
      or trigger == "RR"
      or trigger == "QQ"
      or trigger == "ZZ"
      or trigger == "NN"
      or trigger == "DD"
      or trigger == "HH"
      or trigger == "set"
      or trigger == "fun"
      or trigger == "abs"
      or trigger == "arcsin"
      or trigger == "arctan"
      or trigger == "arcsec"
      or trigger == "asin"
      or trigger == "atan"
      or trigger == "asec"
      or trigger == "..."
      or trigger == "(varepsilon)"
      or trigger == "(varphi)"
      or trigger == "(varrho)"
      or trigger == "(vartheta)"
      or trigger == "(alpha)"
      or trigger == "(Alpha)"
      or trigger == "(beta)"
      or trigger == "(Beta)"
      or trigger == "(chi)"
      or trigger == "(Chi)"
      or trigger == "(delta)"
      or trigger == "(Delta)"
      or trigger == "(epsilon)"
      or trigger == "(Epsilon)"
      or trigger == "(gamma)"
      or trigger == "(Gamma)"
      or trigger == "(iota)"
      or trigger == "(Iota)"
      or trigger == "(kappa)"
      or trigger == "(Kappa)"
      or trigger == "(lambda)"
      or trigger == "(Lambda)"
      or trigger == "(mu)"
      or trigger == "(Mu)"
      or trigger == "(nu)"
      or trigger == "(Nu)"
      or trigger == "(omega)"
      or trigger == "(Omega)"
      or trigger == "(phi)"
      or trigger == "(Phi)"
      or trigger == "(pi)"
      or trigger == "(Pi)"
      or trigger == "(psi)"
      or trigger == "(Psi)"
      or trigger == "(rho)"
      or trigger == "(Rho)"
      or trigger == "(sigma)"
      or trigger == "(Sigma)"
      or trigger == "(tau)"
      or trigger == "(Tau)"
      or trigger == "(theta)"
      or trigger == "(Theta)"
      or trigger == "(zeta)"
      or trigger == "(Zeta)"
      or trigger == "(eta)"
      or trigger == "(Eta)"
      or trigger == "(sin)"
      or trigger == "(cos)"
      or trigger == "(tan)"
      or trigger == "(csc)"
      or trigger == "(sec)"
      or trigger == "(cot)"
      or trigger == "(ln)"
      or trigger == "(log)"
      or trigger == "(exp)"
      or trigger == "(star)"
      or trigger == "(perp)"
      or trigger == "(int)"
      or trigger == "(q?quad)"
    )
  then
    return true
  end

  -- For friendly-snippets, block their math snippets outside math mode
  -- and block their non-math snippets inside math mode
  if filetype == "tex" or filetype == "markdown" or filetype == "quarto" then
    -- Block common math commands outside math mode and vice versa
    if trigger:match("^[\\]") then
      -- TeX commands are generally math related
      return true
    end
  end

  return false
end

-- Function to register snippets as belonging to our plugin
M.register_snippet = function(trigger, is_math)
  if is_math then
    math_snippet_registry[trigger] = true
  end
--   -- print(string.format("[DEBUG] Registering snippet: %s | is_math: %s", trigger, tostring(is_math)))
  local friendly_filter = require("luasnip-latex-snippets.friendly_snippets_filter")
  friendly_filter.register_snippet(trigger, is_math)
end

-- Public filter_completion function that user configs will call
M.filter_completion = function(entry, ctx)
  -- Lazy load the filter module
  local filter_module = require("luasnip-latex-snippets.friendly_snippets_filter")

  -- Use the enhanced filter_completion from the filter module
  -- This includes additional checks to prevent math snippets appearing outside math
  return filter_module.filter_completion(entry, ctx)
end

-- Get detailed context information
M.get_context = function()
  local utils = require("luasnip-latex-snippets.util.utils")
  local ts_utils = require("luasnip-latex-snippets.util.ts_utils")

  return {
    in_code_block = utils.block_expansion(),
    in_math = utils.is_math(true),
    in_text = utils.not_math(true),
    ts_in_mathzone = ts_utils.in_mathzone(),
    ts_in_text = ts_utils.in_text(),
    ts_in_code_block = ts_utils.in_code_block(),
  }
end

M.setup = function(opts)
  opts = vim.tbl_deep_extend("force", default_opts, opts or {})

  -- Add filetype association for qmd files if not already set
  vim.filetype.add({
    extension = {
      qmd = "quarto",
    },
  })

  -- Make options available globally for condition functions
  _G.__luasnip_latex_snippets_opts = opts

  -- Clear existing registry
  our_snippet_triggers = {}
  math_snippet_registry = {}

  -- Set up the friendly snippets filter to prevent expansion and completion in math/code
  require("luasnip-latex-snippets.friendly_snippets_filter").setup()

  local augroup = vim.api.nvim_create_augroup("luasnip-latex-snippets", {})
  -- vim.api.nvim_create_autocmd("FileType", {
  --   pattern = "tex",
  --   group = augroup,
  --   once = true,
  --   callback = function()
  --     local utils = require("luasnip-latex-snippets.util.utils")
  --     local is_math = utils.with_opts(utils.is_math, opts.use_treesitter)
  --     local not_math = utils.with_opts(utils.not_math, opts.use_treesitter)
  --     M.setup_tex(is_math, not_math)
  --   end,
  -- })

  if opts.allow_on_markdown then
    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "markdown", "quarto" },
      group = augroup,
      once = true,
      callback = function()
        M.setup_markdown()
      end,
    })
  end
end

local _autosnippets = function(is_math, not_math)
  local autosnippets = {}

  -- Math-related snippets - uncomment modules to test as autosnippets
--   -- print("[DEBUG] Setting up autosnippets...")
  local math_modules = {
    "math_i",
    -- "math_iA",
    -- "math_wrA",
    -- "math_iA_no_backslash",
    -- "math_wA_no_backslash",
    -- "math_rA_no_backslash",
    -- "math_wRA_no_backslash",
    -- "greek_letters",
    -- "bwA",
    -- "matrix",
  }

  if #math_modules > 0 then
--     -- print("[DEBUG] Will try these modules as autosnippets: " .. table.concat(math_modules, ", "))
  else
--     -- print("[DEBUG] No math modules enabled for autosnippets")
  end

  -- Load math snippets and mark them with context
  for _, module_name in ipairs(math_modules) do
--     -- print("[DEBUG] Loading autosnippet module: " .. module_name)
    local ok, module = pcall(require, "luasnip-latex-snippets." .. module_name)
    if ok then
--       -- print("[DEBUG] Successfully loaded autosnippet module: " .. module_name)
      local snippets = module.retrieve(is_math)
--       -- print("[DEBUG] Got " .. #snippets .. " autosnippets from " .. module_name)

      -- Mark all snippets with math context for filtering
      for _, snippet in ipairs(snippets) do
        snippet.context = { math = true }

        -- Also make sure condition function is properly set
        if not snippet.condition_func then
          local utils = require("luasnip-latex-snippets.util.utils")
          snippet.condition = function(line_to_cursor, matched_trigger, captures)
            -- Only expand in math zones
            return is_math() and not utils.block_expansion()
          end
        end
      end
      vim.list_extend(autosnippets, snippets)
    else
--       print("[ERROR] Failed to load autosnippet module: " .. module_name)
--       print("Error details: " .. tostring(module))
    end
  end

  -- Regular snippets that can be in math or outside it
  local autosnippets = {}
--   print("--- Initializing snippet loading (Revised Logic) ---")

  -- Define which sources provide snippets for which context
  local math_sources = { "bwA" } -- Add other math-only sources here
  -- local non_math_sources = { "wA" } -- Add other non-math sources here

  -- Process Math Snippets
--   print("\n--- Loading MATH snippets ---")
  for _, source_name in ipairs(math_sources) do
    local module_name = ("luasnip-latex-snippets.%s"):format(source_name)
--     print(string.format("Processing source: %s (Context: is_math)", source_name))
--     print("Attempting to require module:", module_name)
    local success, module = pcall(require, module_name)

    if not success or not module or not module.retrieve then
      -- print(
      --   string.format(
      --     "ERROR: Failed to require or find retrieve function in module: %s - %s",
      --     module_name,
      --     module or "require failed"
      --   )
      -- )
    else
--       print("Successfully required module:", module_name)
--       print("Retrieving snippets with is_math condition...")
      -- Call retrieve ONCE, passing is_math. Conditions are now handled inside retrieve.
      local retrieved_snippets = module.retrieve(is_math)
--       print("Retrieved snippets count:", #retrieved_snippets)
      -- Optional: Print triggers
      for j, snippet in ipairs(retrieved_snippets) do
        local trigger_str = snippet.trigger or "N/A"
--         print(string.format("  Loaded math snippet #%d (Trigger: %s)", j, tostring(trigger_str)))
      end
      vim.list_extend(autosnippets, retrieved_snippets)
--       print("Current autosnippets count:", #autosnippets)
    end
  end

--   print("\n--- Snippet loading finished ---")
--   print("Final autosnippets count:", #autosnippets)
  return autosnippets
end

-- M.setup_tex = function(is_math, not_math)
--   local ls = require("luasnip")
--   ls.add_snippets("tex", {
--     ls.parser.parse_snippet(
--       { trig = "pac", name = "Package" },
--       "\\usepackage[${1:options}]{${2:package}}$0"
--     ),
--
--     -- ls.parser.parse_snippet({ trig = "nn", name = "Tikz node" }, {
--     --   "$0",
--     --   -- "\\node[$5] (${1/[^0-9a-zA-Z]//g}${2}) ${3:at (${4:0,0}) }{$${1}$};",
--     --   "\\node[$5] (${1}${2}) ${3:at (${4:0,0}) }{$${1}$};",
--     -- }),
--   })
-- end

-- Add a LuaSnip condition that directly checks if we're in a code block
local function create_code_block_condition()
  local utils = require("luasnip-latex-snippets.util.utils")
  return {
    condition = function()
      if
        _G.__luasnip_latex_snippets_opts and _G.__luasnip_latex_snippets_opts.ignore_code_blocks
      then
        -- Return true if we're NOT in a code block (to allow expansion)
        return not utils.block_expansion()
      end
      return true -- Default to allowing expansion
    end,
    type = "always",
    desc = "Only expand outside code blocks",
  }
end

M.setup_markdown = function()
  local ls = require("luasnip")
  local utils = require("luasnip-latex-snippets.util.utils")
  local pipe = utils.pipe

  -- Register condition for code block detection
  if ls.add_condition then
    ls.add_condition("not_in_code_block", create_code_block_condition())
  end

  local is_math = utils.with_opts(utils.is_math, true)
  local not_math = utils.with_opts(utils.not_math, true)

  -- Force treesitter-based math detection which is more reliable
  _G.__luasnip_latex_snippets_opts = _G.__luasnip_latex_snippets_opts or {}
  _G.__luasnip_latex_snippets_opts.use_treesitter = true

  -- Initialize tracker for loaded modules
  _G.__loaded_snippet_modules = _G.__loaded_snippet_modules or {}

  -- List all the modules you want to test here
--   print("[DEBUG] Loading math snippet modules...")
  local modules_to_test = {
    -- "math_i",
    -- "math_iA",
    -- "math_wrA",
    -- "math_iA_no_backslash",
    -- "math_wA_no_backslash",
    -- "math_rA_no_backslash",
    -- "math_wRA_no_backslash",
    -- "greek_letters",
    -- "matrix",
  }

--   print("[DEBUG] Will try to load: " .. table.concat(modules_to_test, ", "))

  -- Try loading each module and adding its snippets
  for _, module_name in ipairs(modules_to_test) do
    local ok, module = pcall(require, "luasnip-latex-snippets." .. module_name)
    if ok then
--       print("[DEBUG] Successfully loaded module: " .. module_name)

      -- Mark this module as loaded
      _G.__loaded_snippet_modules[module_name] = true

      local snippets = module.retrieve(is_math)
--       print("[DEBUG] Got " .. #snippets .. " snippets from " .. module_name)

      -- Make sure the proper condition is set
      for _, snippet in ipairs(snippets) do
        -- Ensure snippets have consistent condition function that uses treesitter
        snippet.condition = function()
          return utils.is_math(true) and not utils.block_expansion()
        end
      end

      -- Add these to both markdown and quarto files
      ls.add_snippets("markdown", snippets, { default_priority = 0 })
      ls.add_snippets("quarto", snippets, { default_priority = 0 })

      -- Register each snippet with our filtering system
      local count = 0
      for _, snippet in ipairs(snippets) do
        if snippet.trigger then
          if count < 5 then -- Only print the first 5 to avoid flooding
--             print(string.format("[DEBUG] Added snippet from %s: %s", module_name, snippet.trigger))
            count = count + 1
          end

          M.register_snippet(snippet.trigger, true)
        end
      end
--       print(string.format("[DEBUG] Registered %d snippets from %s", count, module_name))
    else
--       print("[ERROR] Failed to load module: " .. module_name)
--       print("Error details: " .. tostring(module))
    end
  end

  -- First collect autosnippets with the regular pattern
  local autosnippets = _autosnippets(is_math, not_math)
  -- local trigger_of_snip = function(s)
  --   return s.trigger
  -- end

  local to_filter = {}
  -- for _, str in ipairs({
  --   "wA",
  --    "bwA",
  -- }) do
  --   local t = require(("luasnip-latex-snippets.%s"):format(str)).retrieve(not_math)
  --   vim.list_extend(to_filter, vim.tbl_map(trigger_of_snip, t))
  -- end

  local filtered = vim.tbl_filter(function(s)
    return not vim.tbl_contains(to_filter, s.trigger)
  end, autosnippets)

  -- tex delimiters - these are special and should always be available
  local normal_wA_tex = {}

  -- Ensure all math delimiter snippets are properly defined with code block prevention
  normal_wA_tex[#normal_wA_tex + 1] = ls.snippet({
    trig = "mk",
    name = "Math",
    snippetType = "autosnippet",
    condition = function()
      return not utils.block_expansion()
    end,
  }, { ls.text_node("$"), ls.insert_node(1), ls.text_node("$") })

  normal_wA_tex[#normal_wA_tex + 1] = ls.snippet({
    trig = "dm",
    name = "Block Math",
    snippetType = "autosnippet",
    condition = function()
      return not utils.block_expansion()
    end,
  }, { ls.text_node({ "$$", "\t" }), ls.insert_node(1), ls.text_node({ "", "$$" }) })

  normal_wA_tex[#normal_wA_tex + 1] = ls.snippet({
    trig = "Mk",
    name = "Math",
    snippetType = "autosnippet",
    condition = function()
      return not utils.block_expansion()
    end,
  }, { ls.text_node("$"), ls.insert_node(1), ls.text_node("$") })

  normal_wA_tex[#normal_wA_tex + 1] = ls.snippet({
    trig = "Dm",
    name = "Block Math",
    snippetType = "autosnippet",
    condition = function()
      return not utils.block_expansion()
    end,
  }, { ls.text_node({ "$$", "\t" }), ls.insert_node(1), ls.text_node({ "", "$$" }) })
  vim.list_extend(filtered, normal_wA_tex)

  -- Apply condition to each snippet to prevent code block expansion
  if _G.__luasnip_latex_snippets_opts and _G.__luasnip_latex_snippets_opts.ignore_code_blocks then
    for _, snippet in ipairs(filtered) do
      if not snippet.condition_func then
        snippet.condition = function(line_to_cursor, matched_trigger, captures)
          -- Block expansion in code blocks
          if utils.block_expansion() then
            return false
          end
          -- Original condition if it exists
          if snippet.condition_func then
            return snippet.condition_func(line_to_cursor, matched_trigger, captures)
          end
          return true
        end
      end
    end
  end

  ls.add_snippets("markdown", filtered, {
    type = "autosnippets",
    default_priority = 0,
  })

  -- Also add the snippets for quarto filetype
  ls.add_snippets("quarto", filtered, {
    type = "autosnippets",
    default_priority = 0,
  })
end

return M

