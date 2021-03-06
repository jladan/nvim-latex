-- nvim-latex
-- ==========
--
-- A few tools to make working with latex documents easier in neovim

local ts_query = require("nvim-treesitter.query")
local utils = require("nvim-latex.utils")
local changedtick = vim.api.nvim_buf_get_changedtick

local log = require("nvim-latex.log")

-- file introspection {{{

-- Check if the current document has a \documentclass macro
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

--- Find the default file in a latexmkrc
local function main_from_latexmkrc(rc)
    local lines = vim.fn.readfile(vim.fn.fnamemodify(rc, ':p'))
    for _, line in ipairs(lines) do
        match = line:match( '@default_files.-[\'"](.-)[\'"]')
        if match then 
            return match
        end
    end
end

--- My own get_captures function
--
-- This is necessary, because nvim-treesitter won't work if the filetype isn't
-- set.
local function get_captures(bufnr, group, capture)
    local query = vim.treesitter.get_query('latex', group)
    local root = vim.treesitter.get_parser(bufnr, 'latex'):trees()[1]:root()
    local matches = {}
    for id, node, meta in query:iter_captures(root, bufnr) do
        if query.captures[id] == capture then
            table.insert(matches, node)
        end
    end
    return matches
end

-- }}}

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
--      bibs    : all the bibtex files as a set {<bibfile> = <bufnr>}
--      files   : all the .tex files  as a set {<bibfile> = <bufnr>}
M._docdata = {}
--- Get the document data object for the document specified by docpath
--  (create a new one if it doesn't exist)
function M.get_docdata(docpath)
    docpath = vim.fn.fnamemodify(docpath, ':~:r')
    if not M._docdata[docpath] then 
        M._docdata[docpath] = {}
    end
    return M._docdata[docpath]
end

-- The Data structure for tex file metadata.
-- Metadata is tied to the buffer number : `M._filedata[<bufnr>]`
-- Contents:
--      doc     : the main document's metadata object
--      bibs    : a list of bibtex files to look up citaitons in
--      inputs  : {lineno : path} list `\input` macros in current file
M._filedata = {}
function M.get_filedata(bufnr)
    if not M._filedata[bufnr] then 
        M._filedata[bufnr] = {}
        M._filedata[bufnr]._tick = -1
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
    log.debug("Called 'set_doc_root' on " .. vim.fn.bufname(bufnr))

    local docfile = M.find_docfile(bufnr)
    local docdata = M.get_docdata(docfile)
    docdata.docfile = docfile
    docdata.root = vim.fn.fnamemodify(docfile, ':h')

    log.debug("*set_doc_root* returning " .. docdata.root)
    return docdata
end

function M.find_docfile(bufnr)
    bufnr = bufnr or vim.fn.bufnr()
    log.debug("Called 'find_docfile' on " .. vim.fn.bufname(bufnr))
    --assert(vim.bo[bufnr].filetype == "tex", string.format("Buffer %d is not a tex file", bufnr))

    local thisfile = vim.fn.bufname(bufnr)
    thisfile = vim.fn.fnamemodify(thisfile, ":~")

    -- Default to current file
    local docfile = thisfile
    -- If \documentclass is in thisfile, then it should be the root
    if has_docclass(bufnr) then
        log.info("*find_docfile* documentclass found in " .. thisfile)
        docfile = thisfile
    else
        log.debug("*find_docfile* looking for latexmkrc")
        -- Try looking for a latexmkrc
        local curbuf = vim.fn.bufnr() -- XXX findfile is relative to "current file"
        vim.api.nvim_set_current_buf(bufnr)
        local latexmkrc = vim.fn.findfile('.latexmkrc', '.;')
        if latexmkrc ~= "" then
            log.info("*find_docfile* found latexmkrc*")
            latexmkrc = vim.fn.fnamemodify(latexmkrc, ':~')
            local main = main_from_latexmkrc(latexmkrc)
            if main then
                log.info("*find_docfile* from latexmkrc, found " .. main)
                local path = vim.fn.fnamemodify(latexmkrc, ':~:h')
                docfile = path .. '/' .. main
            end
        else
            -- If all else fails, just use the current file?
            docfile = thisfile
        end
        vim.api.nvim_set_current_buf(curbuf)
    end
    log.debug("*find_docfile* returning " .. vim.fn.fnamemodify(docfile, ':~'))
    return vim.fn.fnamemodify(docfile, ':~')
end
-- }}}

