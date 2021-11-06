; Queries used to find metadata in latex documents

; Matches the name in \label{}
((label_definition
    name: (word) @latex.label))
; Matches the cross-reference name in \ref{}
((label_reference
    label: (word) @latex.ref))

;; The following matches are for finding other files
((bibtex_include
    path: ((path) @bibliography.path)
 ) @bibliography
)
