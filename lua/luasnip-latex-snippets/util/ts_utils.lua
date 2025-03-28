local M = {}

local MATH_NODES = {
    displayed_equation = true,
    inline_formula = true,
    math_environment = true,
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
                -- For \text{}
                local parent = node:parent()
                if parent and MATH_NODES[parent:type()] then
                    return false
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
    if not node then return false end
    
    -- Get the current line and check for common code block indicators in quarto/rmd
    local row = vim.fn.line(".") - 1
    local current_line = vim.api.nvim_buf_get_lines(0, row, row+1, false)[1] or ""
    
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
                        if attr:type() == "attribute" and attr:named_child(0) and 
                           attr:named_child(0):type() == "attribute_name" and 
                           vim.treesitter.get_node_text(attr:named_child(0), 0) == "class" and
                           attr:named_child(1) and attr:named_child(1):type() == "quoted_attribute_value" then
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
    local prev_line = vim.api.nvim_buf_get_lines(0, math.max(0, row-1), row, false)[1] or ""
    local next_line = vim.api.nvim_buf_get_lines(0, row+1, row+2, false)[1] or ""
    
    -- If the previous line starts a code block
    if prev_line:match("^%s*```%s*{?%s*[a-z]+") then
        -- And we haven't yet seen an end marker
        if not current_line:match("^%s*```%s*$") then
            return true
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
    
    -- Additional checks for markdown/quarto
    if current_filetype == "markdown" or current_filetype == "quarto" then
        -- Extra specific checks for markdown/quarto code blocks
        local block_node = node
        while block_node do
            if CODE_BLOCK_NODES[block_node:type()] then
                return false
            end
            block_node = block_node:parent()
        end
    end

    while node do
        if TEXT_NODES[node:type()] then
            return false
        elseif MATH_NODES[node:type()] then
            return true
        end
        node = node:parent()
    end
    return false
end

return M
