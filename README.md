# nvim-latex
**In early development**
Neovim plugin to manage citations and crossreferences in Latex documents. Also
provide an outline of the whole document.

# Usage

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
        - [ ] pull labels, references, and citations from all files
    - [X] insert a reference from a menu 
        - [X] specific to sections and floats for `\ref`
        - [X] equation references with `\eqref`
        - [ ] sort by relevance
            - [ ] prefer current file
            - [ ] prefer reftype by context before (chapter, appendix, section, figure, table)
    - [ ] check for `\ref{}` with missing `\label{}`
    - [ ] navigate to label definition, or reference
- [/] Citations
    - [ ] Full document support
        - [X] Pull citation keys from the `\bibliography` command (bibtex)
        - [ ] find `\bibliography` for all files
    - [ ] Pull citation keys from `\bibitem`s in the document
    - [/] insert a citation from a menu
        - [X] insert selected citations with `\cite{}`
        - [ ] insert just the citation label (without the surrounding cite)
        - [ ] \citep, \citet options with natbib
    - [ ] list all missing citation keys
    - [ ] integrate with zotero
    - [ ] show preview of reference from bibtex
- [X] Multi-file documents
    - [X] reliably determine which file is the root document
          (checks for `\documentclass`, then looks for `.latexmkrc`)
    - [X] track all related buffers, ideally in all buffers
- [/] Outlining
    - [X] Find all chapters, sections, subsections, etc
    - [X] Find all figures with captions and labels
    - [ ] Create a scratch buffer (`nvim_create_buf(false, true)`) that presents an outline of the document
        - [ ] name the buffer "outline"
        - [ ] highlighting
        - [ ] custom formatting 
            - [ ] labels
            - [ ] indent label
            - [ ] content preview
            - [ ] ...
        - [ ] highlight current position in document
        - [ ] Folding for those longer outlines
    - [ ] Add the ability to jump from the outline to that part of the document.
    - [ ] Multifile support
        - [ ] just the current file
        - [ ] whole document outline
    - [ ] Toggle showing outline with command
- [ ] Fixing errors and warnings
    - [ ] Navigate to next error/warning
        - Probably with LSP or aux file (will have to filter just the errors and warnings)
    - [ ] find unlabelled sections, figures, equations
    - [ ] suggest labels for sections, figures, equations
    - [ ] suggest matches for undefined references (like a spell check)
    - [ ] find duplicated labels

## Dependencies

We use `nvim-treesitter/nvim-treesitter` to parse the latex, and
`nvim-telescope/telescope.nvim` for the searchable menu. To install the parser,
execute `:TSInstall latex`.
