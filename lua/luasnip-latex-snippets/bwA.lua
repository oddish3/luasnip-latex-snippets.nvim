-- File: luasnip-latex-snippets/bwA.lua (or wherever it lives)

local ls = require("luasnip")
local utils = require("luasnip-latex-snippets.util.utils") -- Keep if snippets use utils
local pipe = utils.pipe -- Keep if snippets use utils or complex conditions later
local t = ls.text_node
local i = ls.insert_node

local M = {}

-- This function will be called with is_math from the main loop
-- Changed parameter name to 'context_condition' for clarity
function M.retrieve(context_condition)
  -- print(
  --   "[bwA.lua] retrieve called. Applying condition:",
  --   context_condition == is_math and "is_math" or "other"
  -- ) -- Debug print

  -- Create decorators that apply the passed context_condition
  -- This ensures snippets defined below only trigger when context_condition() is true
  -- Removed conds.line_begin to match the math_i example's simplicity for math snippets
  local parse_snippet = ls.extend_decorator.apply(ls.parser.parse_snippet, {
    condition = pipe({ context_condition }), -- Apply the condition passed by the main loop
    show_condition = context_condition, -- Optional: for snippet menu visibility
  }) --[[@as function]]

  local s = ls.extend_decorator.apply(ls.snippet, {
    condition = pipe({ context_condition }), -- Apply the condition passed by the main loop
    show_condition = context_condition, -- Optional: for snippet menu visibility
  }) --[[@as function]]

  -- Define snippets using the decorated functions 's' and 'parse_snippet'
  -- They will automatically inherit the condition set above.
  return {
    s( -- Uses decorated 's'
      { trig = "ali", name = "Align" },
      { t({ "\\begin{align*}", "\t" }), i(1), t({ "", ".\\end{align*}" }) }
    ),
    parse_snippet({ trig = "beg", name = "begin{} / end{}" }, "\\begin{$1}\n\t$0\n\\end{$1}"), -- Uses decorated 'parse_snippet'
    parse_snippet({ trig = "case", name = "cases" }, "\\begin{cases}\n\t$1\n\\end{cases}"), -- Uses decorated 'parse_snippet'
    s({ trig = "bigfun", name = "Big function" }, { -- Uses decorated 's'
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
      t({ "", ".\\end{align*}" }),
    }),
  }
end

return M
