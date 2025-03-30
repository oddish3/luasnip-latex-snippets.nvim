local M = {}

local default_opts = {
  use_treesitter = false,
  allow_on_markdown = true,
  ignore_code_blocks = true, -- New option to control code block detection
}

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
    ts_in_code_block = ts_utils.in_code_block()
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
      pattern = {"markdown", "quarto"},
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

  for _, s in ipairs({
    "math_wRA_no_backslash",
    "math_rA_no_backslash",
    "math_wA_no_backslash",
    "math_iA_no_backslash",
    "math_iA",
    "math_wrA",
    "greek_letters",
    "matrix",
    "wA",
    "bwA",
  }) do
    vim.list_extend(
      autosnippets,
      require(("luasnip-latex-snippets.%s"):format(s)).retrieve(is_math)
    )
  end

  for _, s in ipairs({
    "wA",
    "bwA",
  }) do
    vim.list_extend(
      autosnippets,
      require(("luasnip-latex-snippets.%s"):format(s)).retrieve(not_math)
    )
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
      if _G.__luasnip_latex_snippets_opts and _G.__luasnip_latex_snippets_opts.ignore_code_blocks then
        -- Return true if we're NOT in a code block (to allow expansion)
        return not utils.block_expansion()
      end
      return true -- Default to allowing expansion
    end,
    type = "always",
    desc = "Only expand outside code blocks"
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

  -- Load all math-related snippets as regular snippets for completion
  local math_i = require("luasnip-latex-snippets/math_i").retrieve(is_math)
  local math_iA = require("luasnip-latex-snippets/math_iA").retrieve(is_math)
  local math_wrA = require("luasnip-latex-snippets/math_wrA").retrieve(is_math)
  local math_iA_no_backslash = require("luasnip-latex-snippets/math_iA_no_backslash").retrieve(is_math)
  local math_wA_no_backslash = require("luasnip-latex-snippets/math_wA_no_backslash").retrieve(is_math)
  local math_rA_no_backslash = require("luasnip-latex-snippets/math_rA_no_backslash").retrieve(is_math)
  local math_wRA_no_backslash = require("luasnip-latex-snippets/math_wRA_no_backslash").retrieve(is_math)
  local greek_letters = require("luasnip-latex-snippets/greek_letters").retrieve(is_math)
  local matrix_snippets = require("luasnip-latex-snippets/matrix").retrieve(is_math)
  
  -- Combine all math snippets
  local all_math_snippets = vim.list_extend(math_i, {})
  vim.list_extend(all_math_snippets, math_iA)
  vim.list_extend(all_math_snippets, math_wrA)
  vim.list_extend(all_math_snippets, math_iA_no_backslash)
  vim.list_extend(all_math_snippets, math_wA_no_backslash)
  vim.list_extend(all_math_snippets, math_rA_no_backslash)
  vim.list_extend(all_math_snippets, math_wRA_no_backslash)
  vim.list_extend(all_math_snippets, greek_letters)
  vim.list_extend(all_math_snippets, matrix_snippets)
  
  -- Add all math snippets as regular snippets
  ls.add_snippets("markdown", all_math_snippets, { default_priority = 0 })
  ls.add_snippets("quarto", all_math_snippets, { default_priority = 0 })

  -- Add special math snippets
  local bwA_math_snippets = require("luasnip-latex-snippets.bwA").retrieve(is_math)
  
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

  -- Directly add Greek letter snippets and matrix snippets for markdown
  vim.list_extend(
    filtered,
    require("luasnip-latex-snippets.greek_letters").retrieve(is_math)
  )
  
  -- Add matrix snippets
  vim.list_extend(
    filtered,
    require("luasnip-latex-snippets.matrix").retrieve(is_math)
  )
  
  -- Add bwA snippets with is_math condition (for bigfun)
  vim.list_extend(filtered, bwA_math_snippets)

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
