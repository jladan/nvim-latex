-- Managing citations and cross-references

local ts_query = require("nvim-treesitter.query")
local ts_parsers = require("nvim-treesitter.parsers")
local ts_utils = require("nvim-treesitter.utils")
local utils = require("nvim-latex.utils")

local M = {}

-- It doesn't make sense to use this in any other language
local lang = "latex"
local query_group = "references"

-- insert text at current cursor position
local function insert_text(text, bufnr)
    bufnr = bufnr or vim.fn.bufnr()

    pos = vim.fn.getcurpos()
    row = pos[2] - 1
    col = pos[3] - 1
    pos[3] = pos[3] + #text

    vim.api.nvim_buf_set_text(bufnr, row, col, row, col, {text})
    vim.fn.setpos('.', pos)
end

-- Insert a cross-reference at the current cursor position
M.insert_ref = function(label, bufnr)
    label = label or ""

    refstring = string.format("~\\ref{%s}", label)
    insert_text(refstring, bufnr)
end

-- Insert a citation at the current cursor position
M.insert_citation = function(label, bufnr)
    label = label or ""
    refstring = string.format("~\\cite{%s}", label)
    insert_text(refstring, bufnr)
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
