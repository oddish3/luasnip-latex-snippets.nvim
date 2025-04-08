local M = {}

local ls = require("luasnip")

function M.retrieve(is_math)
  local utils = require("luasnip-latex-snippets.util.utils")
  local pipe, no_backslash = utils.pipe, utils.no_backslash

  local decorator = {
    wordTrig = false,
    condition = pipe({ is_math, no_backslash }),
  }

  local parse_snippet = ls.extend_decorator.apply(ls.parser.parse_snippet, decorator) --[[@as function]]

  -- Table of Greek letters snippets
  -- Format: { trigger = ":letter", replacement = "\\greekletter" }
  local greek_letters = {
    -- Lowercase Greek letters
    { trig = ";a", name = "alpha", replace = "\\alpha" },
    { trig = ";b", name = "beta", replace = "\\beta" },
    { trig = ";g", name = "gamma", replace = "\\gamma" },
    { trig = ";d", name = "delta", replace = "\\delta" },
    { trig = ";e", name = "epsilon", replace = "\\epsilon" },
    { trig = ";ve", name = "varepsilon", replace = "\\varepsilon" },
    { trig = ";z", name = "zeta", replace = "\\zeta" },
    { trig = ";h", name = "eta", replace = "\\eta" },
    { trig = ";th", name = "theta", replace = "\\theta" },
    { trig = ";vth", name = "vartheta", replace = "\\vartheta" },
    { trig = ";i", name = "iota", replace = "\\iota" },
    { trig = ";k", name = "kappa", replace = "\\kappa" },
    { trig = ";l", name = "lambda", replace = "\\lambda" },
    { trig = ";m", name = "mu", replace = "\\mu" },
    { trig = ";n", name = "nu", replace = "\\nu" },
    { trig = ";x", name = "xi", replace = "\\xi" },
    { trig = ";p", name = "pi", replace = "\\pi" },
    { trig = ";vp", name = "varpi", replace = "\\varpi" },
    { trig = ";r", name = "rho", replace = "\\rho" },
    { trig = ";vr", name = "varrho", replace = "\\varrho" },
    { trig = ";s", name = "sigma", replace = "\\sigma" },
    { trig = ";vs", name = "varsigma", replace = "\\varsigma" },
    { trig = ";t", name = "tau", replace = "\\tau" },
    { trig = ";u", name = "upsilon", replace = "\\upsilon" },
    { trig = ";f", name = "phi", replace = "\\phi" },
    { trig = ";vf", name = "varphi", replace = "\\varphi" },
    { trig = ";c", name = "chi", replace = "\\chi" },
    { trig = ";ps", name = "psi", replace = "\\psi" },
    { trig = ";o", name = "omega", replace = "\\omega" },

    -- Uppercase Greek letters
    { trig = ";A", name = "Alpha", replace = "A" },
    { trig = ";B", name = "Beta", replace = "B" },
    { trig = ";G", name = "Gamma", replace = "\\Gamma" },
    { trig = ";D", name = "Delta", replace = "\\Delta" },
    { trig = ";E", name = "Epsilon", replace = "E" },
    { trig = ";Z", name = "Zeta", replace = "Z" },
    { trig = ";H", name = "Eta", replace = "H" },
    { trig = ";Th", name = "Theta", replace = "\\Theta" },
    { trig = ";I", name = "Iota", replace = "I" },
    { trig = ";K", name = "Kappa", replace = "K" },
    { trig = ";L", name = "Lambda", replace = "\\Lambda" },
    { trig = ";M", name = "Mu", replace = "M" },
    { trig = ";N", name = "Nu", replace = "N" },
    { trig = ";X", name = "Xi", replace = "\\Xi" },
    { trig = ";P", name = "Pi", replace = "\\Pi" },
    { trig = ";R", name = "Rho", replace = "P" },
    { trig = ";S", name = "Sigma", replace = "\\Sigma" },
    { trig = ";T", name = "Tau", replace = "T" },
    { trig = ";U", name = "Upsilon", replace = "\\Upsilon" },
    { trig = ";F", name = "Phi", replace = "\\Phi" },
    { trig = ";C", name = "Chi", replace = "X" },
    { trig = ";Ps", name = "Psi", replace = "\\Psi" },
    { trig = ";O", name = "Omega", replace = "\\Omega" },
  }

  local snippets = {}
  for _, letter in ipairs(greek_letters) do
    table.insert(
      snippets,
      parse_snippet({ trig = letter.trig, name = letter.name }, letter.replace .. " ")
    )
  end

  return snippets
end

return M
