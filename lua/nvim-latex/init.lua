-- nvim-latex
-- ==========
--
-- A few tools to make working with latex documents easier in neovim

-- TODO decide on what if anything goes in the main module

local ts_query = require("nvim-treesitter.query")
local utils = require("nvim-latex.utils")

local function has_docclass(bufnr)
    -- Store the current location before searching
    local pos = vim.fn.getcurpos()
    local curbuf = vim.fn.bufnr()
    bufnr = bufnr or curbuf

    -- search for the document class macro
    vim.api.nvim_set_current_buf(bufnr)
    local found = vim.fn.search("^\\s*\\\\documentclass")
    -- return to original position
    -- This may cause the window to center on current line (:normal zz)
    vim.api.nvim_set_current_buf(curbuf)
    vim.fn.cursor(pos[2],pos[3])
    return found > 0
end

local function main_from_latexmkrc(rc)
    local lines = vim.fn.readfile(rc)
    for _, line in ipairs(lines) do
        match = line:match( '@default_files.-[\'"](.-)[\'"]')
        if match then 
            return match
        end
    end
end

local M = {}

M.has_docclass = has_docclass
M.test = main_from_latexmkrc

---- Set the name of the main latex document that's being edited
--
-- This will matter for multi-file documents.
-- Current strategy choose in order:
--  - the file if it has a documentclass declaration
--  - the first default file in the .latexmkrc
--  - the file as a last resort
--
-- TODO should this be a buffer variable or module-level?
function M.set_document_root(bufnr)
    -- Default to current buffer, and buffer filename
    bufnr = bufnr or vim.fn.bufnr()
    local thisfile = vim.fn.bufname(bufnr)
    thisfile = vim.fn.fnamemodify(thisfile, ":p")

    -- Start with the directory of rootfile
    local thisdir = vim.fn.fnamemodify(thisfile, ":h")
    -- If \documentclass is in thisfile, then it should be the root
    if has_docclass(bufnr) then
        vim.b.latex_root = thisdir
        vim.b.latex_main = thisfile
    else
        -- Try looking for a latexmkrc
        local latexmkrc = vim.fn.findfile('.latexmkrc', '.;')
        if latexmkrc ~= "" then
            vim.b.latex_root = vim.fn.fnamemodify(latexmkrc, ':p:h')
            vim.b.latex_main = vim.b.latex_root .. '/' .. main_from_latexmkrc(latexmkrc)
        else
            -- If all else fails, just use the current file?
            vim.b.latex_root = thisdir
            vim.b.latex_main = thisfile
        end
    end

    return vim.b.latex_root
end

-- Find any bibtex files that are included in the document
function M.set_bibliographies(bufnr)
    bufnr = bufnr or vim.fn.bufnr()
    local matches = ts_query.get_capture_matches(bufnr, '@bibliography.path', "references")

    local root = vim.b.latex_root or M.set_document_root(bufnr)
    local paths = {}
    -- XXX There should only actually be one match, but this works anyway
    -- it may be safer than just picking the first
    for _, m in ipairs(matches) do
        local bibfiles = utils.get_text_in_node(m.node, bufnr)
        -- multiple bibtex files are in a comma-delimited list
        for _, p in ipairs(vim.fn.split(bibfiles, ",\\s*")) do
            if string.lower(string.sub(p, -4, -1)) ~= ".bib" then
                p = p .. ".[bB][iI][bB]"
            end
            for _, fname in ipairs(vim.fn.globpath(root, p, true, true)) do
                table.insert(paths, vim.fn.simplify(fname))
            end
        end
    end

    vim.b.latex_bibs = paths
    
    return paths
end

return M
