-- Telescope pickers for latex

local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local config = require "telescope.config".values

local latex = require "nvim-latex"

local M = {}

-- TODO
local make_entry_from_ref = function(entry)
    local node = entry.node
    local text = latex.get_text_in_node(node) -- TODO handle bufnr better

    return {
        value = node,
        ordinal = text,
        display = text,
        -- Can add other data like the buf number
        bufnr = 0, -- TODO
        lnum = 1, -- TODO
    }
end

-- List all references, and throw in a \ref{}
--   TODO navigate to definition
M.cross_reference = function(opts)
    local opts = opts or {}

    -- TODO I'll need to be smarter about what buffer to use
    -- e.g. if there are multiple files for one document
    local ref_list = latex.get_crossref_defs(vim.fn.bufnr())

    pickers.new(opts, {
        prompt_title = "Insert cross reference",
        finder = finders.new_table({
            results = ref_list,
            entry_maker = make_entry_from_ref,
        }),
        previewer = config.qflist_previewer(opts), 
        sorter = config.generic_sorter(opts),
    }):find()
end

return M
