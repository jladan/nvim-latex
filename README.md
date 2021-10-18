# nvim-latex
**In early development**
Neovim plugin to manage citations and crossreferences in Latex documents

# Usage

Insert a cross-reference:

```viml
" keepinsert will keep the cursor in insert mode, ready to continue typing
:inoremap <c-r> <CMD>lua require("nvim-latex.telescope").cross_reference { keepinsert = true }<CR>
" for normal mode,
:nnoremap <leader>r <CMD>lua require("nvim-latex.telescope").cross_reference()<CR>
```

## TODO

- [ ] Cross-references
    - [X] Find and list all `\label{}`s in a document.
    - [X] insert a reference from a menu 
    - [ ] check for `\ref{}` with missing `\label{}`
    - [ ] navigate to label definition, or reference
- [ ] Citations
    - [ ] Pull citation keys from the `\bibliography` command (bibtex)
    - [ ] Pull citation keys from `\bibitem`s in the document
    - [ ] insert a citation from a menu
    - [ ] list all missing citation keys
- [ ] Multi-file documents
    - [ ] reliably determine which file is the root document
    - [ ] track all buffers, ideally in the same tree
    - [ ] pull labels, references, and citations from all files

## Dependencies

We use `nvim-treesitter/nvim-treesitter` to parse the latex, and
`nvim-telescope/telescope.nvim` for the searchable menu. To install the parser,
execute `:TSInstall latex`.
