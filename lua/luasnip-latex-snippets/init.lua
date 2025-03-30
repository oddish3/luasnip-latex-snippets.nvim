local M = {}

local default_opts = {
	use_treesitter = false,
	allow_on_markdown = true,
	ignore_code_blocks = true, -- Option to control code block detection
	register_all_snippets = false, -- Option to force registration of all snippets
	preserve_jumps = true, -- Preserve tab jumping behavior even with filtering
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
local our_snippet_triggers = {}
local math_snippet_registry = {}

-- Helper for nvim-cmp to check if a snippet is a math snippet
M.is_math_snippet = function(trigger, filetype)
  -- First check our registry of known math snippets
  if math_snippet_registry[trigger] then
    return true
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
  our_snippet_triggers[trigger] = true
  
  -- If this is a math snippet, add it to the math registry
  if is_math then
    math_snippet_registry[trigger] = true
  end
end

-- Force register specific snippets we know should be included
local function force_register_known_snippets()
  -- Greek letters
  local greek_prefixes = {"", "v"}
  local greek_letters = {
    "alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta",
    "iota", "kappa", "lambda", "mu", "nu", "xi", "pi", "rho", "sigma", 
    "tau", "upsilon", "phi", "chi", "psi", "omega"
  }
  
  for _, prefix in ipairs(greek_prefixes) do
    for _, letter in ipairs(greek_letters) do
      local trigger = ";" .. prefix .. letter:sub(1, 1)
      M.register_snippet(trigger, true)
      -- Also register uppercase version
      local upper_trigger = ";" .. prefix .. letter:sub(1, 1):upper()
      M.register_snippet(upper_trigger, true)
    end
  end
  
  -- Common math decorators
  local decorators = {"bar", "hat", "dot", "und", "ora", "ola"}
  for _, dec in ipairs(decorators) do
    M.register_snippet("a" .. dec, true)
    M.register_snippet("b" .. dec, true)
    M.register_snippet("x" .. dec, true)
    M.register_snippet("y" .. dec, true)
  end
  
  -- Common math operators
  local operators = {"EE", "AA", "RR", "ZZ", "NN", "QQ", "DD", "HH", "ooo", "lll", "td", "rd", "cb", "sr"}
  for _, op in ipairs(operators) do
    M.register_snippet(op, true)
  end
  
  -- Register begin/end snippets for bwA
  M.register_snippet("ali", false)
  M.register_snippet("beg", false)
  M.register_snippet("case", false)
  M.register_snippet("bigfun", false)
end

-- Function to initialize snippet registry from our modules
M.initialize_snippet_registry = function(opts)
  opts = opts or _G.__luasnip_latex_snippets_opts or default_opts
  
  -- Clear existing registry
  our_snippet_triggers = {}
  math_snippet_registry = {}
  
  -- Get a list of triggers from all our snippet modules
  local context_helper = require("luasnip-latex-snippets.util.context_helper")
  local utils = require("luasnip-latex-snippets.util.utils")
  local is_math = utils.with_opts(utils.is_math, opts.use_treesitter)
  local not_math = utils.with_opts(utils.not_math, opts.use_treesitter)
  
  -- First register known snippets that we know should be registered
  force_register_known_snippets()
  
  -- Get all math snippets
  local all_snippets = context_helper.get_math_snippets_for_completion(is_math)
  
  -- Get snippets from all modules if forced registration is enabled
  local modules = {
    "math_i",
    "math_iA",
    "math_wrA",
    "math_iA_no_backslash",
    "math_wA_no_backslash",
    "math_rA_no_backslash",
    "math_wRA_no_backslash",
    "greek_letters",
    "matrix",
    "wA",
    "bwA",
  }
  
  -- Register all snippet modules
  for _, module_name in ipairs(modules) do
    local ok, module = pcall(require, "luasnip-latex-snippets." .. module_name)
    if ok then
      -- Try to get snippets with both math and non-math conditions to register all
      local snippets = {}
      
      -- Get snippets with math condition
      pcall(function()
        local math_snippets = module.retrieve(is_math)
        vim.list_extend(snippets, math_snippets)
        
        -- Mark these as math snippets
        for _, snippet in ipairs(math_snippets) do
          if snippet.trigger then
            M.register_snippet(snippet.trigger, true)
          end
        end
      end)
      
      -- Also try with not_math condition for modules that support it
      pcall(function()
        local non_math_snippets = module.retrieve(not_math)
        vim.list_extend(snippets, non_math_snippets)
        
        -- Register these as non-math snippets
        for _, snippet in ipairs(non_math_snippets) do
          if snippet.trigger then
            M.register_snippet(snippet.trigger, false)
          end
        end
      end)
    end
  end
  
  -- Register all snippet triggers from all_snippets as well
  for _, snippet in ipairs(all_snippets) do
    if snippet.trigger then
      M.register_snippet(snippet.trigger, true)
    end
  end
end

-- Function to filter completions for nvim-cmp
M.filter_completion = function(entry, ctx)
  local kind = entry:get_kind()
  local is_snippet = kind == 15 -- kinds.Snippet = 15
  
  if not is_snippet then return true end
  
  local completion_item = entry:get_completion_item()
  local trigger = completion_item.label
  
  -- Check if we're in a math zone
  if M.is_in_math() then
    -- In math zone, only show math snippets
    return M.is_math_snippet(trigger, vim.bo.filetype)
  elseif M.is_in_code_block() then
    -- In code block, only show mk/dm type snippets
    return trigger == "mk" or trigger == "dm" or trigger == "Mk" or trigger == "Dm"
  else
    -- Outside math/code, don't show math snippets
    return not M.is_math_snippet(trigger, vim.bo.filetype)
  end
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
  
  -- Initialize our snippet registry for the filter_completion function
  M.initialize_snippet_registry(opts)
  
  -- Also register all snippets with the friendly-snippets filter
  local friendly_filter = require("luasnip-latex-snippets.friendly_snippets_filter")
  for trigger, _ in pairs(our_snippet_triggers) do
    friendly_filter.register_snippet(trigger)
  end
  
  -- Set up the friendly snippets filter to prevent expansion and completion in math/code
  require("luasnip-latex-snippets.friendly_snippets_filter").setup()

  local augroup = vim.api.nvim_create_augroup("luasnip-latex-snippets", {})
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "tex",
    group = augroup,
    once = true,
    callback = function()
      local utils = require("luasnip-latex-snippets.util.utils")
      local is_math = utils.with_opts(utils.is_math, opts.use_treesitter)
      local not_math = utils.with_opts(utils.not_math, opts.use_treesitter)
      M.setup_tex(is_math, not_math)
    end,
  })

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

  -- Math-related snippets
  local math_modules = {
    "math_wRA_no_backslash",
    "math_rA_no_backslash",
    "math_wA_no_backslash",
    "math_iA_no_backslash",
    "math_iA",
    "math_wrA",
    "greek_letters",
    "matrix"
  }

  -- Load math snippets and mark them with context
  for _, s in ipairs(math_modules) do
    local snippets = require(("luasnip-latex-snippets.%s"):format(s)).retrieve(is_math)
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
  end

  -- Regular snippets that can be in math or outside it
  for _, s in ipairs({
    "wA",
    "bwA",
  }) do
    -- Math context
    local math_snippets = require(("luasnip-latex-snippets.%s"):format(s)).retrieve(is_math)
    for _, snippet in ipairs(math_snippets) do
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
    vim.list_extend(autosnippets, math_snippets)

    -- Non-math context (no need to mark these)
    local non_math_snippets = require(("luasnip-latex-snippets.%s"):format(s)).retrieve(not_math)
    for _, snippet in ipairs(non_math_snippets) do
      -- Also make sure condition function is properly set
      if not snippet.condition_func then
        local utils = require("luasnip-latex-snippets.util.utils")
        snippet.condition = function(line_to_cursor, matched_trigger, captures)
          -- Only expand outside math zones and code blocks
          return not_math() and not utils.block_expansion()
        end
      end
    end
    vim.list_extend(autosnippets, non_math_snippets)
  end

  return autosnippets
