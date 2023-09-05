# nvim-latex

**No longer maintained** This project has been abandoned, because the `texlab`
language server performs its main function. Also, because it was difficult to
maintain with changes upstream (telescope, and the latex treesitter grammar),
and I am not writing much latex anymore. 

This is a Neovim plugin to manage citations and crossreferences in Latex documents. 
It was also going to provide an outline of the whole document, which can be
useful for larger projects with multiple files.

# Usage

In order to use full functionality, the setup function has to be run first. 
This can be placed in `ftplugin/tex.vim`:

```viml
:lua require("nvim-latex").setup_document()
```

The function `setup_document(bufnr)` tracks all the `.tex` and `.bib` files in
the current document. If a substantial change is made (adding an `\input{}` or
`\bibliography{}`, then the function needs to be called  again to see the
changes in citations or the outline.

Insert a cross-reference:

```viml
" keepinsert will keep the cursor in insert mode, ready to continue typing
:inoremap <c-r> <CMD>lua require("nvim-latex.telescope").cross_reference { keepinsert = true }<CR>
" for normal mode,
:nnoremap <leader>r <CMD>lua require("nvim-latex.telescope").cross_reference()<CR>
```

Insert a citation

```viml
:inoremap <c-r> <CMD>lua require("nvim-latex.telescope").citation { keepinsert = true }<CR>
:nnoremap <leader>r <CMD>lua require("nvim-latex.telescope").citation()<CR>
```

## TODO / features

- [/] Cross-references
    - [ ] Find cross-references in whole document.
        - [X] Find and list all `\label{}`s in a file.
        - [X] pull labels, references, and citations from all files
    - [X] insert a reference from a menu 
        - [X] specific to sections and floats for `\ref`
        - [X] equation references with `\eqref`
- [/] Citations
    - [X] Full document support
        - [X] Pull citation keys from the `\bibliography` command (bibtex)
        - [X] find `\bibliography` for all files
    - [/] insert a citation from a menu
        - [X] insert selected citations with `\cite{}`
    - [X] integrate with zotero
- [X] Multi-file documents
    - [ ] Update on document changes
        - [/] Flag if something has changed with autocommand
            - [X] Add flag to the module
            - [ ] create autocommand
        - [X] Re-scan from functions (bibliography or outline) if the flag  is set
    - [X] reliably determine which file is the root document
          (checks for `\documentclass`, then looks for `.latexmkrc`)
    - [X] track all related buffers, ideally in all buffers
- [/] Outlining
    - [X] Find all chapters, sections, subsections, etc
    - [X] Find all figures with captions and labels
    - [/] Create a scratch buffer (`nvim_create_buf(false, true)`) that presents an outline of the document
        - [X] name the buffer "outline"

## Dependencies

We use `nvim-treesitter/nvim-treesitter` to parse the latex, and
`nvim-telescope/telescope.nvim` for the searchable menu. To install the parser,
execute `:TSInstall latex`.
