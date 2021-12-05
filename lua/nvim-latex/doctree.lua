-- DOM for latex to be used by outlining functions

local utils = require("nvim-latex.utils")

lang = 'latex'
qgroup = 'outline'

-- Meta class
local DocNode = {}
DocNode.__index = DocNode

-- @class DocNode
-- DocNode is node in a latex document to track document elements. It is a
-- fairly thin wrapper around a treesitter.node, but keeps track of the
-- children, and some related metadata.
function DocNode:new(capture, node)
    return setmetatable({
        capture = capture or "",
        node = node,
        children = {}
    }, self)
end

function DocNode:addChild(dnode)
    table.insert(self.children, dnode)
end

function DocNode:range()
    return self.node:range()
end

function DocNode:covers(srow, scol, erow, ecol)
    local dsrow, dscol, derow, decol = self:range()
    local start, last
    -- self starts before the starting position
    start = dsrow < srow or (dsrow == srow and dscol <= scol)
    if erow and ecol then
        -- self ends after the ending position
        last = derow > erow or (derow == erow and decol >= ecol)
    else
        -- self ends after the starting position
        last = derow > srow or (derow == srow and decol >= scol)
    end
    return start and last
end

--- Check if the docNode b should be a child of docNode a
function DocNode:is_in(dnode)
    --- Check if range b is a subset of range a
    local asrow, ascol, aerow, aecol = dnode:range()
    local bsrow, bscol, berow, becol = self:range()
    -- dnode starts before self
    local start = asrow < bsrow or (asrow == bsrow and ascol <= bscol)
    -- dnode ends after self
    local last = aerow > berow or (aerow == berow and aecol >= becol)
    return start and last
end

--- Convert a query match to a DOM like node {{{
--
--  This function is set up so that it can be called with an iterator:
--      match_iterator = query:iter_matches(root, bufnr)
--      docNode = match_to_docNode(query, match_iterator())
--
--  Each match corresponds to one query defined in the .scm, with one entry per
--  capture. So
--     ((caption 
--          short: ((bracket_group) @caption.short)? 
--          long:  ((brace_group) @caption.long)
--      ) @caption )
--  Will match as:
--      { caption.short = <node>, 
--        caption.long = <node>,
--        caption = <node>, }
--  The captures with dots are added as extra parameters on the DocNode

function DocNode:from_match(query, pid, match, metadata)
    -- If pid is nil, then there was nothing new from the match_iterator
    if pid == nil then
        return nil
    end
    -- split a capture name on '.'s
    local function split(string)
        local t = {}
        for str in string.gmatch(string, "([^.]+)") do
            table.insert(t, str)
        end
        return t
    end

    docNode = DocNode:new()
    for id, node in pairs(match) do
        name = query.captures[id]
        splitName = split(name)
        local curr = docNode
        if #splitName == 1 then
            -- Use the primary name for the docNode
            docNode.capture = name
        else
            -- Descend down '.'s adding objects as necessary
            for i = 2, #splitName do
                if curr[splitName[i]] == nil then
                    curr[splitName[i]] = {}
                end
                curr = curr[splitName[i]]
            end
        end
        -- curr is now the object that the capture's node and metadata applies to
        curr.node = node
        curr.metadata = metadata[id]
    end

    return docNode
end

-- }}}

-- Creating the doctree of a file {{{

--- The main function to create the document tree.
--
--  This will have to be called whenever the buffer is changed
--  TODO: can we cache this reasonably?
--  TODO: maybe do some async processing so that it won't hang
function DocNode:from_buffer(bufnr)
    bufnr = bufnr or vim.fn.bufnr()
    local root = vim.treesitter.get_parser(bufnr, lang):trees()[1]:root()
    local query = vim.treesitter.get_query(lang, qgroup)

    rootnode = DocNode:new("root", root)
    match_iter = query:iter_matches(root, bufnr)
    nextNode = DocNode:from_match(query, match_iter())
    while (nextNode) do
        subtree, nextNode = DocNode._make_subtree(query, nextNode, match_iter)
        rootnode:addChild(subtree)
    end

    return rootnode
end

--- Makes a document subtree out of the rootNode from matches provided by match_iter
--
--  Returns the full subtree, and the next docNode, so that we can use it like
--  an iterator.
function DocNode._make_subtree(query, rootNode, match_iter)
    nextNode = DocNode:from_match(query, match_iter())
    while (nextNode and nextNode:is_in(rootNode)) do
        subtree, nextNode = DocNode._make_subtree(query, nextNode, match_iter)
        rootNode:addChild(subtree)
    end
    return rootNode, nextNode
end

-- }}}

