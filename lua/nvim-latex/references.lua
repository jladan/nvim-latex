-- Managing citations and cross-references

local ts_query = require("nvim-treesitter.query")
local ts_parsers = require("nvim-treesitter.parsers")
local ts_utils = require("nvim-treesitter.utils")
local utils = require("nvim-latex.utils")

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

return M
