local M = {}

-- Store a registry of our own snippets with metadata
-- Keep separate registries for autosnippets and regular snippets
local our_snippet_registry = {
  regular = {},
  auto = {},
}

-- Register a snippet as one of our own with metadata
M.register_snippet = function(trigger, is_math, is_auto)
  local registry_type = is_auto and "auto" or "regular"

  our_snippet_registry[registry_type][trigger] = {
    is_math = is_math == true, -- Ensure boolean
    is_our_snippet = true,
  }
end

-- Check if a snippet trigger is one of our math snippets
M.is_our_math_snippet = function(trigger, is_auto)
  local registry_type = is_auto and "auto" or "regular"
  local entry = our_snippet_registry[registry_type][trigger]
  return entry and entry.is_math
end

-- Check if a snippet trigger is one of our non-math snippets
M.is_our_non_math_snippet = function(trigger, is_auto)
  local registry_type = is_auto and "auto" or "regular"
  local entry = our_snippet_registry[registry_type][trigger]
  return entry and not entry.is_math
end

-- Setup function to apply the filter
M.setup = function()
  -- Get LuaSnip
  local ls = require("luasnip")
  local latex_snippets = require("luasnip-latex-snippets")

  -- Original functions
  local original_expand_or_jumpable = ls.expand_or_jumpable
  local original_expandable = ls.expandable
  local original_jumpable = ls.jumpable
  local original_snip_expand = ls.snip_expand

  -- Check if we should preserve jumping functionality
  local should_preserve_jumps = true
  if
    _G.__luasnip_latex_snippets_opts and _G.__luasnip_latex_snippets_opts.preserve_jumps ~= nil
  then
    should_preserve_jumps = _G.__luasnip_latex_snippets_opts.preserve_jumps
  end

  -- This function checks if the current trigger would pass our filter
  local function should_allow_snippet_at_cursor(snippet)
    -- Get current context
    local in_math = latex_snippets.is_in_math()
    local in_code = latex_snippets.is_in_code_block()
    local opts = _G.__luasnip_latex_snippets_opts or {}
    local utils = require("luasnip-latex-snippets.util.utils")

    local ft = vim.bo.filetype
    local in_text_command = false
    if opts.disable_math_snippets_in_text_commands then
      in_text_command = utils.in_text_command()
    end

    local block_markdown_text_in_math = opts.block_markdown_text_snippets_in_math
      and (ft == "markdown" or ft == "quarto" or ft == "rmd")

    -- If not in math or code blocks, allow all
    if not (in_math or in_code) then
      return true
    end

    -- Extract trigger either from snippet or from cursor position
    local trigger = nil
    if snippet and snippet.trigger then
      trigger = snippet.trigger
    else
      -- Extract from cursor position
      local line = vim.api.nvim_get_current_line()
      local cursor = vim.api.nvim_win_get_cursor(0)
      local col = cursor[2]

      -- Try to extract what looks like a trigger
      local start_idx = col
      while start_idx > 0 and line:sub(start_idx, start_idx):match("[%w_]") do
        start_idx = start_idx - 1
      end

      -- Extract the trigger candidate
      trigger = line:sub(start_idx + 1, col)
    end

    if not trigger or trigger == "" then
      return false
    end

    local snippet_is_math = snippet and snippet.context and snippet.context.math

    -- SPECIAL HANDLING FOR CUSTOM SNIPPETS
    -- Check if this is a LuaSnip snippet instance (not just a string)
    if snippet and type(snippet) == "table" and snippet.condition then
      local condition_str = tostring(snippet.condition)

      -- If snippet has a math condition, it should be treated as a math snippet
      if condition_str:match("in_mathzone") or condition_str:match("is_math") then
        if in_math then
          return true -- Allow this math snippet in math mode
        else
          return false -- Block this math snippet outside math
        end
      elseif not in_math then
        -- This is a non-math snippet and we're not in math, so allow it
        return true
      end
    end

    -- Get if this is an autosnippet
    local is_auto = snippet and snippet.snippetType == "autosnippet"

    -- In math zone
    if in_math then
      if
        in_text_command
        and (snippet_is_math or M.is_our_math_snippet(trigger, is_auto))
      then
        return false
      end

      -- Check if this is a registered math snippet
      if M.is_our_math_snippet(trigger, is_auto) then
        return true -- Our registered math snippets are allowed in math
      end

      if snippet_is_math then
        return true
      end

      if block_markdown_text_in_math then
        return false
      end

      -- For non-registered snippets, use heuristics
      if
        not M.is_our_non_math_snippet(trigger, is_auto)
      then
        return true -- Looks like a math snippet based on patterns
      end

      -- Not a math snippet, don't allow in math
      return false
    end

    -- In code block
    if in_code then
      -- Block all snippets in code blocks
      return false
    end

    return false -- Shouldn't get here
  end

  -- Override the expand_or_jumpable function
  ls.expand_or_jumpable = function()
    -- Check if we're in a jump sequence - if so, allow jumping
    if should_preserve_jumps and original_jumpable() then
      return true
    end

    -- Check if we should allow the current snippet
    if should_allow_snippet_at_cursor() then
      return original_expand_or_jumpable()
    else
      return false
    end
  end

  -- Also override expandable
  ls.expandable = function()
    -- Check if we should allow the current snippet
    if should_allow_snippet_at_cursor() then
      return original_expandable()
    else
      return false
    end
  end

  -- A shared filter implementation both modules can use
  local function filter_completion_impl(entry, ctx, core_module)
    local kind = entry:get_kind()
    local is_snippet = kind == 15 -- kinds.Snippet = 15

    -- If not a snippet, allow all other completion types
    if not is_snippet then
      return true
    end

    -- Get context information
    local in_math = core_module.is_in_math()
    local in_code = core_module.is_in_code_block()
    local opts = _G.__luasnip_latex_snippets_opts or {}
    local utils = require("luasnip-latex-snippets.util.utils")
    local ft = vim.bo.filetype
    local in_text_command = false
    if opts.disable_math_snippets_in_text_commands then
      in_text_command = utils.in_text_command()
    end
    local block_markdown_text_in_math = opts.block_markdown_text_snippets_in_math
      and (ft == "markdown" or ft == "quarto" or ft == "rmd")

    -- Get the snippet trigger/label
    local completion_item = entry:get_completion_item()
    local trigger = completion_item.label

    -- Try to determine if this is an autosnippet or regular snippet
    local is_auto = false
    local snippet_obj = nil

    -- Look for the actual snippet object
    local ls_ok, ls = pcall(require, "luasnip")
    if ls_ok and ls and ls.snippets and ls.autosnippets then
      -- Check autosnippets first
      local filetypes = { vim.bo.filetype, "all" }
      for _, ft in ipairs(filetypes) do
        if ls.autosnippets and ls.autosnippets[ft] then
          for _, snip in ipairs(ls.autosnippets[ft]) do
            if snip and snip.trigger == trigger then
              snippet_obj = snip
              is_auto = true
              break
            end
          end
        end

        if not snippet_obj and ls.snippets[ft] then
          for _, snip in ipairs(ls.snippets[ft]) do
            if snip and snip.trigger == trigger then
              snippet_obj = snip
              is_auto = false
              break
            end
          end
        end

        if snippet_obj then
          break
        end
      end
    end

    -- If we found the actual snippet object, check its context or condition
    if snippet_obj then
      -- First check for explicit context property
      if snippet_obj.context and snippet_obj.context.math then
        if in_math then
          if in_text_command then
            return false
          end
          return true
        end
        return false
      end

      -- Check condition as fallback
      if snippet_obj.condition then
        local condition_str = tostring(snippet_obj.condition)

        -- Check if it has a math condition
        if condition_str:match("in_mathzone") or condition_str:match("is_math") then
          if in_math and in_text_command then
            return false
          end
          return in_math -- Only show in math
        elseif condition_str:match("not_math") or condition_str:match("in_text") then
          return not in_math -- Only show outside math
        end
      end
    end

    -- Get info from our registry
    local is_our_math_snippet = M.is_our_math_snippet(trigger, is_auto)
    local is_our_non_math_snippet = M.is_our_non_math_snippet(trigger, is_auto)
    local snippet_is_math = snippet_obj and snippet_obj.context and snippet_obj.context.math

    -- For third-party snippets, use pattern matching
    -- Inside math zones:
    if in_math then
      if in_text_command and (snippet_is_math or is_our_math_snippet) then
        return false
      end

      if snippet_is_math or is_our_math_snippet then
        return true
      end

      if block_markdown_text_in_math then
        return false
      end

      if is_our_non_math_snippet then
        return false
      end

      return true
    elseif in_code then
      -- Block all snippets in code blocks
      return false
    else
      return true
    end
  end

  -- Expose the implementation
  M._filter_completion_impl = filter_completion_impl

  -- Public filter_completion function
  M.filter_completion = function(entry, ctx)
    local kind = entry:get_kind()
    local is_snippet = kind == 15 -- kinds.Snippet = 15

    if not is_snippet then
      return true -- Allow non-snippet completions
    end

    -- Get context information
    local in_math = latex_snippets.is_in_math()
    local in_code = latex_snippets.is_in_code_block()

    -- Get the snippet trigger
    local completion_item = entry:get_completion_item()
    local trigger = completion_item.label

    -- Use the filter implementation
    local result = filter_completion_impl(entry, ctx, latex_snippets)

    -- Extra safety check for math snippets outside math
    if not in_math then

      -- Try to determine if it's an autosnippet
      local is_auto = false
      local ls_ok, ls = pcall(require, "luasnip")
      if ls_ok and ls and ls.autosnippets then
        local ft = vim.bo.filetype
        if ls.autosnippets[ft] then
          for _, snip in ipairs(ls.autosnippets[ft]) do
            if snip and snip.trigger == trigger then
              is_auto = true
              break
            end
          end
        end
      end

      -- Check our registry
      local is_our_math_snippet = M.is_our_math_snippet(trigger, is_auto)

      -- if result and (is_our_math_snippet or is_math_pattern) then
      --   return false
      -- end
    end

    return result
  end

  -- Override the snip_expand function to filter snippets
  ls.snip_expand = function(snippet, ...)
    -- Check if we should block this specific snippet expansion
    if not should_allow_snippet_at_cursor(snippet) then
      return false
    end

    -- Allow mk/dm snippets in text mode for markdown/quarto
    if snippet and snippet.trigger then
      local triggers = { "mk", "dm", "Mk", "Dm" }
      local ft = vim.bo.filetype
      if ft == "markdown" or ft == "quarto" then
        if vim.tbl_contains(triggers, snippet.trigger) then
          -- Always allow these special math delimiter snippets
          return original_snip_expand(snippet, ...)
        end
      end
    end

    -- Otherwise proceed with normal expansion
    return original_snip_expand(snippet, ...)
  end
end

return M
