// chp => chapter
// fig => figure
// spc => spacing
// mjr => major

#let prof_indent = state("ut_prof_indent", 1cm)

// Spacing before the first entry of the chapter in the outline
#let otln_new_chp_spc = state("ut_otln_new_chp_spc", 1em)

// Spacing between the chapter number and the chapter title in the outline
#let otln_chp_primary_spc = state("ut_otln_chp_primary_spc", 6em)

// Additional indentation of sub-headings for each level in the outline
#let otln_chp_secondary_spc = state("ut_otln_chp_secondary_spc", 3em)

// Spacing between the major entries in the table of contents
#let toc_mjr_spc = state("ut_toc_mjr_spc", 2em)

// Leading of the outline (table of contents, list of figures, etc.)
#let otln_leading_spc = state("ut_otln_leading_spc", 1em)

// Columns for the list of abbreviations. The first column is for the abbreviation and the second column is for the full form.
#let abbrv_columns = state("ut_abbrv_columns", (0.25fr, 1fr))

#let CommitteeProf(person, indent: true) = context {
  if indent {
    h(prof_indent.get())
  }
  
  if person.title != none {
    person.title + [ ]
  }
  person.name
  if person.chair {
    [, Chair]
  }
  linebreak()
} 


#let PreambleChapter(title, label_name: none) = context {
  show heading: set align(center)
  heading(numbering: none, supplement: none)[
    #{
      text(weight: "regular", upper(title)) + v(1em)
    }
  ]
}

#let ThesisBibliography(..files, full: false, style: "association-for-computing-machinery", title: "Bibliography") = {
  par(
    leading: 0.5em,
    spacing: 1em
  )[
    #show heading.where(level: 1): it => context {
      pagebreak()
      text(1.8em, style: "normal", weight: "bold")[
        #par(leading: 1em, justify: false)[
          #it.body
        ]
      ]
    }
    #bibliography(
      files.pos(),
      full: full,
      style: style, 
      title: title
    )
  ]
}

