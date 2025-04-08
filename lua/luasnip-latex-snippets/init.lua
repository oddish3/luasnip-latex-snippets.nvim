local M = {}

local default_opts = {
  use_treesitter = false,
  allow_on_markdown = true,
  ignore_code_blocks = true,
  register_all_snippets = false,
  preserve_jumps = true,
  
  custom_math_snippet_filter = nil,
  custom_code_snippet_filter = nil,
}

_G.in_mathzone = function()
  return M.is_in_math()
end

M.is_in_code_block = function()
  local utils = require("luasnip-latex-snippets.util.utils")
  return utils.block_expansion()
end

M.is_in_math = function()
  local utils = require("luasnip-latex-snippets.util.utils")
  return utils.is_math(true)
end

M.filter_completion = function(entry, ctx)
  local filter_module = require("luasnip-latex-snippets.filter")
  return filter_module.filter_completion(entry, ctx)
end

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
  
  vim.filetype.add({
    extension = {
      qmd = "quarto",
    },
  })
  
  _G.__luasnip_latex_snippets_opts = opts
  
  our_snippet_triggers = {}
  math_snippet_registry = {}
  
  require("luasnip-latex-snippets.filter").setup()
  
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

M.register_snippet = function(trigger, is_math, is_auto)
  local filter_module = require("luasnip-latex-snippets.filter")
  filter_module.register_snippet(trigger, is_math, is_auto)
end

local _autosnippets = function(is_math, not_math)
  local autosnippets = {}
  
  -- All modules except math_i are treated as autosnippets
  for _, s in ipairs({
    "math_wRA_no_backslash",
    "math_rA_no_backslash",
    "math_wA_no_backslash",
    "math_iA_no_backslash",
    "math_iA",
    "math_wrA",
    "greek_letters",
    "matrix",
    "autopairs",
  }) do
    local ok, module = pcall(require, ("luasnip-latex-snippets.%s"):format(s))
    if ok then
      local snippets = module.retrieve(is_math)
      
      -- Mark all snippets with math context for filtering
      for _, snippet in ipairs(snippets) do
        snippet.context = { math = true }
      end
      
      vim.list_extend(autosnippets, snippets)
    end
  end
  
  -- Handle bwA separately - make it work in math context
  local ok_bwa, bwa_module = pcall(require, "luasnip-latex-snippets.bwA")
  if ok_bwa then
    local bwa_snippets = bwa_module.retrieve(is_math) -- Use is_math instead of not_math
    
    -- Mark as math snippets
    for _, snippet in ipairs(bwa_snippets) do
      snippet.context = { math = true }
    end
    
    vim.list_extend(autosnippets, bwa_snippets)
  end
  
  -- Handle wA (math delimiters) separately
  local ok_wa, wa_module = pcall(require, "luasnip-latex-snippets.wA")
  if ok_wa then
    local wa_snippets = wa_module.retrieve(not_math)
    
    -- Override condition to ensure math delimiters don't expand in math
    for _, snippet in ipairs(wa_snippets) do
      local original_condition = snippet.condition
      
      snippet.condition = function(line_to_cursor, matched_trigger, captures)
        -- Don't expand math delimiters when already in math
        if require("luasnip-latex-snippets").is_in_math() then
          return false
        end
        
        -- Use original condition if it exists
        if original_condition then
          return original_condition(line_to_cursor, matched_trigger, captures)
        end
        
        return true
      end
    end
    
    vim.list_extend(autosnippets, wa_snippets)
  end
  
  return autosnippets
end

local function create_code_block_condition()
  local utils = require("luasnip-latex-snippets.util.utils")
  return {
    condition = function()
      if _G.__luasnip_latex_snippets_opts and _G.__luasnip_latex_snippets_opts.ignore_code_blocks
      then
        return not utils.block_expansion()
      end
      return true
    end,
    type = "always",
    desc = "Only expand outside code blocks",
  }
end

M.setup_tex = function(is_math, not_math)
  local ls = require("luasnip")
  ls.add_snippets("tex", {
    ls.parser.parse_snippet(
      { trig = "pac", name = "Package" },
      "\\usepackage[${1:options}]{${2:package}}$0"
    ),
  })
  
  -- math_i stays as regular snippets
  local math_i = require("luasnip-latex-snippets/math_i").retrieve(is_math)
  
  -- Register each snippet with our filtering system
  for _, snippet in ipairs(math_i) do
    if snippet.trigger then
      -- Regular snippet (is_auto = false)
      M.register_snippet(snippet.trigger, true, false)
    end
  end
  
  ls.add_snippets("tex", math_i, { default_priority = 0 })
  
  -- Get all autosnippets
  local autosnippets = _autosnippets(is_math, not_math)
  
  -- Register each autosnippet with our filtering system
  for _, snippet in ipairs(autosnippets) do
    if snippet.trigger then
      -- Register as autosnippet (is_auto = true)
      M.register_snippet(snippet.trigger, snippet.context and snippet.context.math, true)
    end
  end
  
  -- Add as autosnippets with proper type
  ls.add_snippets("tex", autosnippets, {
    type = "autosnippets",
    default_priority = 0,
  })
