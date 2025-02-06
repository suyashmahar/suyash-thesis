#import "macros.typ" : *

#set page(
  paper: "us-letter",
  number-align: center,
  numbering: none,
)

#show table.cell: it => text(weight: "regular")[#it]

#show heading: it => [
  #set align(center)
  #set text(13pt, weight: "regular")
  #block(upper(it.body))
  #v(1em)
]

#show figure: it => block(width: 100%)[#align(center)[
   #par(leading: 1em)[
     #text(weight: "bold")[#it.body]
     #it.caption
   ]
 ]
]

#set outline(fill: align(right, repeat(gap: 5pt)[.]))

#show outline.entry : it => {
  if it.element.func() == heading { // Table of contents outline
    let element = it.element
    let body = it.body
    let indent = 5.3em

    if body.has("text") { // Preamble Chapters
      v(2em)
      body.text + " "
      box(width: 1fr, it.fill)
      " " + it.page
    } else if it.has("level") { // Normal Chapters

      if element.body.has("text") and element.body.text == "Acknowledgement" {
        // Skip it
      } else {
        let num = body.children.at(0).text.replace("Chapter ", "")
        let grid_data = ()
        let lvl = it.level
        
        let columns = (
          "1": (6em, 1fr),
          "2": (6em, 3em, 1fr),
          "3": (6em, 3em, 3em, 1fr),
          "4": (6em, 3em, 3em, 3em, 1fr),        
          "5": (6em, 3em, 3em, 3em, 3em, 1fr),
        )
  
        if lvl == 1 {
          v(2em)
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
    let elem_num = numbering(it.element.numbering, ..it.element.counter.at(it.element.location()))
    let elem_typ = it.element.caption.supplement.text
    let caption = it.element.caption.body
    let dots = box(width: 1fr, align(right, repeat(gap: 5pt)[.]))

    let columns = (
      "Table": (4em, 1fr),
      "Figure": (5em, 1fr),
    )
    
    grid(
      columns: columns.at(elem_typ),
      elem_typ + " " + elem_num + ":",
      par(leading: 0.5em, spacing: 0.4em)[#{
        caption + " " + dots + " " + it.page
      }]
    )

    if upper(elem_typ) == upper("Table") {
      v(-3em)
    }
  }
}


#let subject = "Computer Science"
#let name = "Suyash Mahar"
#let title = "Usable Interfaces for Emerging Memory Technologies"
#let degree = "Doctor of Philosophy"


#align(center)[
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
  #name
  #v(1fr)
]

Committee in charge:

#{
  CommitteeProf("Steven Swanson", title: "Chair") + ln()
  CommitteeProf("Amy Ousterhout") + ln()
  CommitteeProf("Paul Siegel") + ln()
  CommitteeProf("Jishen Zhao")
}

#v(1fr)
#let today = datetime.today()

#align(center)[
  #today.display("[year]") 
]
#v(1fr)

#pagebreak()
#v(1fr)
#align(center)[
  Copyright #emoji.copyright #name, #today.display("[year]")
  
  All rights reserved.
]

#pagebreak()
#set page(numbering: "i")

#align(center)[
  The Dissertation of #name is approved, and it is acceptable \
  in quality and form for publication on microfilm and electronically.
  
  #v(1fr)
  
  University of California San Diego
  
  #today.display("[year]")
  
  #v(1fr)
]

#pagebreak()

#set par(
  leading: 2em,  
  spacing: 2em,
  first-line-indent: 4em,
) 
#show list: set block(spacing: 2em)



#PreambleChapter("Dedication")

#align(center, "To anyone reading this.")




#pagebreak()

#PreambleChapter("Epigraph")
#v(1fr)
#align(horizon + right)[
  #text(size: 1em)[
    // Everything not saved will be lost. #h(4em)
    
    // ---Nintendo "Quit Screen" Message

    // Underfull `\hbox` (badness 10000) in paragraph at lines 165--169

    #par(leading: 0.5em)[
      ! Paragraph ended before `\HyPsd@@ProtectSpacesFi` was complete. \
      \<to be read again\>`\par` `\end{document}`
    ]

    ---pdfTex (Tex Live 2024)

    So, I switched to Typst.
  ]
]
#v(2fr)

#pagebreak()


#par(leading: 0.9em, spacing: 0em)[
  #outline(title: [TABLE OF CONTENTS])
]



#pagebreak()

#par(leading: 2em, spacing: 0em)[
  #outline(
    title: [LIST OF FIGURES],
    target: figure.where(kind: image),
  )
]

#pagebreak()