-- Printing the doctree {{{

--- Create a formatted string of the docNode
function DocNode:prettify(depth)
    -- Depth is how many spaces to prepend
    depth = depth or 0

    local prettified = {}
    -- Format the current docNode
    local formatter = DocNode.formatter[self.capture]
    if formatter then
        table.insert(prettified, formatter(self, depth))
    end
    -- Format the children at a deeper level
    for _, child in ipairs(self.children) do
        for _, v in ipairs(child:prettify(depth + 2)) do
            table.insert(prettified, v)
        end
    end

    return prettified
end


--  Formatting functions {{{

local function inner_text(node)
    local title = utils.get_text_in_node(node)
    return(string.sub(title, 2, -2))
end

local function prefix(depth)
    return string.rep(" ", depth)
end

local function section_formatter(docNode, depth)
    return prefix(depth) .. inner_text(docNode.title.node)
end


DocNode.formatter = {
    document = function(docNode, depth)
        return prefix(depth) .. "DOCUMENT START"
    end,
    section = section_formatter,
    subsection = section_formatter,
    subsubsection = section_formatter,
    paragraph = section_formatter,
    subparagraph = section_formatter,
    figure = function(docNode, depth)
        local fig_path = nil
        local fig_label = nil
        for _, child in ipairs(docNode.children) do
            if child.capture == "graphics" then
                fig_path = utils.get_text_in_node(child.path.node)
            elseif child.capture == "label" then
                fig_label = utils.get_text_in_node(child.name.node)
            end
        end
        return prefix(depth) .. "FIGURE " .. fig_label .. " :: " .. fig_path
    end,
    table = function(docNode, depth)
        local table_label = ""
        for _, child in ipairs(docNode.children) do
            if child.capture == "label" then
                table_label = utils.get_text_in_node(child.name.node)
            end
        end
        return prefix(depth) .. "TABLE " .. table_label
    end,
}

-- }}}
-- }}}

return DocNode

-- Design decisions {{{
-- --------------------
--
-- Problem with nvim-treesitter matches:
-- Only one capture of each type can be included in a group, because the key
-- for the match is the capture name. So, we can have
-- `caption.long` and `figure.caption.long`
-- but we cannot have two different sections in one document
-- assigning to `document.section`, overwrites the previous section
--
-- This method of access also makes iteration over children more complicated:
--   without knowing the key for the child, how do we know if it's actually a
--   child or just metadata associated with the capture?
-- That means that simply making `section.subsection` a list isn't sufficient:
--   `section.figure` would be a separate list, and the order between them is lost
--
-- Solution: a more conventional tree with nodes:
--     {capture = "document",
--      node = <ts_node>,
--      children = [<doc_node>,],
--      parent = <doc_node>    -- maybe
--     }
-- Because of this, I don't think it makes sense to use nvim-treesitter's iterators
-- They already create a nested structure that isn't really useful. There may be
-- some use in the way we get something like `caption.short` or `caption.long`,
-- and I'd turn that into,
--     {capture = "caption",
--      node = <ts_node>,
--      short = <ts_node>,
--      long = <ts_node>,
--      children = [],
--     }
-- But I can probably do that myself.
--
-- Each match from `query:iter_matches()` is a list of the captures on
-- the current pattern, so the `caption.short` and `caption.long` are given along
-- with the `caption` node.
-- }}}


