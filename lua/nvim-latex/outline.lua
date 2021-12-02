-- Outline window/buffer module


local meta = require('nvim-latex')
local DocNode = require('nvim-latex.doctree')

local outline = {}

-- Create the outline buffer
function outline.make_buffer()
    local  bufnr = vim.api.nvim_create_buf(false, true)
    -- XXX  buffer names bust be unique
    --vim.api.nvim_buf_set_name(bufnr, "[OUTLINE]")
    vim.api.nvim_buf_set_option(bufnr, 'filetype', 'outline')
    --vim.api.nvim_buf_set_option(bufnr, 'readonly', true)
    return bufnr
end

-- Toggle outline buffer
function outline.toggle_for(bufnr)
    local bufnr = bufnr or vim.fn.bufnr()
    local fdata = meta.get_filedata(bufnr)
    if not fdata.outline then
        fdata.outline = { bufnr = outline.make_buffer(), }
    end
    -- Check to see if the buffer is open in a visible window
    local winid = vim.fn.bufwinid(fdata.outline.bufnr)
    if winid == -1 then
        outline.open_for(bufnr)
    else
        vim.api.nvim_win_hide(winid)
    end
end

-- Open an outline for the current buffer
function outline.open_for(bufnr)
    local bufnr = bufnr or vim.fn.bufnr()
    local fdata = meta.get_filedata(bufnr)
    if not fdata.outline then
        fdata.outline = { bufnr = outline.make_buffer(), }
    end
    -- Open a new window beside
    local curwin = vim.api.nvim_get_current_win()
    vim.cmd(':vsplit +b'..fdata.outline.bufnr)
    local outwin = vim.api.nvim_get_current_win()
    outline._win_options(outwin)
    vim.api.nvim_set_current_win(curwin)
    outline._print_for(bufnr, fdata)
end

function outline._win_options(win)
    vim.api.nvim_win_set_option(win, 'number', false)
    vim.api.nvim_win_set_option(win, 'relativenumber', false)
    vim.api.nvim_win_set_option(win, 'signcolumn', 'no')
end


-- Print the outline into the buffer
function outline._print_for(bufnr, fdata)
    bufnr = bufnr or vim.fn.bufnr()
    fdata = fdata or meta.get_filedata(bufnr)
    local tree = fdata.doctree or DocNode:from_buffer(bufnr)
    vim.api.nvim_buf_set_lines(fdata.outline.bufnr, 0, -1, false, tree:prettify())
end

-- Possibly Useful functions:
--  nvim_win_get_buf()
--  nvim_win_get_tabpage
--  nvim_win_hide
--  win_findbuf() : gits list with ids for windows containing bufnr
--  win_gitid([win, [tab]]) : window id from window number
--  win_id2win, or win_id2tabwin
--
--  nvim set_current_win()
--  nvim_list_wins()
--
--  nvim_buf_set_lines()
--  nvim_buf_add_highlight()
--  nvim_buf_set_extmark() for tracking important locations in files

-- nvim_buf_call
-- nvim_win_call

return outline
