#import "template.typ": ucsd_thesis, ThesisBibliography

// Preamble chapters as variables make organization simpler
#import "Chapters/abstract.typ": abstract
#import "Chapters/abbrv.typ": abbrv
#import "Chapters/acknowledgement.typ": acknowledgement
#import "Chapters/epigraph.typ": epigraph
#import "Chapters/intro.typ": intro
#import "Chapters/pubs.typ": pubs

#show: ucsd_thesis.with(
  subject: "Computer Science",
  
  author: "Suyash Mahar",
  
  title: "Usable Interfaces for Emerging Memory Technologies",
  
  degree: "Doctor of Philosophy",
  
  committee: (
    (title: "Professor", name: "Steven Swanson", chair: true),
    (title: "Professor", name: "Amy Ousterhout", chair: false),
    (title: "Professor", name: "Paul Siegel", chair: false),
    (title: "Professor", name: "Jishen Zhao", chair: false),
  ),
  
  abstract: abstract,
  
  dedication: align(center, [To anyone reading this.]),
  
  epigraph: epigraph,

  abbrv: abbrv,

  acknowledgement: acknowledgement,

  vita: par(spacing: 0em, leading: 0.5em)[
    #table(
      stroke: none,
      columns: (0.25fr, 1fr),
      [2020],[Bachelor of Technology, Electronics and Communication Engineering, Indian Institute of Technology Roorkee],
      [2025],[Doctor of Philosophy, Computer Science, University of California San Diego],
    )
  ],

  publications: pubs,

  introduction: intro,

  enable_field_of_study: true,

  research_topic: "Computer Science and Engineering (Computer Systems)"
)


= Emerging Memory Technologies <background>

#include "Chapters/background.typ"

= Snapshot: High-performance `msync()`-based crash consistency. <chapter:snapshot>

#include "Chapters/snapshot.typ"


= Puddles: Application-Independent Recovery and Location-Independent Data for Persistent Memory <chapter:puddles>

#include "Chapters/puddles.typ"

= RPCool: Fast Shared Memory RPC For Containers and CXL <chapter:rpcool>

#include "Chapters/rpcool.typ"

= Conclusion
<chapter:conclude>

#include "Chapters/conclusion.typ"

#ThesisBibliography("references.bib", "nvsl.bib", "puddles.bib")