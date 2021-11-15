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

-- Document file data {{{
-- The "Main document's metadata object", `M._docdata[<main-file>]` is to be
--      shared by all buffers from the same document. 
-- <main-file> is the rootfile of the document with the extension stripped. To
--      ensure uniqueness, the full path is used.
--      E.g. "~/path/to/full-document.tex" -> "~/path/to/full-document"
-- Contents:
--      root    : the root directory of the project
--      docfile : the .tex file that gets compiled
--      bibs    : all the bibtex files
--      files   : all the .tex files (just a list of files)
M._docdata = {}
--- Get the document data object for the document specified by docpath
--  (create a new one if it doesn't exist)
local function get_docdata(docpath)
    docpath = vim.fn.fnamemodify(docpath, ':~:r')
    if not M._docdata[docpath] then 
        M._docdata[docpath] = {}
    end
    return M._docdata[docpath]
end

-- The Data structure for tex file metadata.
-- Metadata is tied to the buffer number : `M._filedata[<bufnr>]`
-- Contents:
--      main    : the main document's metadata object
--      bibs    : a list of bibtex files to look up citaitons in
--      inputs  : {lineno : path} list `\input` macros in current file
M._filedata = {}
local function get_filedata(bufnr)
    if not M._filedata[bufnr] then 
        M._filedata[bufnr] = {}
    end
    return M._filedata[bufnr]
end
-- }}}

-- setting the document file and root {{{
---- Set the name and root directory of the main latex document that's being edited
--
-- Also sets `M._filedata[bufnr] = M._docdata[<docfile>]` to link the doc data
-- to the file data
function M.set_document_root(bufnr)
    bufnr = bufnr or vim.fn.bufnr()

    local docfile = M.find_docfile(bufnr)
    local docdata = get_docdata(docfile)
    docdata.docfile = docfile
    docdata.root = vim.fn.fnamemodify(docfile, ':h')

    local fdata = get_filedata(bufnr)
    fdata.doc = docdata

    return docdata.root
end

function M.find_docfile(bufnr)
    bufnr = bufnr or vim.fn.bufnr()
    assert(vim.bo[bufnr].filetype == "tex", string.format("Buffer %d is not a tex file", bufnr))

    local thisfile = vim.fn.bufname(bufnr)
    thisfile = vim.fn.fnamemodify(thisfile, ":p")

    -- Default to current file
    local docfile = thisfile
    -- If \documentclass is in thisfile, then it should be the root
    if has_docclass(bufnr) then
        docfile = thisfile
    else
        -- Try looking for a latexmkrc
        local curbuf = vim.fn.bufnr() -- XXX findfile is relative to "current file"
        vim.api.nvim_set_current_buf(bufnr)
        local latexmkrc = vim.fn.findfile('.latexmkrc', '.;')
        if latexmkrc ~= "" then
            latexmkrc = vim.fn.fnamemodify(latexmkrc, ':p')
            local main = main_from_latexmkrc(latexmkrc)
            if main then
                local path = vim.fn.fnamemodify(latexmkrc, ':p:h')
                docfile = path .. '/' .. main
            end
        else
            -- If all else fails, just use the current file?
            docfile = thisfile
        end
        vim.api.nvim_set_current_buf(curbuf)
    end
    return vim.fn.fnamemodify(docfile, ':~')
end
-- }}}

-- Find any bibtex files that are included in the document
function M.set_bibliographies(bufnr)
    bufnr = bufnr or vim.fn.bufnr()
    local matches = ts_query.get_capture_matches(bufnr, '@bibliography.path', "references")

    local data = get_data(bufnr)
    local root = data.root or M.set_document_root(bufnr)
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

    data.bibs = paths
    
    return paths
end

-- Find tex files in the .log
-- 
-- The problem with this method is that we don't know where in the document the
-- input file goes.
function M.files_in_log(bufnr)
    bufnr = bufnr or vim.fn.bufnr()

    data = get_data(bufnr)
    local mainfile = data.main or M.set_document_root(bufnr) and data.main
    local logfile = vim.fn.fnamemodify(mainfile, ':r') .. '.log'
    -- check if log file exists
    local files = {}
    if vim.fn.filereadable(logfile) == 1 then
        nextLine = io.lines(logfile)
        -- find the bit starting with *File List*
        while not string.match(nextLine(), '%*File List') do end
        -- pull all tex files until *******
        for line in nextLine do
            if string.match(line, ' %*+') then break end
            file = string.match(line, '[^%s]+%.tex')
            if file then
                table.insert(files, vim.fn.fnamemodify(file, ':p'))
            end
        end
    end
    return  files
end

-- Get the input files in the buffer
-- 
-- Using a treesitter query will allow us to know there inside the file the
-- input goes. This will be necessary for the outlines.
function M.inputs_in_buf(bufnr)
    bufnr = bufnr or vim.fn.bufnr()
    
    local inputs = ts_query.get_capture_matches(bufnr, '@input', 'outline')
    local files = {}
    for _, m in ipairs(inputs) do
        local fname = utils.get_text_in_node(m.path.node)
        if string.sub(fname, -4, -1) ~= '.tex' then
            fname = fname .. '.tex'
        end
        table.insert(files, fname)
    end

    return files
end

-- Add the list of input files to the buffer's data
function M.set_file_list(bufnr)
    bufnr = bufnr or vim.fn.bufnr()

    local data = get_data(bufnr)
    data.files = M.inputs_in_buf(bufnr)
end

--- Recursively set the document root and file list for each file referenced in the buffer
--
-- Currently, each buffer has a different list of files.
-- TODO: share files among all buffers, and maybe have a list of subfiles
function M.recurse_set_vals(bufnr)
    bufnr = bufnr or vim.fn.bufnr()

    local data = get_data(bufnr)
    M.set_document_root(bufnr)
    M.set_bibliographies(bufnr)
    M.set_file_list(bufnr)
    for _, file in ipairs(data.files) do
        fbuf = vim.fn.bufnr(file, true)
        M.recurse_set_vals(fbuf)
    end
end


return M