end

M.setup_markdown = function()
  local ls = require("luasnip")
  local utils = require("luasnip-latex-snippets.util.utils")
  local pipe = utils.pipe
  
  if ls.add_condition then
    ls.add_condition("not_in_code_block", create_code_block_condition())
  end
  
  local is_math = utils.with_opts(utils.is_math, true)
  local not_math = utils.with_opts(utils.not_math, true)
  
  _G.__luasnip_latex_snippets_opts = _G.__luasnip_latex_snippets_opts or {}
  _G.__luasnip_latex_snippets_opts.use_treesitter = true
  
  _G.__loaded_snippet_modules = _G.__loaded_snippet_modules or {}
  
  -- math_i stays as regular snippets
  local math_i = require("luasnip-latex-snippets/math_i").retrieve(is_math)
  
  -- Register each snippet with our filtering system
  for _, snippet in ipairs(math_i) do
    if snippet.trigger then
      M.register_snippet(snippet.trigger, true, false)
    end
  end
  
  ls.add_snippets("markdown", math_i, { default_priority = 0 })
  ls.add_snippets("quarto", math_i, { default_priority = 0 })
  
  -- Get all autosnippets
  local autosnippets = _autosnippets(is_math, not_math)
  
  local trigger_of_snip = function(s)
    return s.trigger
  end
  
  local to_filter = {}
  for _, str in ipairs({
    "wA", -- Only filter wA now, not bwA
  }) do
    local t = require(("luasnip-latex-snippets.%s"):format(str)).retrieve(not_math)
    vim.list_extend(to_filter, vim.tbl_map(trigger_of_snip, t))
  end
  
  local filtered = vim.tbl_filter(function(s)
    return not vim.tbl_contains(to_filter, s.trigger)
  end, autosnippets)
  
  -- tex delimiters - these are special and should always be available
  local normal_wA_tex = {}
  
  -- Use proper snippet format with autosnippet type
  normal_wA_tex[#normal_wA_tex + 1] = ls.snippet({
    trig = "mk",
    name = "Math",
    condition = function()
      -- Don't expand when already in math mode
      return not utils.is_math(true) and not utils.block_expansion()
    end,
  }, { ls.text_node("$"), ls.insert_node(1), ls.text_node("$") })
  
  normal_wA_tex[#normal_wA_tex + 1] = ls.snippet({
    trig = "dm",
    name = "Block Math",
    condition = function()
      -- Don't expand when already in math mode
      return not utils.is_math(true) and not utils.block_expansion()
    end,
  }, { ls.text_node({ "$$", "\t" }), ls.insert_node(1), ls.text_node({ "", "$$" }) })
  
  normal_wA_tex[#normal_wA_tex + 1] = ls.snippet({
    trig = "Mk",
    name = "Math",
    condition = function()
      -- Don't expand when already in math mode
      return not utils.is_math(true) and not utils.block_expansion()
    end,
  }, { ls.text_node("$"), ls.insert_node(1), ls.text_node("$") })
  
  normal_wA_tex[#normal_wA_tex + 1] = ls.snippet({
    trig = "Dm",
    name = "Block Math",
    condition = function()
      -- Don't expand when already in math mode
      return not utils.is_math(true) and not utils.block_expansion()
    end,
  }, { ls.text_node({ "$$", "\t" }), ls.insert_node(1), ls.text_node({ "", "$$" }) })
  vim.list_extend(filtered, normal_wA_tex)
  
  -- Apply condition to each snippet to prevent code block expansion
  if _G.__luasnip_latex_snippets_opts and _G.__luasnip_latex_snippets_opts.ignore_code_blocks then
    for _, snippet in ipairs(filtered) do
      if not snippet.condition_func then
        snippet.condition = function(line_to_cursor, matched_trigger, captures)
          if utils.block_expansion() then
            return false
          end
          if snippet.condition_func then
            return snippet.condition_func(line_to_cursor, matched_trigger, captures)
          end
          return true
        end
      end
    end
  end
  
  -- Register each autosnippet with our filtering system
  for _, snippet in ipairs(filtered) do
    if snippet.trigger then
      M.register_snippet(snippet.trigger, snippet.context and snippet.context.math, true)
    end
  end
  
  -- Add as autosnippets with proper type
  ls.add_snippets("markdown", filtered, {
    type = "autosnippets",
    default_priority = 0,
  })
  
  ls.add_snippets("quarto", filtered, {
    type = "autosnippets",
    default_priority = 0,
  })
end

return M
