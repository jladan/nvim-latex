-- nvim-latex
-- ==========
--
-- A few tools to make working with latex documents easier in neovim

-- TODO decide on what if anything goes in the main module

local ts_query = require("nvim-treesitter.query")
local utils = require("nvim-latex.utils")

local M = {}

-- Set the name of the main latex document that's being edited
-- This will matter for multi-file documents
-- TODO should this be a buffer variable or module-level?
function M.set_document_root(bufnr, rootfile)
    -- Default to current buffer, and buffer filename
    bufnr = bufnr or vim.fn.bufnr()
    rootfile = rootfile or vim.fn.bufname(bufnr)

    -- now get the absolute path and filename for use in the rest
    vim.b.latex_root = vim.fn.fnamemodify(rootfile, ":p:h")
    vim.b.latex_main = vim.fn.fnamemodify(rootfile, ":p")

    return vim.b.latex_root
end

-- Find any bibtex files that are included in the document
function M.set_bibliographies(bufnr)
    bufnr = bufnr or vim.fn.bufnr()
    local matches = ts_query.get_capture_matches(bufnr, '@bibliography.path', "references")

    local root = vim.b.latex_root or M.set_document_root(bufnr)
    local paths = {}
    for _, m in ipairs(matches) do
        local p = utils.get_text_in_node(m.node, bufnr)
        -- TODO handle with document root
        if string.lower(string.sub(p, -4, -1)) ~= ".bib" then
            p = p .. ".[bB][iI][bB]"
        end
        for _, fname in ipairs(vim.fn.globpath(root, p, true, true)) do
            table.insert(paths, vim.fn.simplify(fname))
        end
    end

    vim.b.latex_bibs = paths
    
    return paths
end

-- Make a list of all the bibtex entries in bibliographies
function M.collect_citations(bufnr)
    bufnr = bufnr or vim.fn.bufnr()
    local entries = {}
    for _, bib in ipairs(vim.b.latex_bibs or M.set_bibliographies(bufnr)) do
        bibbuf = vim.fn.bufnr(bib, true)
        -- The buffer has to be loaded for nvim-treesitter
        vim.fn.bufload(bibbuf)
        local matches = ts_query.get_capture_matches(bibbuf, '@entry', "references")
        for _, m in ipairs(matches) do
            m.bufnr = bibbuf
            table.insert(entries, m)
        end
    end
    local keys = {}
    for _, e in ipairs(entries) do
        if e.key then
            table.insert(keys, utils.get_text_in_node(e.key.node, e.bufnr))
        end
    end
    return keys
end

return M
