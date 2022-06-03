; A set of queries for outlining a latex document

; Input files (for multi-file documents)
;((latex_include ((path) @input.path) ) @input)

; generic_environmentS
(generic_environment
    begin: (begin name: (curly_group_text (text) @document.type))
 @document
 (#match? @document.type "document")
)

(generic_environment
    begin: (begin name: (curly_group_text (text) @abstract.type))
 @abstract
 (#match? @abstract.type "document")
)

((generic_environment
    begin: (begin name: (curly_group_text (text) @figure.type))
    ) @figure
 (#match? @figure.type "figure"))

((generic_environment
    begin: (begin name: (curly_group_text (text) @table.type))
    ) @table
 (#match? @table.type "table"))

; SECTIONS
((chapter
    text: ((curly_group) @chapter.title)
 ) @chapter
)

((section
    text: ((curly_group) @section.title)
 ) @section
)

((subsection
    text: ((curly_group) @subsection.title)
 ) @subsection
)

((subsubsection
    text: ((curly_group) @subsubsection.title)
 ) @subsubsection
)

((paragraph
    text: ((curly_group) @paragraph.title)
 ) @paragraph
)

((subparagraph
    text: ((curly_group) @subparagraph.title)
 ) @subparagraph
)

; METADATA
((caption
   short: ((brack_group) @caption.short)?
   long:  ((curly_group) @caption.long)
 ) @caption
)

((label_definition
    name: (curly_group_text (text) @label.name)
 ) @label
)

((graphics_include
    path: (curly_group_path (path) @graphics.path)
 ) @graphics
)

