-- Managing citations and cross-references

local ts_query = require("nvim-treesitter.query")
local ts_parsers = require("nvim-treesitter.parsers")
local ts_utils = require("nvim-treesitter.utils")

local M = {}

-- It doesn't make sense to use this in any other language
local lang = "latex"
local query_group = "references"

M.insert_ref = function(label, bufnr)
    label = label or ""
    bufnr = bufnr or vim.fn.bufnr()

    pos = vim.fn.getcurpos()
    row = pos[2] - 1
    col = pos[3] - 1
    refstring = string.format("~\\ref{%s}", label)
    pos[3] = pos[3] + #refstring

    vim.api.nvim_buf_set_text(bufnr, row, col, row, col, {refstring})
    vim.fn.setpos('.', pos)
end

--- Return all nodes for cross-reference definitions
M.get_crossref_defs = function(bufnr)
    bufnr = bufnr or vim.fn.bufnr()
    local matches = ts_query.get_capture_matches(bufnr, '@latex.label', query_group)
    
    return matches
end

M.get_crossref_refs = function(bufnr)
    bufnr = bufnr or vim.fn.bufnr()
    local matches = ts_query.get_capture_matches(bufnr, '@latex.ref', query_group)

    return matches
end

-- Thanks Primeagen (ThePrimeagen/refactoring/ ... region.lua)
M.get_text_in_node = function(node, bufnr)
    -- TODO just use his Range object instead?
    bufnr = bufnr or vim.fn.bufnr()
    local start_row, start_col, end_row, end_col = node:range()
    start_col = start_col + 1

    local text = vim.api.nvim_buf_get_lines(
        bufnr,
        start_row,
        end_row + 1,
        false
    )

    local text_length = #text
    local end_col = math.min(#text[text_length], end_col)
    local end_idx = vim.str_byteindex(text[text_length], end_col)
    local start_idx = vim.str_byteindex(text[1], start_col)

    text[text_length] = text[text_length]:sub(1, end_idx)
    text[1] = text[1]:sub(start_idx)

    return table.concat(text, '\n')
end

return M
