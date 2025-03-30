local ls = require("luasnip")
local s = ls.snippet
local f = ls.function_node

local M = {}

M.decorator = {}

local postfix_trig = function(match)
  return string.format("(%s)", match)
end

local postfix_node = f(function(_, snip)
  return string.format("\\%s ", snip.captures[1])
end, {})

local build_snippet = function(trig, node, match, priority, name)
  -- Create the snippet
  local snippet = s({
    name = name and name(match) or match,
    trig = trig(match),
    priority = priority,
  }, vim.deepcopy(node))
  
  -- Mark this as a math snippet explicitly
  snippet.context = { math = true }
  
  return snippet
end

local build_with_priority = function(trig, node, priority, name)
  return function(match)
    return build_snippet(trig, node, match, priority, name)
  end
end

local vargreek_postfix_completions = function()
  local re = "varepsilon|varphi|varrho|vartheta"

  local build = build_with_priority(postfix_trig, postfix_node, 200)
  return vim.tbl_map(build, vim.split(re, "|"))
end

local greek_postfix_completions = function()
  local re =
    "[aA]lpha|[bB]eta|[cC]hi|[dD]elta|[eE]psilon|[gG]amma|[iI]ota|[kK]appa|[lL]ambda|[mM]u|[nN]u|[oO]mega|[pP]hi|[pP]i|[pP]si|[rR]ho|[sS]igma|[tT]au|[tT]heta|[zZ]eta|[eE]ta"

  local build = build_with_priority(postfix_trig, postfix_node, 200)
  return vim.tbl_map(build, vim.split(re, "|"))
end

local postfix_completions = function()
  local re = "sin|cos|tan|csc|sec|cot|ln|log|exp|star|perp|int"

  local build = build_with_priority(postfix_trig, postfix_node)
  return vim.tbl_map(build, vim.split(re, "|"))
end

local snippets = {}

function M.retrieve(is_math)
  -- Clear previous snippets
  snippets = {}
  
  -- Make sure is_math is a function
  if type(is_math) ~= "function" then
    local utils = require("luasnip-latex-snippets.util.utils")
    is_math = utils.is_math
  end
  
  local utils = require("luasnip-latex-snippets.util.utils")
  local no_backslash = utils.no_backslash

  -- This decorator will be applied to all snippets
  M.decorator = {
    wordTrig = true,
    trigEngine = "pattern",
    -- The critical part: ensure this only works in math mode
    condition = function(line_to_cursor, matched_trigger, captures)
      return is_math() and no_backslash(line_to_cursor, matched_trigger)
    end,
  }

  -- Apply the decorator to snippets
  s = ls.extend_decorator.apply(ls.snippet, M.decorator) --[[@as function]]

  -- Build the snippets
  vim.list_extend(snippets, vargreek_postfix_completions())
  vim.list_extend(snippets, greek_postfix_completions())
  vim.list_extend(snippets, postfix_completions())
  vim.list_extend(snippets, { build_snippet(postfix_trig, postfix_node, "q?quad", 200) })

  -- Register all generated snippets with the init module for filtering
  local init_module = require("luasnip-latex-snippets")
  if init_module.register_snippet then
    for _, snippet in ipairs(snippets) do
      if snippet.trigger then
        init_module.register_snippet(snippet.trigger, true) -- Mark as math snippets
      end
    end
  end

  return snippets
end

return M