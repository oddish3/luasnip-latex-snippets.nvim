local M = {}

-- local s = ls.snippet
-- local sn = ls.snippet_node
-- local isn = ls.indent_snippet_node
-- local t = ls.text_node
-- local i = ls.insert_node
-- local f = ls.function_node
-- local c = ls.choice_node
-- local d = ls.dynamic_node
-- local events = require("luasnip.util.events")
-- local r = require("luasnip.extras").rep
-- local fmt = require("luasnip.extras.fmt").fmt
-- local fmta = require("luasnip.extras.fmt").fmta

M.pipe = function(fns)
  return function(...)
    for _, fn in ipairs(fns) do
      if not fn(...) then
        return false
      end
    end

    return true
  end
end

M.no_backslash = function(line_to_cursor, matched_trigger)
  return not line_to_cursor:find("\\%a+$", -#line_to_cursor)
end

local ts_utils = require("luasnip-latex-snippets.util.ts_utils")

-- Check if we're in a quarto or rmd code chunk
M.in_quarto_code_chunk = function()
  local ft = vim.bo.filetype
  if ft ~= "quarto" and ft ~= "rmd" and ft ~= "markdown" then
    return false
  end
  
  -- Get current line and position
  local line = vim.api.nvim_get_current_line()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  
  -- Check if current line contains code chunk markers
  if line:match("^%s*```%s*{") then
    return true
  end
  
  -- Look at a few lines above to find code chunk start
  local start_found = false
  local chunk_end_found = false
  local start_line = math.max(1, row - 10)
  
  for i = row - 1, start_line, -1 do
    local check_line = vim.api.nvim_buf_get_lines(0, i-1, i, false)[1]
    if check_line and check_line:match("^%s*```%s*$") then
      chunk_end_found = true
      break
    end
    if check_line and check_line:match("^%s*```%s*{") then
      start_found = true
      break
    end
  end
  
  -- If we found a start marker but no end marker before it, we're in a code chunk
  if start_found and not chunk_end_found then
    -- Check if current line is an end marker
    if line:match("^%s*```%s*$") then
      return false
    end
    return true
  end
  
  return false
end

-- Get a direct reference to luasnip for condition checking
local function get_luasnip()
  local status, ls = pcall(require, "luasnip")
  if not status then
    return nil
  end
  return ls
end

-- Check if the current position should block snippet expansion
M.block_expansion = function()
  -- Get filetype
  local ft = vim.bo.filetype
  
  -- For non-markdown/quarto files, don't block
  if ft ~= "markdown" and ft ~= "quarto" and ft ~= "rmd" then
    return false
  end
  
  -- Check for code block using direct method
  if M.in_quarto_code_chunk() then
    return true
  end
  
  -- Check using treesitter
  if ts_utils.in_code_block() then
    return true
  end
  
  -- Additional pattern check for inline code
  local line = vim.api.nvim_get_current_line()
  local pos = vim.api.nvim_win_get_cursor(0)[2] + 1
  
  -- Check if we're inside backticks on the current line
  local start_idx = 1
  while true do
    local code_start = line:find("`", start_idx)
    if not code_start then break end
    
    local code_end = line:find("`", code_start + 1)
    if not code_end then break end
    
    if pos > code_start and pos <= code_end then
      return true
    end
    
    start_idx = code_end + 1
  end
  
  return false
end

M.is_math = function(treesitter)
  -- First check if we should block expansion
  if M.block_expansion() then
    return false
  end
  
  -- Use global options if available
  local use_ts = treesitter
  if _G.__luasnip_latex_snippets_opts and _G.__luasnip_latex_snippets_opts.use_treesitter ~= nil then
    use_ts = _G.__luasnip_latex_snippets_opts.use_treesitter
  end
  
  if use_ts then
    return ts_utils.in_mathzone()
  end

  -- For VimTeX users
  if vim.fn.exists("*vimtex#syntax#in_mathzone") == 1 then
    return vim.fn["vimtex#syntax#in_mathzone"]() == 1
  end

  return false
end

M.not_math = function(treesitter)
  -- If we're in a code block, we're definitely not in math mode
  -- but we should also prevent expansion
  if M.block_expansion() then
    return false
  end
  
  -- Use global options if available
  local use_ts = treesitter
  if _G.__luasnip_latex_snippets_opts and _G.__luasnip_latex_snippets_opts.use_treesitter ~= nil then
    use_ts = _G.__luasnip_latex_snippets_opts.use_treesitter
  end
  
  if use_ts then
    return ts_utils.in_text(true)
  end

  -- For VimTeX users
  if vim.fn.exists("*vimtex#syntax#in_mathzone") == 1 then
    return vim.fn["vimtex#syntax#in_mathzone"]() == 0
  end

  return true
end

M.comment = function()
  return vim.fn["vimtex#syntax#in_comment"]() == 1
end

M.env = function(name)
  local x, y = unpack(vim.fn["vimtex#env#is_inside"](name))
  return x ~= "0" and y ~= "0"
end

M.with_priority = function(snip, priority)
  snip.priority = priority
  return snip
end

M.with_opts = function(fn, opts)
  return function()
    return fn(opts)
  end
end

return M
