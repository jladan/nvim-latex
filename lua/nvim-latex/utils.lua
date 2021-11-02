-- Managing citations and cross-references

local ts_query = require("nvim-treesitter.query")
local ts_parsers = require("nvim-treesitter.parsers")
local ts_utils = require("nvim-treesitter.utils")

local M = {}

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
