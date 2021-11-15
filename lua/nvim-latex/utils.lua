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

-- Extend a list with values from a second list
M.extend = function(a, b)
    for _, x in ipairs(b) do
        table.insert(a, x)
    end
end

--- Keep only the first instance of an item in a list
M.unique = function(list)
    local set = {}
    local keys = {}
    for _, x in ipairs(list) do
        if not keys[x] then
            keys[x] = true
            table.insert(set, x)
        end
    end
    return set
end

--- Take a list of filenames, and convert it to a set {filename = <bufnr>}
M.file_set = function(filelist)
    local fset = {}
    for _, f in ipairs(filelist) do
        fset[f] = vim.fn.bufnr(f, true)
    end
    return fset
end

--- Extend a set with a second set (writing over previous values)
M.extend_set = function(a, b)
    for k, v in pairs(b) do
        a[k] = v
    end
end

return M