#outline(
  title: [LIST OF TABLES],
  target: figure.where(kind: table),
)

#pagebreak()

#PreambleChapter("LIST OF ABBREVIATIONS")

#let abbrv = (
  "CXL": "Compute Express Link",
  "PMEM": "Persistent Memory",
  "ASLR": "Address Space Layout Randomization",
  "PCIe": "Peripheral Component Interconnect Express",
  "TLB": "Translation Lookaside Buffer",
  "SSD": "Solid State Disk",
  "NVM": "Non-volatile Memory",
  "PMDK": "Persistent Memory Development Kit",
  "DRAM": "Dynamic Random Access Memory",
  "DDR": "Double Data Rate",
  "KV": "Key value",
  "WAL": "Write Ahead Log",
  "DAX": "Direct Access",
  "FAMS": "Failure atomic msync()",
  "NT": "Non Temporal",
  "YCSB": "Yahoo! Cloud Serving Benchmark",
  "RPC": "Remote procedure call",  
)

#let abbrv_sorted = abbrv.pairs().sorted(key: k => k.at(0))

#set par(justify: true)

#table(
  stroke: none,
  columns: (0.25fr, 1fr),
  ..for (k, v) in abbrv_sorted {
    (k, v)
  }
)

#pagebreak()

#PreambleChapter("ACKNOWLEDGEMENTS")

I have really enjoyed my PhD experience. 

This thesis would not have been possible without the contribution of several people. I am deeply thankful to my advisor, Steven Swanson for all his support, guidance and fun conversations during my PhD.


I would also like to thank Terence Kelly who helped with several technical discussions, feedback on my writing, and advice on how to handle different aspects of my PhD life. Special thanks to Professor Joseph Izraelevitz, who helped me shape my research project when I was just starting out my PhD. I would also like to thank my collaborators from several industry internships that helped me get a better understanding of commercial implications of my research. Thanks to Abhishek Dhanotia 
and Hao Wang for providing insights into needs and operations of hyperscalars. Thanks to Professor Samira Khan and Professor Baris Kasikci for their guidance during my internship at Google.

I am also deeply indebdted to people who helped me get into research during my undergraduate which led me to where I am today. Professor Saugata Ghose and Dr. Rachata Ausavarungnirun who have helped not only spark my interest in Computer Archicture but have helped me over the years. Thanks to Professor Ran Ginosar and Professor Leonid Yavits who helped me get started in the field of Persistent Memories an a wonderful summer in Haifa.

I am grateful to all the fun times I had at UCSD. Ziheng for being a great friend and roommate. Mingyao for all his restaurant recommendations! Nara for all the support. Zixuan for helping me figure out various processes at UCSD and life. Yanbo for being the perfect travel companion! Seungjin, Ehsan, Zifeng, YJ, and Theo for all the fun memories.


A special thanks to Professor Samira Khan for providing me opportunities during my undergrad to make significant contributions to research projects, helping me with my PhD applications, and providing support and guidance over the years. I would also like to thanks everyone at SHIFTLAB who helped me when I was getting started with my research, especially, Korakit Seemakhupt and Yasas Seneviratne.


Finally, I would like to thank my parents without who provided me support and encouragement during my PhD. My girlfriend, Caleigh who has always been supportive and encouraging.


@chapter:snapshot contains material from "Snapshot: Fast, Userspace Crash Consistency for CXL and PM Using msync," by Suyash Mahar, Mingyao Shen, Terence Kelly, and Steven Swanson, which appears in the Proceedings of the 41st IEEE International Conference on Computer Design (ICCD 2023). The dissertation author is the primary investigator and first author of this
paper.

@chapter:puddles contains material from "Puddles: Application-Independent Recovery and Location-Independent Data for Persistent Memory," by Suyash Mahar, Mingyao Shen, TJ Smith, Joseph Izraelevitz, and Steven Swanson, which appears in the Proceedings of the 19th European Conference on Computer Systems (EuroSys 2024). The dissertation author is the primary investigator and first author of this paper.

@chapter:rpcool contains material from "MemRPC: Fast Shared Memory RPC For Containers and CXL," by Suyash Mahar, Ehsan Hajyjasini, Seungjin Lee, Zifeng Zhang, Mingyao Shen, and Steven Swanson, which is under review. The dissertation author is the primary investigator and first author of this paper.

Thanks! #h(1fr) #today.display("[day] [month repr:short] [year]")

#pagebreak()

#PreambleChapter("VITA")