#let ucsd_thesis(
  
  // Subject of the thesis
  subject: "Computer Science",

  // Author of the thesis
  author: "John/Jane Doe",

  // Title of the thesis
  title: "My Little Thesis",

  // Degree of the thesis
  degree: "Doctor of Philosophy",

  // Committee members as dict in the order of appearance
  // If a member is the chair, set chair to true
  // Fields: title, name, chair
  committee: (
    (title: "Professor", name: "Jane Doe", chair: true),
    (title: "Professor", name: "John Doe", chair: false)
  ),
  
  // Abstract of the thesis. Omitted if none
  abstract: none,

  // Dedication of the thesis. Omitted if none
  dedication: none,

  // Acknowledgement of the thesis. Omitted if none
  acknowledgement: none,
  
  // Epigraph of the thesis. Omitted if none
  epigraph: none,

  // List of abbreviations. Omitted if none
  // The list will be sorted by the abbreviation.
  // 
  // Example:
  // (
  //   "UCSD": "University of California San Diego",
  //   "PhD": "Doctor of Philosophy"
  // )
  abbrv: none,

  // Vita of the author. Omitted if none
  vita: none,

  // Publications of the author. Omitted if none
  publications: none,

  // Introduction of the thesis. Omitted if none
  introduction: none,

  // Enable field of study section
  enable_field_of_study: false,

  // Research Topic for Field of Study
  research_topic: none,

  // Enables List of Table page
  enable_list_of_tables: true,

  // Enables List of Table page
  enable_list_of_figures: true,
  
  doc,
) = {
  set page(
    paper: "us-letter",
    number-align: center,
    numbering: none,
    margin: (top: 1.5in, left: 1in, right: 1in)
  )

  set par(
    justify: true
  )

  show table.cell: it => text(weight: "regular")[#it]
  show table.cell: it => par(leading: 0.5em)[#it]

  show figure: it => block(width: 100%)[#align(center)[
     // Captions for Tables should be above the table (Manual, Pg 32)
     #let body_before_caption = it.kind != table
     
     #let caption = none
     #let body = par(leading: 1em)[
       #it.body
     ]

     #set par(leading: 1em)

     #if it.has("caption") {
         if it.caption != none and it.caption.has("body") {
           caption = {
             text(weight: "bold", {
                 it.supplement
                 " "
                 str(counter(heading).get().first())
                 "."
                 str(counter(figure.where(kind: it.kind)).get().first())
               }
             )
             ": "
             it.caption.body
           }
         }
       }

     #if body_before_caption {
       body
       caption
     } else {
       caption
       body
     }
   ]
  ]

  show ref: it => {
    let auto_supplement = (
      "table": "Table",
      "image": "Figure",
    )

    let el = it.element   
    
    if el != none and el.has("kind") and el.kind in (table, image) {
      // Override references.
      let kind_str = [#el.kind].text
      let text = auto_supplement.at(kind_str) + [ ] +[#counter(heading).at(el.location()).first()\.#counter(figure.where(kind: el.kind)).at(el.location()).first()]
      link(it.target)[#text]
    } else {
      // Other references as usual.
      it
    }
  }
  
  set outline(fill: align(right, repeat(gap: 5pt)[.]))
  
  show outline.entry : it => context {
    if it.element.func() == heading { // Table of contents outline
      let element = it.element
      let body = it.body

      if element.numbering == none { // Preamble Chapters
        v(toc_mjr_spc.get())
        if body.has("text") { // Bibliography
          body.text
          box(width: 1fr, it.fill)
          " " + it.page
        } else {
          let name = body.children.at(1).children.at(0).child
          name + " "
          box(width: 1fr, it.fill)
          " " + it.page
        }
      } else if it.has("level") { // Normal Chapters
  
        if element.body.has("text") and element.body.text == "Acknowledgement" {
          // Skip it
        } else {
          
          let num = numbering("1.1.1", ..counter(heading).at(it.element.location()))
          let grid_data = ()
          let lvl = it.level

          let prim_spc = otln_chp_primary_spc.get()
          let sec_spc = otln_chp_secondary_spc.get()
          
          let columns = (
            "1": (prim_spc, 1fr),
            "2": (prim_spc, sec_spc, 1fr),
            "3": (prim_spc, sec_spc, sec_spc, 1fr),
            "4": (prim_spc, sec_spc, sec_spc, sec_spc, 1fr),        
            "5": (prim_spc, sec_spc, sec_spc, sec_spc, sec_spc, 1fr),
          )
    
          if lvl == 1 {
            if num == 1 {
              v(toc_mjr_spc.get() * 0.2)
            }
            v(toc_mjr_spc.get() * 0.8)
            grid_data.push("Chapter " + num)
          } else {
            for i in range(lvl - 1) {
              grid_data.push("")
            }
            
            grid_data.push(num)
          }        
          grid_data.push(element.body + box(width: 1fr, it.fill) + " " + it.page)
    
          grid(
            columns: columns.at(str(lvl)),
            ..for data in grid_data {
              (data,)
            }
          )
        }
      }
    } else { // Other outlines
      let kind = it.element.kind
      let heading_num = counter(heading).at(it.element.location()).first()
      let figure_num = counter(figure.where(kind: kind)).at(it.element.location()).first()
      
      let elem_num = numbering("1.1", heading_num, figure_num)
      let elem_typ = it.element.caption.supplement.text
      let caption = it.element.caption.body
      let dots = box(width: 1fr, align(right, repeat(gap: 5pt)[.]))
  
      let columns = (otln_chp_primary_spc.get(), 1fr, 2em)

      if figure_num == 1 {
        v(otln_new_chp_spc.get())
      }
      
      grid(
        columns: columns,
        elem_typ + " " + elem_num + ":",
        par(leading: 0.5em, spacing: 0.4em)[#context {
          caption + " " + dots + " "
        }],
        align(bottom+right, it.page)
      )
    }
  }

  
  align(center)[
    #v(1fr)
    UNIVERSITY OF CALIFORNIA SAN DIEGO
    #v(1fr)
    *#title*
    #v(1fr) A Dissertation submitted in partial satisfaction of the requirements \
    for the degree #degree 
    #v(1fr)  
    in
    #v(1fr)
    #subject
    #v(1fr)
    by
    #v(1fr)
    #author
    #v(1fr)
  ]

    
  [Committee in charge:] + linebreak()


  for person in committee {
    CommitteeProf(person)
  }

  
  v(1fr)
  let today = datetime.today()
  
  align(center)[
    #today.display("[year]") 
  ]
  v(1fr)
  
  pagebreak()
  v(1fr)
  align(center)[
    #emoji.copyright #author, #today.display("[year]")
    
    All rights reserved.
  ]
  
  pagebreak()
  set page(numbering: "i")

  {
    show heading: none
    PreambleChapter("Dissertation Approval")
  }
  
  align(center)[
    The Dissertation of #author is approved, and it is acceptable \
    in quality and form for publication on microfilm and electronically.
    
    #v(1fr)
    
    University of California San Diego
    
    #today.display("[year]")
    
    #v(1fr)
  ]
  
  set par(
    leading: 2em,  
    spacing: 2em,
    first-line-indent: 0.5in,
    justify: true
  ) 
  show list: set block(spacing: 2em)
    
  pagebreak()
  
  
  if dedication != none {
    PreambleChapter("Dedication")
    dedication
    pagebreak()
  }

  if epigraph != none {
    PreambleChapter("Epigraph")
    epigraph
    pagebreak()
  }
  
  context {
    PreambleChapter("Table of Contents")
    par(leading: otln_leading_spc.get(), spacing: 0em)[
      #outline(title: none)
    ]
  }
  pagebreak()

  context {
    if enable_list_of_figures {
      PreambleChapter("List of Figures")
      par(leading: otln_leading_spc.get(), spacing: 0em)[
        #outline(
          title: none,
          target: figure.where(kind: image),
        )
      ]
    }
  }
  pagebreak()

  context {
    if enable_list_of_tables {
      PreambleChapter("List of Tables")
      par(leading: otln_leading_spc.get(), spacing: 0em)[
        #outline(
          title: none,
          target: figure.where(kind: table),
        )
      ]
    }
  }
  
  pagebreak()

  if abbrv != none {
    PreambleChapter("LIST OF ABBREVIATIONS")
    
    let abbrv_sorted = abbrv.pairs().sorted(key: k => k.at(0))
    
    set par(justify: true)

    context {
      table(
        stroke: none,
        columns: abbrv_columns.get(),
        ..for (k, v) in abbrv_sorted {
          (k, v)
        }
      )
    }
    
    pagebreak()
  }

  if acknowledgement != none {
    PreambleChapter("ACKNOWLEDGEMENTS")
    acknowledgement
    pagebreak()
  }

  if vita != none {
    PreambleChapter("Vita")
    vita
  }

  if publications != none {
    PreambleChapter("Publications")
    publications
  }

  if enable_field_of_study {
    PreambleChapter("Field of Study")
    
    par(
        leading: 0.5em,  
        spacing: 0.5em,
        first-line-indent: 0em,
      )[
        Major Field: #subject
  
        #context [
          #h(prof_indent.get()) Studies in #research_topic
        ]
  
        #for person in committee {
          if person.chair {
            CommitteeProf(person)
          }
        }
    ]
  }

  pagebreak()
  
  if abstract != none {
    
    v(2.5in)
    PreambleChapter("Abstract of Dissertation")
    
    align(center)[
      #title
      #v(1em)  
      by
      #v(1em)  
      #author
      #v(1em)
      #degree in #subject
      
      University of California San Diego, #today.display("[year]")
  
      #for person in committee {
        if person.chair {
          CommitteeProf(person, indent: false)
        }
      }
      
      #v(1em)
    ]
    abstract
    
  }
  
  set page(numbering: "1")
  counter(page).update(1)

  if introduction != none {
    PreambleChapter("Introduction")
    introduction
  }
  
  set heading(
      numbering: (..) => counter(heading).display("1.1"),
      supplement: ""
  )

  show heading.where(level: 1): set heading(
    supplement: [Chapter],
  )

  show heading: it => context {
    set text(style: "normal", weight: "regular")
    
    if it.level == 1 {
      set text(1.6em, weight: "bold")
      set par(leading: 2em, justify: false)
      
      counter(figure.where(kind: image)).update(0)
      counter(figure.where(kind: table)).update(0)
      pagebreak()
      {
        "Chapter "
        counter(heading).display("1.1.1")
        linebreak()
      }
      it.body
    } else {
        set text(1em + 0.8em/it.level, weight: "bold")
        it
        v(-2em)
        linebreak()
        parbreak()
    }
  }

  doc
}

