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

-- Cross-references {{{
--- Return all nodes for cross-reference definitions
M.get_crossref_defs = function(bufnr, root)
    bufnr = bufnr or vim.fn.bufnr()
    local matches = ts_query.get_capture_matches(bufnr, '@label', query_group, root)
    for _, m in ipairs(matches) do
        m.bufnr = bufnr
        m.label = utils.get_text_in_node(m.node, bufnr)
    end
    
    return matches
end

-- Find all the label definitions inside a multi-file document
M.label_defs = function(bufnr)
    bufnr = bufnr or vim.fn.bufnr()
    local fdata = doc._filedata[bufnr]
    local matches = {}
    if fdata and fdata.doc.files then
        for file, bufnr in pairs(fdata.doc.files) do
            utils.extend(matches, M.get_crossref_defs(bufnr))
        end
    else
        matches = M.get_crossref_defs(bufnr)
    end
    return matches
end

M.get_crossref_refs = function(bufnr, root)
    bufnr = bufnr or vim.fn.bufnr()
    local matches = ts_query.get_capture_matches(bufnr, '@ref', query_group, root)
    for _, m in ipairs(matches) do
        m.bufnr = bufnr
    end

    return matches
end

-- }}}

-- Equation references {{{

--- Find equation labels using vim.treesitter directly (alternate)
M.get_eq_labels = function(bufnr, root)
    bufnr = bufnr or vim.fn.bufnr()
    local matches = ts_query.get_capture_matches(bufnr, '@eq-label', query_group, root)
    for _, m in ipairs(matches) do
        m.bufnr = bufnr
        m.label = utils.get_text_in_node(m.node, bufnr)
    end
    return matches
end

-- Find all the label definitions inside a multi-file document
M.eq_defs = function(bufnr)
    bufnr = bufnr or vim.fn.bufnr()
    local fdata = doc._filedata[bufnr]
    local matches = {}
    if fdata and fdata.doc.files then
        for file, bufnr in pairs(fdata.doc.files) do
            utils.extend(matches, M.get_eq_labels(bufnr))
        end
    else
        matches = M.get_eq_labels(bufnr)
    end
    return matches
end


--- Find equation labels using vim.treesitter directly (alternate)
--
-- Differs from the main implementation in that it:
--   - supports metadata from vim.treesitter
--   - allows searching a subset of the document
M.get_eq_labels_alt = function(bufnr, root, startrow, endrow)
    bufnr = bufnr or vim.fn.bufnr()
    root = root or vim.treesitter.get_parser(bufnr, lang):trees()[1]:root()
    local query = vim.treesitter.get_query(lang, query_group)
    -- Find out the capture id for eq-label
    local cap_id
    for k, v in pairs(query.captures) do
        if v == "eq-label" then
            cap_id = k
            break
        end
    end
    local eqlabels = {}
    for id, node, meta in query:iter_captures(root, 1, startrow, endrow) do
        if id == cap_id then
            table.insert(eqlabels, {bufnr=bufnr, node=node, metadata=meta})
        end
    end
    return eqlabels
end

-- }}}

-- Citations {{{

-- Make a list of all the bibtex entries in bibliographies
function M.get_citations(bufnr)
    bufnr = bufnr or vim.fn.bufnr()
    -- get the document data for the buffer
    local fdata = doc._filedata[bufnr]
    if not fdata then
        return
    end
    local entries = {}
    for file, _ in pairs(fdata.doc.bibs or {}) do
        bibbuf = vim.fn.bufnr(file, true)
        -- The buffer has to be loaded for nvim-treesitter
        vim.fn.bufload(bibbuf)
        local matches = ts_query.get_capture_matches(bibbuf, '@entry', "references")
        for _, m in ipairs(matches) do
            m.bufnr = bibbuf
            m.label = utils.get_text_in_node(m.key.node, bibbuf)
            table.insert(entries, m)
        end
    end
    return entries
end

--- Farm out the citation search to zotero
function M.zotCite()
    local format = 'json'
    local api_call = 'http://127.0.0.1:23119/better-bibtex/cayw?format='..format
    local result = vim.fn.system({"curl", "-s", api_call})
    local cite
    if result ~= "" then
        cite = vim.fn.json_decode(result)[1]
    end
    return cite
end


-- }}}

return M
