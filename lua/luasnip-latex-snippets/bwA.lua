local ls = require("luasnip")
local t = ls.text_node
local i = ls.insert_node

local M = {}

function M.retrieve(condition_fn)
  local utils = require("luasnip-latex-snippets.util.utils")
  local pipe = utils.pipe
  local conds = require("luasnip.extras.expand_conditions")
  
  -- Check if we received is_math (for math mode) or not_math (for non-math mode)
  local is_math_mode = type(condition_fn) == "function" and 
                       debug.getinfo(condition_fn).name ~= "not_math"
  
  local condition
  if is_math_mode then
    -- Inside math mode condition
    condition = pipe({ condition_fn })
  else
    -- Outside math mode condition
    condition = pipe({ conds.line_begin, condition_fn })
  end

  local parse_snippet = ls.extend_decorator.apply(ls.parser.parse_snippet, {
    condition = condition,
  }) --[[@as function]]

  local s = ls.extend_decorator.apply(ls.snippet, {
    condition = condition,
  }) --[[@as function]]

  -- Basic snippets that work in both math and non-math
  local snippets = {
    s(
      { trig = "ali", name = "Align" },
      { t({ "\\begin{align*}", "\t" }), i(1), t({ "", "\\end{align*}" }) }
    ),

    parse_snippet({ trig = "beg", name = "begin{} / end{}" }, "\\begin{$1}\n\t$0\n\\end{$1}"),
    parse_snippet({ trig = "case", name = "cases" }, "\\begin{cases}\n\t$1\n\\end{cases}"),

    s({ trig = "bigfun", name = "Big function" }, {
      t({ "\\begin{align*}", "\t" }),
      i(1),
      t(":"),
      t(" "),
      i(2),
      t("&\\longrightarrow "),
      i(3),
      t({ " \\", "\t" }),
      i(4),
      t("&\\longmapsto "),
      i(1),
      t("("),
      i(4),
      t(")"),
      t(" = "),
      i(0),
      t({ "", "\\end{align*}" }),
    }),
  }

  return snippets
end

return M
