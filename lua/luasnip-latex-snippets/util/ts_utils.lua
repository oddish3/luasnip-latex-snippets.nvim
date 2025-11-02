local M = {}

local MATH_NODES = {
  displayed_equation = true,
  inline_formula = true,
  math_environment = true,
  math = true, -- Generic math node in some parsers
  math_delimiter = true, -- For math delimiters like $, $$, \[, \]
  equation_environment = true, -- For specific equation environments
  math_environment_body = true, -- For contents of math environments
}

local TEXT_NODES = {
  text_mode = true,
  label_definition = true,
  label_reference = true,
}

local CODE_BLOCK_NODES = { -- Add this to define code block node types
  fenced_code_block = true,
  indented_code_block = true, -- Optional: include indented code blocks as well if needed
  code_block = true, -- For more generic code blocks
  code_fence_content = true, -- For content inside fenced code blocks
  info_string = true, -- Language specifier in fenced code blocks
  raw_code_fence = true, -- For raw code fences in Quarto (```{r} style)
  inline_code = true, -- For inline code in markdown/quarto (`code` style)
  html_block = true, -- HTML blocks which may contain scripts
  latex_block = true, -- LaTeX blocks in quarto that aren't math
}

function M.in_text(check_parent)
  local node = vim.treesitter.get_node({ ignore_injections = false })

  -- Check if we're in a code block using the helper function
  if M.in_code_block() then
    return true -- If in a code block, always consider it text
  end

  while node do
    if node:type() == "text_mode" then
      if check_parent then
        local ancestor = node:parent()
        while ancestor do
          if MATH_NODES[ancestor:type()] then
            return false
          end
          ancestor = ancestor:parent()
        end
      end
      return true
    elseif MATH_NODES[node:type()] then
      return false
    end
    node = node:parent()
  end
  return true
end

-- Helper function to check if we're in a code block
function M.in_code_block()
  local node = vim.treesitter.get_node({ ignore_injections = false })
  if not node then
    return false
  end

  -- Get the current line and check for common code block indicators in quarto/rmd
  local row = vim.fn.line(".") - 1
  local current_line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ""

  -- Check for inline R code in quarto: `r ...`
  if current_line:match("`r ") or current_line:match("`{r}") then
    return true
  end

  -- Check for quarto code chunk headers: ```{r}, ```{python}, etc.
  if current_line:match("^%s*```%s*{%s*[a-z]+") then
    return true
  end

  -- Check for code blocks via treesitter node types
  local check_node = node
  while check_node do
    local node_type = check_node:type()
    if CODE_BLOCK_NODES[node_type] then
      return true
    end

    -- Also check for code chunks in quarto/rmd files by node name
    if node_type == "element" then
      -- Try to get the language attribute which might indicate a code block
      for child in check_node:iter_children() do
        if child:type() == "start_tag" then
          for attr in child:iter_children() do
            if
              attr:type() == "attribute"
              and attr:named_child(0)
              and attr:named_child(0):type() == "attribute_name"
              and vim.treesitter.get_node_text(attr:named_child(0), 0) == "class"
              and attr:named_child(1)
              and attr:named_child(1):type() == "quoted_attribute_value"
            then
              local class_value = vim.treesitter.get_node_text(attr:named_child(1), 0)
              if class_value:match("sourceCode") or class_value:match("code%-") then
                return true
              end
            end
          end
        end
      end
    end

    check_node = check_node:parent()
  end

  -- Additional context check for quarto code blocks - look at surrounding lines
  local prev_line = vim.api.nvim_buf_get_lines(0, math.max(0, row - 1), row, false)[1] or ""
  local next_line = vim.api.nvim_buf_get_lines(0, row + 1, row + 2, false)[1] or ""

  -- If the previous line starts a code block
  if prev_line:match("^%s*```%s*{?%s*[a-z]+") then
    -- And we haven't yet seen an end marker
    if not current_line:match("^%s*```%s*$") then
      return true
    end
  end

  return false
end

-- Fallback function for markdown/quarto when treesitter doesn't detect math zones properly
local function check_markdown_math_manually()
  -- Get the current line and cursor position
  local row = vim.fn.line(".") - 1
  local col = vim.fn.col(".") - 1
  local current_line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ""

  -- Check for inline math zones ($...$)
  local in_inline_math = false
  local is_opening = false
  local dollar_positions = {}

  -- Find all unescaped $ positions in the current line
  for i = 1, #current_line do
    local char = current_line:sub(i, i)
    if char == "$" and (i == 1 or current_line:sub(i - 1, i - 1) ~= "\\") then
      table.insert(dollar_positions, i)
    end
  end

  -- Check if we're between two $ markers
  if #dollar_positions >= 2 then
    for i = 1, #dollar_positions - 1 do
      local start_pos = dollar_positions[i]
      local end_pos = dollar_positions[i + 1]

      -- Check if cursor is between these markers
      if col > start_pos and col < end_pos then
        return true
      end
    end
  end

  -- Check for display math ($$...$$)
  -- Check if the current line has $$ at the beginning or end
  if current_line:match("^%s*%$%$") or current_line:match("%$%$%s*$") then
    -- Look for matching $$ in the buffer
    local start_line = row
    local end_line = row
    local found_start = current_line:match("^%s*%$%$") ~= nil
    local found_end = current_line:match("%$%$%s*$") ~= nil

    -- If we have $$ at the start, search for end $$ in following lines
    if found_start and not found_end then
      for i = row + 1, math.min(row + 20, vim.api.nvim_buf_line_count(0) - 1) do
        local line = vim.api.nvim_buf_get_lines(0, i, i + 1, false)[1] or ""
        if line:match("%$%$") then
          end_line = i
          found_end = true
          break
        end
      end

      -- Check if we're in this range
      if found_end and row >= start_line and row <= end_line then
        return true
      end
    end

    -- If we have $$ at the end, search for start $$ in previous lines
    if found_end and not found_start then
      for i = math.max(0, row - 20), row - 1 do
        local line = vim.api.nvim_buf_get_lines(0, i, i + 1, false)[1] or ""
        if line:match("%$%$") then
          start_line = i
          found_start = true
          break
        end
      end

      -- Check if we're in this range
      if found_start and row >= start_line and row <= end_line then
        return true
      end
    end
  end

  -- Also check for LaTeX math environments
  local buffer_text = table.concat(
    vim.api.nvim_buf_get_lines(
      0,
      math.max(0, row - 10),
      math.min(row + 10, vim.api.nvim_buf_line_count(0) - 1),
      false
    ),
    "\n"
  )

  -- Look for common LaTeX math environments around the current position
  local math_environments = {
    "\\begin{equation}.-\\end{equation}",
    "\\begin{align}.-\\end{align}",
    "\\begin{align%*}.-\\end{align%*}",
    "\\begin{equation%*}.-\\end{equation%*}",
    "\\begin{math}.-\\end{math}",
    "\\%[.-%]", -- display math
    "\\%(.-%)", -- inline math
  }

  for _, pattern in ipairs(math_environments) do
    for s, e in buffer_text:gmatch("()(" .. pattern .. ")()") do
      if s <= #buffer_text and e <= #buffer_text then
        -- Check if current position is in this environment
        -- Need to adjust for the relative position in the buffer text
        local rel_pos = 0
        for i = 0, row - math.max(0, row - 10) - 1 do
          rel_pos = rel_pos
            + #(vim.api.nvim_buf_get_lines(
              0,
              math.max(0, row - 10) + i,
              math.max(0, row - 10) + i + 1,
              false
            )[1] or "")
            + 1
        end
        rel_pos = rel_pos + col

        if rel_pos >= s and rel_pos <= e then
          return true
        end
      end
    end
  end

  return false
end

function M.in_mathzone()
  local node = vim.treesitter.get_node({ ignore_injections = false })
  local current_filetype = vim.bo.filetype

  -- First check if we are in a code block (regardless of filetype)
  if M.in_code_block() then
    return false -- Never consider code blocks as math zones
  end

  -- Special handling for markdown/quarto
  if
    current_filetype == "markdown"
    or current_filetype == "quarto"
    or current_filetype == "rmd"
  then
    -- First try treesitter if available
    if node then
      -- Check for code blocks first (more reliable)
      local block_node = node
      while block_node do
        if CODE_BLOCK_NODES[block_node:type()] then
          return false
        end
        block_node = block_node:parent()
      end

      -- Check for math nodes
      local math_node = node
      while math_node do
        if MATH_NODES[math_node:type()] then
          return true
        end
        math_node = math_node:parent()
      end
    end

    -- Fallback to manual check for markdown math
    return check_markdown_math_manually()
  end

  -- Standard treesitter check for other filetypes
  while node do
    if TEXT_NODES[node:type()] then
      return false
    elseif MATH_NODES[node:type()] then
      return true
    end
    node = node:parent()
  end

  -- For non-markdown files, check for LaTeX math environments
  if current_filetype == "tex" or current_filetype == "latex" then
    if vim.fn.exists("*vimtex#syntax#in_mathzone") == 1 then
      return vim.fn["vimtex#syntax#in_mathzone"]() == 1
    end
  end

  return false
end

return M
