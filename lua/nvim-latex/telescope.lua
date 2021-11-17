-- Telescope pickers for latex

local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local config = require "telescope.config".values
local actions = require "telescope.actions"
local state = require "telescope.actions.state"

local references = require "nvim-latex.references"
local utils = require "nvim-latex.utils"

local M = {}

-- TODO fix up with whatever extra info I need.
local make_entry_from_ref = function(entry)
    local node = entry.node
    local text = entry.label

    return {
        value = node,
        ordinal = text,
        display = text,
        -- Can add other data like the buf number
        bufnr = entry.bufnr,
        label = text,
    }
end

-- "Generic" picker to do cross-references and citations
-- @ref_list: the list of matches with {bufnr = <bufnr>, node = <node>}
-- @inserter: function(label, normal_mode?, macro)
-- @macrostring: what macro to insert the reference with
local function ref_picker(ref_list, inserter, macrostring, opts)
    local opts = opts or {}
    local keepinsert = opts.keepinsert or false

    -- TODO handle no matching part of list gracefully
    local function insert_ref(prompt_bufnr)
        local picker = state.get_current_picker(prompt_bufnr)
        local selections = picker._multi:get()
        local label = {}
        if selections and #selections > 0 then
            for _, e in ipairs(selections) do
                table.insert(label, e.label)
            end
        else
            label = state.get_selected_entry(prompt_bufnr).label
        end
        actions._close(prompt_bufnr, keepinsert)
        inserter(label, not keepinsert, macrostring)
    end

    pickers.new(opts, {
        finder = finders.new_table({
            results = ref_list,
            entry_maker = make_entry_from_ref,
        }),
        previewer = nil,
        sorter = config.generic_sorter(opts),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(insert_ref)
            return true
        end,
    }):find()
end

-- List all references, and throw in a \ref{}
--   TODO navigate to definition
M.cross_reference = function(opts)
    -- TODO I'll need to be smarter about what buffer to use
    -- e.g. if there are multiple files for one document
    local ref_list = references.label_defs(vim.fn.bufnr())

    ref_picker(ref_list, references.insert_ref, "ref", opts)
end

-- List all references, and throw in a \eqref{}
M.eq_reference = function(opts)
    -- TOOD select only equation labels
    local ref_list = references.eq_defs(vim.fn.bufnr())

    ref_picker(ref_list, references.insert_ref, "eqref", opts)
end

-- List all references, and throw in a \ref{}
--   TODO navigate to definition
M.citation = function(opts)
    -- TODO I'll need to be smarter about what buffer to use
    -- e.g. if there are multiple files for one document
    local ref_list = references.get_citations(vim.fn.bufnr())

    ref_picker(ref_list, references.insert_ref, "cite", opts)
end

return M