#par(spacing: 0em, leading: 0.5em)[
#table(
  stroke: none,
  columns: (0.25fr, 1fr),
  [2020],[Bachelor of Technology, Electronics and Communication Engineering, Indian Institute of Technology Roorkee],
  [2025],[#degree, Computer Science, University of California San Diego],
)
]

#PreambleChapter("PUBLICATIONS") 
#par(
    leading: 0.5em,
    spacing: 1.5em,
    first-line-indent: 0em,
  )[
  Suyash Mahar, B. Ray, S. Khan, _PMFuzz: Test Case Generation for Persistent Memory Programs_ (Proceedings of the 26th ACM International Conference on Architectural Support for Programming Languages and Operating Systems).
  
  L. Yavits, L. Orosa, Suyash Mahar, J. D. Ferreira, M. Erez, R. Ginosar, O. Mutlu, WoLFRaM: _Enhancing Wear-Leveling and Fault Tolerance in Resistive Memories Using Programmable Address Decoders_ (2020 IEEE 38th International Conference on Computer Design (ICCD), 187-196).
  
  D. Saxena, Suyash Mahar, V. Raychoudhury, J. Cao, Scalable, _High-Speed On-Chip-Based NDN Name Forwarding Using FPGA_ (Proceedings of the 20th International Conference on Distributed Computing and Networking).
  
  Suyash Mahar, M. Shen, T. Smith, J. Izraelevitz, S. Swanson, _Puddles: Application-Independent Recovery and Location-Independent Data for Persistent Memory_ (Proceedings of the Nineteenth European Conference on Computer Systems, 575-589).
  
  Suyash Mahar, H. Wang, W. Shu, A. Dhanotia, _Workload Behavior Driven Memory Subsystem Design for Hyperscale_ (arXiv preprint arXiv:2303.08396).
  
  Suyash Mahar, E. Hajyasini, S. Lee, Z. Zhang, M. Shen, S. Swanson, _Telepathic Datacenters: Fast RPCs Using Shared CXL Memory_ (in review).
  
  Suyash Mahar, M. Shen, T. Kelly, S. Swanson, _Snapshot: Fast, Userspace Crash Consistency for CXL and PM Using `msync()`_ (2023 IEEE 41st International Conference on Computer Design (ICCD), 495-498).
  
  Suyash Mahar, S. Liu, K. Seemakhupt, Y. Young, S. Khan, _Write Prediction for Persistent Memory Systems_ (2021 30th International Conference on Parallel Architectures and Compilation).
  
  Z. Wang, Suyash Mahar, L. Li, J. Park, J. Kim, T. Michailidis, Y. Pan, T. Rosing, _The Hitchhiker’s Guide to Programming and Optimizing CXL-Based Heterogeneous Systems_ (arXiv preprint arXiv:2411.02814).
]

#PreambleChapter("Field of Study")

#par(
    leading: 0.5em,  
    spacing: 0.5em,
    first-line-indent: 0em,
  )[
    Major Field: Computer Science

    #h(prof_indent) Studies in Research topic
    
    #CommitteeProf("Steven Swanson", title: "Chair")
]

#pagebreak()
#v(2.5in)

#PreambleChapter("Abstract of Dissertation")

#align(center)[
  #title
  #v(1em)  
  by
  #v(1em)  
  #name
  #v(1em)
  #degree in #subject
  
  University of California San Diego, #today.display("[year]")
  
  #CommitteeProf("Steven Swanson", title: "Chair")
  
  #v(1em)

  Intro to the thesis

  condense the abstract

  // #lorem(100)

  // #lorem(100)
]

#pagebreak()

#counter(page).update(1)
#set page(numbering: "1")

#include "Chapters/intro.typ"

#set heading(
    numbering: (..) => "Chapter " + counter(heading).display("1"),
    supplement: ""
)
#show heading: it => context {
  if it.level == 1 {
    pagebreak()
    text(1.8em, style: "normal", weight: "bold")[
      #par(leading: 0.5em, justify: false)[
        #{
          "Chapter "
          counter(heading).display("1.1.1")
        } #v(-1.8em)
        #linebreak()
        #it.body
      ]
    ]
  } else {
    if it.body.has("text") and it.body.text == "Acknowledgement" {    
      h(-4em) + text(1.5em, style: "normal", weight: "regular")[#it.body #linebreak()]      
    } else {
      h(-4em) + text(1.5em, style: "normal", weight: "regular")[#counter(heading).display("1.1.1") #it.body #linebreak()]
    }
  }
}

 \

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


#par(
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
    ("references.bib", "nvsl.bib", "puddles.bib"), full: false, style: "institute-of-electrical-and-electronics-engineers", title: "Bibliography")
]