-- Bibliographies {{{
-- Find any bibtex files that are included in the file, and add them to the document
function M.set_bibliographies(bufnr)
    bufnr = bufnr or vim.fn.bufnr()
    log.debug("Called 'set_bibs' on " .. vim.fn.bufname(bufnr))
    local matches = get_captures(bufnr, 'references', 'bibliography.path')

    local data = M.get_filedata(bufnr)
    local root = data.doc.root
    local paths = {}
    -- XXX There should only actually be one match, but this works anyway
    -- it may be safer than just picking the first
    for _, node in ipairs(matches) do
        local bibfiles = utils.get_text_in_node(node, bufnr)
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

    -- add the bibtex files into the doc data
    data.bibs = utils.file_set(paths)
    if not data.doc.bibs then
        data.doc.bibs = {}
    end
    utils.extend_set(data.doc.bibs, utils.file_set(paths))
    
    return paths
end
-- }}}

-- Tex files {{{
-- Find tex files in the .log
-- 
-- The problem with this method is that we don't know where in the document the
-- input file goes.
function M.files_in_log(bufnr)
    bufnr = bufnr or vim.fn.bufnr()

    data = M.get_filedata(bufnr)
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
                table.insert(files, vim.fn.fnamemodify(file, ':~'))
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
    log.debug("Called 'inputs_in_buf' on " .. vim.fn.bufname(bufnr))
    
    local inputs = get_captures(bufnr, 'outline', 'input.path')
    local files = {}
    for _, node in ipairs(inputs) do
        local fname = utils.get_text_in_node(node, bufnr)
        if string.sub(fname, -4, -1) ~= '.tex' then
            fname = fname .. '.tex'
        end
        table.insert(files, fname)
    end

    return files
end

-- }}}

-- Document setup {{{

local function doc_changed(docdata)
    local result = false
    if not docdata.files then
        return true
    else
        for _, bufnr in pairs(docdata.files) do
            result = result or  M.get_filedata(bufnr)._tick < changedtick(bufnr)
        end
    end
    return result
end
--- Set up the document data for the whole document
function M.setup_document(bufnr, force)
    bufnr = bufnr or vim.fn.bufnr()
    log.debug("Called 'setup_document' on " .. vim.fn.bufname(bufnr))
    local fdata = M.get_filedata(bufnr)
    local docdata = fdata.doc or M.set_document_root(bufnr)

    if doc_changed(docdata) then
        local bufnr = vim.fn.bufnr(vim.fn.expand(docdata.docfile), true)
        -- XXX We request an update of all files because it would be hard to find removed files
        -- This seems fast enough in use
        docdata.files = {}
        docdata.files[docdata.docfile] = bufnr
        M._set_files(vim.fn.bufnr(vim.fn.expand(docdata.docfile), true), docdata)
    else
        log.debug("Document unchanged")
    end
end

local function update_file(bufnr, docdata)
    local fdata = M.get_filedata(bufnr)
    if fdata._tick < changedtick(bufnr) then
        fdata.doc = docdata
        M.set_bibliographies(bufnr)
        fdata.files = utils.file_set(M.inputs_in_buf(bufnr))
        fdata._tick = changedtick(bufnr)
    else
        log.debug("file has not been changed since last scan")
    end
    return fdata
end

function M._set_files(bufnr, docdata)
    log.debug("Called '_set_files' on " .. vim.fn.bufname(bufnr))
    vim.fn.bufload(bufnr)
    -- The create the data for current buffer, and assign the document to it
    local data = update_file(bufnr, docdata)
    -- Begin setting files
    for file, bufnr in pairs(data.files) do
        -- if the file is already in data.doc.files, then it has already been loaded
        -- We skip loaded files to avoid infinite loops
        if not data.doc.files[file] then
            data.doc.files[file] = bufnr
            M._set_files(bufnr, docdata)
        end
    end
end

-- }}}


return M
