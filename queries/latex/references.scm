; Queries used to find metadata in latex documents

; Matching section and float labels {{{
(label_definition
    name: (curly_group_text (text) @label)
)

((generic_environment
    begin: (begin name: (curly_group_text (text) @float-name))
    (label_definition name: (curly_group_text (text) @label))
 ) @float
 (#any-of? @float-name "figure" "figure*" "table")
)

; }}}

; Matching equations {{{
(math_environment
    (label_definition
        name: (curly_group_text (text) @label)
    )
)

; This will match each label, but the related captures will match multiple
; times for each generic_environment
((math_environment
    (label_definition name: (curly_group_text (text) @eq-label))?
 )
)


;; The following matches are for finding other files
((bibtex_include
    path: (curly_group_path (path) @bibliography.path)
 ) @bibliography
)
