-- Managing citations and cross-references

local ts_query = require("nvim-treesitter.query")
local ts_parsers = require("nvim-treesitter.parsers")
local ts_utils = require("nvim-treesitter.utils")
local utils = require("nvim-latex.utils")
local doc = require("nvim-latex")

local M = {}

-- It doesn't make sense to use this in any other language
local lang = "latex"
local query_group = "references"


-- Insert a reference at the current cursor position
-- @label : the reference label or key
-- @normal_mode : whether this is called in normal mode or insert mode
-- @macroname : the name of the macro to use in the reference (ref, eqref, cite, etc)
M.insert_ref = function(label, normal_mode, macroname)
    label = label or ""
    local after = normal_mode or false
    macroname = macroname or 'ref'
    if type(label) == "table" then
        label = table.concat(label, ",")
    end
    refstring = string.format("~\\%s{%s}", macroname, label)
    vim.api.nvim_put({refstring}, "c", after, true)
end

--- Return all nodes for cross-reference definitions
M.get_crossref_defs = function(bufnr)
    bufnr = bufnr or vim.fn.bufnr()
    local matches = ts_query.get_capture_matches(bufnr, '@latex.label', query_group)
    for _, m in ipairs(matches) do
        m.bufnr = bufnr
    end
    
    return matches
end

M.get_crossref_refs = function(bufnr)
    bufnr = bufnr or vim.fn.bufnr()
    local matches = ts_query.get_capture_matches(bufnr, '@latex.ref', query_group)
    for _, m in ipairs(matches) do
        m.bufnr = bufnr
    end

    return matches
end

-- Make a list of all the bibtex entries in bibliographies
function M.get_citations(bufnr)
    bufnr = bufnr or vim.fn.bufnr()
    local entries = {}
    for _, bib in ipairs(vim.b.latex_bibs or doc.set_bibliographies(bufnr)) do
        bibbuf = vim.fn.bufnr(bib, true)
        -- The buffer has to be loaded for nvim-treesitter
        vim.fn.bufload(bibbuf)
        local matches = ts_query.get_capture_matches(bibbuf, '@entry.key', "references")
        for _, m in ipairs(matches) do
            m.bufnr = bibbuf
            table.insert(entries, m)
        end
    end
    return entries
end

return M
