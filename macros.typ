#let final = true
#let prof_indent = 1cm


#let CommitteeProf(name, title: "") = {
  h(prof_indent) + [Professor ] + name
  
  if title != "" {
    [, #title]
  }
} 

#let PreambleChapter(title) = context {
  heading(numbering: none)[#upper(title)]
}

#let CircledNumber(num) = {
  // box(align(horizon, circle(radius: 0.5em, fill: black, inset: (x: 0pt, y: 0pt))[#text(fill: white)[#num]]))

  let nums = ("⓿",
    "❶", "❷", "❸", "❹", "❺", "❻", "❼", "❽", "❾", "❿",
    "⓫", "⓬", "⓭", "⓮", "⓯", "⓰", "⓱", "⓲", "⓳", "⓴")

    h(0.25em) + box[#scale(200%, move(dy: -0em, dx: 0.1em, nums.at(num)))] + h(0.6em)
}

#let BoldParagraph(title) = {
  let str = none

  if type(title) == type("") {
    str = title
  } else if title.has("text") {
    str = title.text
  } else {
    str = title.children.flatten().last()
    str = str.text
  }
  
  let last = str.last()
  if last == "." {
    strong(title)
  } else {
    [#strong(title)] + [.]
  }
}

#let green_check = text(fill: green.darken(40%))[#sym.checkmark]
#let red_cross = text(fill: red.darken(40%))[#sym.crossmark]

#let yes = table.cell(fill: green.lighten(60%), green_check)
#let yes_heavy = table.cell(fill: green.lighten(40%), text(fill: green.darken(40%))[#sym.checkmark])
#let no = table.cell(fill: red.lighten(60%), red_cross)

#let UpdateLater(txt) = text(fill: blue)[#txt]

#let ln = linebreak;

#let Green(txt) = {
  if not final {
    text(fill: green.darken(20%), strong(txt))
  } else {
    text(txt)
  }
}

#let Red(txt) = {
  if final {
  } else {
    text(fill: red.darken(20%), strong(txt))
  }
}