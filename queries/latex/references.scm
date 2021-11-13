; Queries used to find metadata in latex documents

; Matches the name in \label{}
((label_definition
    name: (word) @label))
; Matches the cross-reference name in \ref{}
((label_reference
    label: (word) @ref))

; Matching equations {{{
((equation_label_reference
    label: (word) @eqref
 ))

; This will match each label, but the related captures will match multiple
; times for each environment
((environment
    begin: (begin name: (word) @eq-env-name)
    (label_definition name: (word) @eq-label)?
 )
 (#any-of? @eq-env-name "align" "align*" "equation" "equation*")
)


;; The following matches are for finding other files
((bibtex_include
    path: ((path) @bibliography.path)
 ) @bibliography
)
