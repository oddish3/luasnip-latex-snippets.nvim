local M = {}

local ls = require("luasnip")
local utils = require("luasnip-latex-snippets.util.utils")
local pipe = utils.pipe
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local s = ls.snippet

function M.retrieve(is_math)
  -- Create snippets that only trigger in math mode
  return {
    -- Parentheses
    s({
      trig = "(",
      wordTrig = false,
      condition = pipe({ is_math }),
      show_condition = is_math,
    }, {
      t("("),
      i(1),
      t(")"),
    }),

    -- Square brackets
    -- s({
    --   trig = "[",
    --   wordTrig = false,
    --   condition = pipe({ is_math }),
    --   show_condition = is_math,
    -- }, {
    --   t("["),
    --   i(1),
    --   t("]"),
    -- }),

    -- Curly braces
    s({
      trig = "{",
      wordTrig = false,
      condition = pipe({ is_math }),
      show_condition = is_math,
    }, {
      t("\\{"),
      i(1),
      t("\\}"),
    }),

    -- Angle brackets
    -- s({
    --   trig = "<",
    --   wordTrig = false,
    --   condition = pipe({ is_math }),
    --   show_condition = is_math,
    -- }, {
    --   t("\\langle "),
    --   i(1),
    --   t(" \\rangle"),
    -- }),

    -- Vertical bars (absolute value)
    -- s({
    --   trig = "|",
    --   wordTrig = false,
    --   condition = pipe({ is_math }),
    --   show_condition = is_math,
    -- }, {
    --   t("\\left| "),
    --   i(1),
    --   t(" \\right|"),
    -- }),

    -- Floor function
    s({
      trig = "fl",
      wordTrig = false,
      condition = pipe({ is_math }),
      show_condition = is_math,
    }, {
      t("\\lfloor "),
      i(1),
      t(" \\rfloor"),
    }),

    -- Ceiling function
    s({
      trig = "cl",
      wordTrig = false,
      condition = pipe({ is_math }),
      show_condition = is_math,
    }, {
      t("\\lceil "),
      i(1),
      t(" \\rceil"),
    }),
  }
end

return M
