; A set of queries for outlining a latex document

; ENVIRONMENTS
((environment
    begin: (begin
        name: (word) @document.type)
 ) @document
 (#match? @document.type "document")
)

((environment
    begin: (begin
        name: (word) @abstract.type)
    child: (_) @abstract.contents) @abstract
 (#match? @abstract.type "abstract"))

((environment
    begin: (begin name: (word) @figure.type)
    ) @figure
 (#match? @figure.type "figure"))

((environment
    begin: (begin name: (word) @table.type)
    ) @table
 (#match? @table.type "table"))

; SECTIONS
((chapter
    text: ((brace_group) @chapter.title)
 ) @chapter
)

((section
    text: ((brace_group) @section.title)
 ) @section
)

((subsection
    text: ((brace_group) @subsection.title)
 ) @subsection
)

((subsubsection
    text: ((brace_group) @subsubsection.title)
 ) @subsubsection
)

((paragraph
    text: ((brace_group) @paragraph.title)
 ) @paragraph
)

((subparagraph
    text: ((brace_group) @subparagraph.title)
 ) @subparagraph
)

; METADATA
((caption
   short: ((bracket_group) @caption.short)?
   long:  ((brace_group) @caption.long)
 ) @caption
)

((label_definition
    name: ((word) @label.name)
 ) @label
)

((graphics_include
    path: ((path) @graphics.path)
 ) @graphics
)