end

M.setup_tex = function(is_math, not_math)
  local ls = require("luasnip")
  ls.add_snippets("tex", {
    ls.parser.parse_snippet(
      { trig = "pac", name = "Package" },
      "\\usepackage[${1:options}]{${2:package}}$0"
    ),

    -- ls.parser.parse_snippet({ trig = "nn", name = "Tikz node" }, {
    --   "$0",
    --   -- "\\node[$5] (${1/[^0-9a-zA-Z]//g}${2}) ${3:at (${4:0,0}) }{$${1}$};",
    --   "\\node[$5] (${1}${2}) ${3:at (${4:0,0}) }{$${1}$};",
    -- }),
  })

  local math_i = require("luasnip-latex-snippets/math_i").retrieve(is_math)

  ls.add_snippets("tex", math_i, { default_priority = 0 })

  ls.add_snippets("tex", _autosnippets(is_math, not_math), {
    type = "autosnippets",
    default_priority = 0,
  })
end

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
  local context_helper = require("luasnip-latex-snippets.util.context_helper")
  local pipe = utils.pipe

  -- Register condition for code block detection
  if ls.add_condition then
    ls.add_condition("not_in_code_block", create_code_block_condition())
  end

  local is_math = utils.with_opts(utils.is_math, true)
  local not_math = utils.with_opts(utils.not_math, true)

  -- Get ALL math snippets from all modules for completions
  local all_math_snippets = context_helper.get_math_snippets_for_completion(is_math)

  -- Add all math snippets as regular snippets to be available in completions
  ls.add_snippets("markdown", all_math_snippets, { default_priority = 0 })
  ls.add_snippets("quarto", all_math_snippets, { default_priority = 0 })
  
  -- Also specially add the bwA snippets
  local bwA_snippets = require("luasnip-latex-snippets.bwA").retrieve(not_math)
  ls.add_snippets("markdown", bwA_snippets, { default_priority = 0 })
  ls.add_snippets("quarto", bwA_snippets, { default_priority = 0 })

  -- First collect autosnippets with the regular pattern
  local autosnippets = _autosnippets(is_math, not_math)
  local trigger_of_snip = function(s)
    return s.trigger
  end

  local to_filter = {}
  for _, str in ipairs({
    "wA",
    "bwA",
  }) do
    local t = require(("luasnip-latex-snippets.%s"):format(str)).retrieve(not_math)
    vim.list_extend(to_filter, vim.tbl_map(trigger_of_snip, t))
  end

  local filtered = vim.tbl_filter(function(s)
    return not vim.tbl_contains(to_filter, s.trigger)
  end, autosnippets)

  local parse_snippet = ls.extend_decorator.apply(ls.parser.parse_snippet, {
    condition = pipe({ not_math }),
  }) --[[@as function]]

  -- tex delimiters
  local normal_wA_tex = {
    parse_snippet({ trig = "mk", name = "Math" }, "$${1:${TM_SELECTED_TEXT}}$"),
    parse_snippet({ trig = "dm", name = "Block Math" }, "$$\n\t${1:${TM_SELECTED_TEXT}}\n$$"),
    parse_snippet({ trig = "Mk", name = "Math" }, "$${1:${TM_SELECTED_TEXT}}$"),
    parse_snippet({ trig = "Dm", name = "Block Math" }, "$$\n\t${1:${TM_SELECTED_TEXT}}\n$$"),
  }
  vim.list_extend(filtered, normal_wA_tex)

  -- Apply condition to each snippet to prevent code block expansion
  if _G.__luasnip_latex_snippets_opts and _G.__luasnip_latex_snippets_opts.ignore_code_blocks then
    for _, snippet in ipairs(filtered) do
      if not snippet.condition_func then
        local utils = require("luasnip-latex-snippets.util.utils")
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
