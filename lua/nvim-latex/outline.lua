-- Create an outline of a latex document

local ts_query = require("nvim-treesitter.query")
local utils = require("nvim-latex")

local M = {}

-- This module is just for latex
local lang = "latex"
local qgroup = "outline"

-- The DOM for the latex document
M._doc_tree = { capture = "root", children = {}, }

--- Check if range b is a subset of range a
local function range_in_range(b, a)
    -- starting point
    start = a[1] < b[1] or (a[1] == b[1] and a[2] <= b[2])
    -- ending point
    last = a[3] > b[3] or (a[3] == b[3] and a[4] >= b[4])
    return start and last
end

--- Check if the docNode b should be a child of docNode a
local function is_child(a, b)
    -- Checks if b is the child of a
    if b then 
        return range_in_range({b.node:range()}, {a.node:range()})
    else
        return nil
    end
end

--- Convert a query match to a DOM like node
--  
--  This function is set up so that it can be called with an iterator:
--      match_iterator = query:iter_matches(root, bufnr)
--      docNode = match_to_docNode(query, match_iterator())
local function match_to_docNode(query, pid, match, metadata)
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

    docNode = { children = {}, }
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

--- Makes a document subtree out of the rootNode from matches provided by match_iter
--
--  Returns the full subtree, and the next docNode, so that we can use it like
--  an iterator.
local function make_subtree(query, rootNode, match_iter)
    nextNode = match_to_docNode(query, match_iter())
    while (is_child(rootNode, nextNode)) do
        subtree, nextNode = make_subtree(query, nextNode, match_iter)
        table.insert(rootNode.children, subtree)
    end
    return rootNode, nextNode
end

--- The main function to create the document tree.
--
--  This will have to be called whenever the buffer is changed
--  TODO: can we cache this reasonably?
--  TODO: maybe do some async processing so that it won't hang
M.create_doc_tree = function(bufnr)
    bufnr = bufnr or vim.fn.bufnr()
    local root = vim.treesitter.get_parser(bufnr, lang):trees()[1]:root()
    local query = vim.treesitter.get_query(lang, qgroup)

    M._doc_tree = { capture = "root", children = {} }
    match_iter = query:iter_matches(root, bufnr)
    nextNode = match_to_docNode(query, match_iter())
    while (nextNode) do
        subtree, nextNode = make_subtree(query, nextNode, match_iter)
        table.insert(M._doc_tree.children, subtree)
    end

    return M._doc_tree
end

--- Create a formatted string of the docNode
M.pretty_print = function(docNode, depth)
    depth = depth or 0

    local prettified = {}
    -- Format the current docNode
    local formatter = M.formatter[docNode.capture]
    if formatter then
        table.insert(prettified, formatter(docNode, depth))
    end
    -- Format the children at a deeper level
    for _, child in ipairs(docNode.children) do
        table.insert(prettified, M.pretty_print(child, depth + 2))
    end

    return table.concat(prettified, "\n")
end

local function title_text(docNode)
    local title = utils.get_text_in_node(docNode.title.node)
    return(string.sub(title, 2, -2))
end

M.formatter = {
    document = function(docNode, depth)
        return string.rep(" ", depth) .. "DOCUMENT START"
    end,
    section = function(docNode, depth)
        return string.rep(" ", depth) .. title_text(docNode)
    end,
    subsection = function(docNode, depth)
        return string.rep(" ", depth) .. title_text(docNode)
    end,
    subsubsection = function(docNode, depth)
        return string.rep(" ", depth) .. title_text(docNode)
    end,
    paragraph = function(docNode, depth)
        return string.rep(" ", depth) .. title_text(docNode)
    end,
    subparagraph = function(docNode, depth)
        return string.rep(" ", depth) .. title_text(docNode)
    end,
}

return M

-- Design decisions,
-- ----------------
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
