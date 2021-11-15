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

-- XXX This new spec is not implemented yet
-- The Data structure for all document metadata.
-- Metadata is tied to the buffer number : {bufnr = {data}}
-- Contents:
--      main    : the main document's metadata object
--      bibs    : a list of bibtex files to look up citaitons in
--      inputs  : {lineno : path} list `\input` macros in current file
--  The "Main document's metadata object" should be shared by all buffers from
--  the same document.
--  Contents:
--      root    : the root directory of the project
--      docfile : the .tex file that gets compiled
--      bibs    : all the bibtex files
--      files   : all the .tex files (just a list of files)
-- TODO figure out how/where to store the Project's metadata, so that it's
--      easy to find for all files
M._data = {}
local function get_data(bufnr)
    if not M._data[bufnr] then 
        M._data[bufnr] = {}
    end
    return M._data[bufnr]
end

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

    local data = get_data(bufnr)

    -- Start with the directory of rootfile
    local thisdir = vim.fn.fnamemodify(thisfile, ":h")
    -- If \documentclass is in thisfile, then it should be the root
    if has_docclass(bufnr) then
        data.root = thisdir
        data.main = thisfile
    else
        -- Try looking for a latexmkrc
        local latexmkrc = vim.fn.findfile('.latexmkrc', '.;')
        if latexmkrc ~= "" then
            data.root = vim.fn.fnamemodify(latexmkrc, ':p:h')
            data.main = data.root .. '/' .. main_from_latexmkrc(latexmkrc)
        else
            -- If all else fails, just use the current file?
            data.root = thisdir
            data.main = thisfile
        end
    end

    return data.root
end

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
