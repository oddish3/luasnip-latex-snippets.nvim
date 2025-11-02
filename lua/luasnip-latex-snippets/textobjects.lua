local M = {}

local did_setup = false

local function begins_with(text, prefix)
  return text:sub(1, #prefix) == prefix
end

local function ends_with(text, suffix)
  if #suffix == 0 then
    return true
  end
  return text:sub(-#suffix) == suffix
end

local function get_visual_range()
  local visual_mode = vim.fn.visualmode()
  if visual_mode == "" then
    visual_mode = vim.fn.mode()
  end

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local bufnr = vim.api.nvim_get_current_buf()

  local start_row = start_pos[2] - 1
  local start_col = math.max(start_pos[3] - 1, 0)
  local end_row = end_pos[2] - 1
  local end_col = math.max(end_pos[3] - 1, 0)

  if visual_mode == "V" then
    start_col = 0
    local line = vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, true)[1] or ""
    end_col = #line
  elseif visual_mode == "v" then
    end_col = end_col + 1
  else
    return nil
  end

  return {
    start_row = start_row,
    start_col = start_col,
    end_row = end_row,
    end_col = end_col,
    mode = visual_mode,
  }
end

local function get_selection_lines(bufnr, range)
  return vim.api.nvim_buf_get_text(
    bufnr,
    range.start_row,
    range.start_col,
    range.end_row,
    range.end_col,
    {}
  )
end

local function wrap_lines(lines, open_text, close_text)
  local new_lines = vim.deepcopy(lines)
  if #new_lines == 0 then
    new_lines = { "" }
  end

  new_lines[1] = open_text .. new_lines[1]
  local last_idx = #new_lines
  new_lines[last_idx] = new_lines[last_idx] .. close_text

  return new_lines
end

local function unwrap_lines(lines, open_text, close_text)
  local new_lines = vim.deepcopy(lines)
  if #new_lines == 0 then
    return new_lines
  end

  new_lines[1] = new_lines[1]:sub(#open_text + 1)

  local last_idx = #new_lines
  local trimmed = new_lines[last_idx]
  new_lines[last_idx] = trimmed:sub(1, #trimmed - #close_text)

  return new_lines
end

local function is_pure_display_line(line)
  return line:match("^%s*%$%$%s*$") ~= nil
end

local function clamp_index(bufnr, row, col)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local row_clamped = math.min(math.max(row, 1), line_count)
  local line = vim.api.nvim_buf_get_lines(bufnr, row_clamped - 1, row_clamped, true)[1] or ""
  local col_clamped = math.min(math.max(col, 1), #line + 1)
  return row_clamped, col_clamped, line
end

local function set_visual_marks(start_row, start_col, end_row, end_col)
  local bufnr = vim.api.nvim_get_current_buf()
  local s_row, s_col = clamp_index(bufnr, start_row, start_col)
  local e_row, e_col = clamp_index(bufnr, end_row, end_col)

  vim.fn.setpos("'<", { 0, s_row, s_col, 0 })
  vim.fn.setpos("'>", { 0, e_row, e_col, 0 })
  vim.cmd.normal({ args = { "gv" }, bang = true })
end

local function find_prev_display_delim(bufnr, cursor_row, cursor_col)
  for row = cursor_row, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, true)[1] or ""
    local limit = #line
    if row == cursor_row then
      limit = math.min(limit, cursor_col + 1)
    end

    if limit >= 2 then
      local idx
      local start_idx = 1
      while true do
        local found = line:find("$$", start_idx, true)
        if not found or found > limit then
          break
        end
        idx = found
        start_idx = found + 1
      end
      if idx then
        return row, idx
      end
    end
  end
end

local function find_next_display_delim(bufnr, cursor_row, cursor_col, start_row, start_col)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  for row = cursor_row, line_count do
    local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, true)[1] or ""
    local search_start = 1
    if row == cursor_row then
      search_start = cursor_col + 2
    end

    local found = line:find("$$", search_start, true)
    if row == start_row and found and found == start_col then
      search_start = found + 2
      found = line:find("$$", search_start, true)
    end

    if found then
      return row, found
    end
  end
end

local function select_math_textobject(around)
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_row, cursor_col0 = cursor[1], cursor[2] -- col is 0-based

  local start_row, start_col = find_prev_display_delim(bufnr, cursor_row, cursor_col0)
  if not start_row then
    return false
  end

  local end_row, end_col = find_next_display_delim(bufnr, cursor_row, cursor_col0, start_row, start_col)
  if not end_row then
    return false
  end

  local open_line = vim.api.nvim_buf_get_lines(bufnr, start_row - 1, start_row, true)[1] or ""
  local close_line = vim.api.nvim_buf_get_lines(bufnr, end_row - 1, end_row, true)[1] or ""

  if around then
    set_visual_marks(start_row, start_col, end_row, math.min(end_col + 1, #close_line))
    return true
  end

  local inner_start_row = start_row
  local inner_start_col = start_col + 2
  if is_pure_display_line(open_line) then
    inner_start_row = start_row + 1
    inner_start_col = 1
  end

  local inner_end_row = end_row
  local inner_end_col = end_col - 1
  if is_pure_display_line(close_line) then
    inner_end_row = end_row - 1
    if inner_end_row >= 1 then
      local prev_line = vim.api.nvim_buf_get_lines(bufnr, inner_end_row - 1, inner_end_row, true)[1] or ""
      inner_end_col = #prev_line
    end
  end

  if inner_end_row < inner_start_row then
    inner_end_row = inner_start_row
    inner_end_col = inner_start_col
  elseif inner_end_row == inner_start_row and inner_end_col < inner_start_col then
    inner_end_col = inner_start_col
  end

  set_visual_marks(inner_start_row, inner_start_col, inner_end_row, inner_end_col)
  return true
end

local function surround_visual(open_text, close_text)
  local prior_mode = vim.fn.mode()
  if not prior_mode:match("[vV\022]") then
    return
  end

  if type(open_text) ~= "string" or type(close_text) ~= "string" then
    return
  end

  local range = get_visual_range()
  if not range then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local lines = get_selection_lines(bufnr, range)
  if #lines == 0 then
    lines = { "" }
  end

  local is_wrapped = begins_with(lines[1], open_text) and ends_with(lines[#lines], close_text)

  local replacement
  if is_wrapped then
    replacement = unwrap_lines(lines, open_text, close_text)
  else
    replacement = wrap_lines(lines, open_text, close_text)
  end

  vim.api.nvim_buf_set_text(
    bufnr,
    range.start_row,
    range.start_col,
    range.end_row,
    range.end_col,
    replacement
  )

  local mark_start = vim.fn.getpos("'[")
  local mark_end = vim.fn.getpos("']")

  vim.fn.setpos("'<", mark_start)
  vim.fn.setpos("'>", mark_end)

  vim.cmd.normal({ args = { "gv" }, bang = true })
end

local function setup_textobjects(opts)
  local config = opts.math_textobjects or {}
  if config.enabled == false then
    return
  end

  local inside_key = config.inside
  local around_key = config.around

  local base_opts = { noremap = true, silent = true }

  if inside_key and inside_key ~= "" then
    local map_opts = vim.tbl_extend("force", base_opts, {
      desc = config.inside_desc or "Inside math $...$ / $$...$$",
    })

    if type(config.inside_handler) == "function" then
      vim.keymap.set({ "o", "x" }, inside_key, config.inside_handler, map_opts)
    else
      vim.keymap.set({ "o", "x" }, inside_key, function()
        if not select_math_textobject(false) then
          vim.cmd.normal({ args = { "T$vt$" }, bang = true })
        end
      end, map_opts)
    end
  end

  if around_key and around_key ~= "" then
    local map_opts = vim.tbl_extend("force", base_opts, {
      desc = config.around_desc or "Around math $...$ / $$...$$",
    })

    if type(config.around_handler) == "function" then
      vim.keymap.set({ "o", "x" }, around_key, config.around_handler, map_opts)
    else
      vim.keymap.set({ "o", "x" }, around_key, function()
        if not select_math_textobject(true) then
          vim.cmd.normal({ args = { "F$vf$" }, bang = true })
        end
      end, map_opts)
    end
  end
end

local function setup_surrounds(opts)
  local config = opts.math_surrounds or {}
  if config.enabled == false then
    return
  end

  local mappings = config.mappings or {}
  if vim.tbl_isempty(mappings) then
    return
  end

  for lhs, spec in pairs(mappings) do
    local open_text = spec.open or spec.left
    local close_text = spec.close or spec.right
    if open_text and close_text then
      vim.keymap.set("x", lhs, function()
        surround_visual(open_text, close_text)
      end, {
        noremap = true,
        silent = true,
        desc = spec.desc or ("Surround selection with %s … %s"):format(open_text, close_text),
      })
    end
  end
end

function M.setup(opts)
  if did_setup then
    return
  end
  did_setup = true

  setup_textobjects(opts or {})
  setup_surrounds(opts or {})
end

return M
