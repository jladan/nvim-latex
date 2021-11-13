; Queries used to find metadata in latex documents

; Matching section and float labels {{{
((_
    ;; All section macros have a bracegroup, but environments don't
    text: ((brace_group))
    (label_definition name: (word) @label)
 ) 
)

((environment
    begin: (begin name: (word) @float-name)
    (label_definition name: (word) @label)
 ) @float
 (#any-of? @float-name "figure" "table")
)

; }}}

; Matching equations {{{
((equation_label_reference
    label: (word) @eqref
 ))

; This will match each label, but the related captures will match multiple
; times for each environment
((environment
    begin: (begin name: (word) @eq-name)
    (label_definition name: (word) @eq-label)?
 )
 (#any-of? @eq-name "align" "align*" "equation" "equation*")
)


;; The following matches are for finding other files
((bibtex_include
    path: ((path) @bibliography.path)
 ) @bibliography
)
