local M = {}

local ls = require("luasnip")
local i = ls.insert_node
local d = ls.dynamic_node
local utils = require("luasnip-latex-snippets.util.utils")
local pipe = utils.pipe

function M.retrieve(is_math)
  local parse_snippet = ls.extend_decorator.apply(ls.parser.parse_snippet, {
    condition = pipe({ is_math }),
  }) --[[@as function]]
  -- Custom snippet for dynamic matrix dimensions
  local s = ls.extend_decorator.apply(ls.snippet, {
    condition = pipe({ is_math }),
  }) --[[@as function]]

  return {
    -- Using hyphen separator
    s({
      trig = "bmat%-(%d+)%-(%d+)",
      name = "bmatrix with hyphen and dimensions",
      regTrig = true,
    }, {
      d(1, function(_, snip)
        local rows = tonumber(snip.captures[1])
        local cols = tonumber(snip.captures[2])

        -- Create the snippet string
        local snippet_str = "\\begin{bmatrix}\n"
        local count = 1

        for row = 1, rows do
          for col = 1, cols do
            snippet_str = snippet_str .. "${" .. count .. "}"
            count = count + 1

            if col < cols then
              snippet_str = snippet_str .. " & "
            end
          end

          if row < rows then
            snippet_str = snippet_str .. " \\\\\\\\\n"
          else
            snippet_str = snippet_str .. "\n"
          end
        end

        snippet_str = snippet_str .. "\\end{bmatrix}"

        -- Parse the snippet
        local parsed = ls.parser.parse_snippet({}, snippet_str)
        return parsed
      end),
      i(0),
    }),

    s({
      trig = "pmat%-(%d+)%-(%d+)",
      name = "pmatrix with hyphen and dimensions",
      regTrig = true,
    }, {
      d(1, function(_, snip)
        local rows = tonumber(snip.captures[1])
        local cols = tonumber(snip.captures[2])

        -- Create the snippet string
        local snippet_str = "\\begin{pmatrix}\n"
        local count = 1

        for row = 1, rows do
          for col = 1, cols do
            snippet_str = snippet_str .. "${" .. count .. "}"
            count = count + 1

            if col < cols then
              snippet_str = snippet_str .. " & "
            end
          end

          if row < rows then
            snippet_str = snippet_str .. " \\\\\\\\\n"
          else
            snippet_str = snippet_str .. "\n"
          end
        end

        snippet_str = snippet_str .. "\\end{pmatrix}"

        -- Parse the snippet
        local parsed = ls.parser.parse_snippet({}, snippet_str)
        return parsed
      end),
      i(0),
    }),
  }
end
return M
