// =============================================================================
// CUSTOM HANDBOOK WORKSPACE — shared style module ("college notes" look)
//
// Subject-agnostic. Used by every handbook in handbooks/*. Nothing here may
// mention a specific handbook's subject matter; that belongs in its folder.
//
// Used via:
//   pandoc in.md -o out.pdf --pdf-engine=typst \
//     --template=pandoc-typst.template -V template=template.typ
//
// Or imported directly by a hand-written .typ page:
//   #import "template.typ": *
//
// DESIGN DECISIONS (do not quietly revert these):
//  - Colour is PRIMARY. The original spec's rule 5 (monochrome ASCII art) was
//    formally retired by the user on 2026-10-01 in favour of 6-pen colour notes.
//  - Diagrams are CeTZ vector graphics with NAMED ANCHORS, never hand-placed
//    coordinates. Anchors make arrows connect edge-to-edge by construction;
//    hand-placed boxes were the cause of the distorted diagrams in samples 1-3.
//  - Callout blocks are `breakable: false`. A callout split across a page break
//    leaves an empty coloured header, which looked broken in the first proof.
// =============================================================================

#import "@preview/cetz:0.4.2"

// ---------------------------------------------------------------- 6-PEN SET --
// Each pen carries ONE meaning. Consistency is what makes colour a reading aid
// instead of decoration.
#let ink    = rgb("#1c2b4a")   // blue-black : body text, default
#let red    = rgb("#c0392b")   // red        : danger, anti-patterns, failures
#let green  = rgb("#1e7a46")   // green      : correct path, wins, fixes
#let blue   = rgb("#1f6fb5")   // blue       : structure, tiers, headings
#let orange = rgb("#d35400")   // orange     : formulas, maths, emphasis
#let purple = rgb("#6c3483")   // purple     : definitions, margin caveats
#let hl     = rgb("#ffe9a8")   // highlighter: the one takeaway per section
#let paper  = rgb("#fdfcf7")   // cream notebook paper

#let bodyfont = "Chalkboard SE"
#let headfont = "Marker Felt"


// ------------------------------------------------------------------- ICONS --
// Geometric glyphs only — they render as monochrome text, inherit the pen
// colour, and print correctly in greyscale. Emoji were tested and rejected:
// they render as colour bitmaps that clash with the ink aesthetic, and several
// (flag, pointing hand) have no glyph in the embedded fonts at all.
//
// Each icon has ONE meaning, matching the pen it is drawn in.
#let ico-key    = "▸"   // the takeaway  (points at it)
#let ico-anti   = "✗"   // anti-pattern  (this is wrong)
#let ico-math   = "§"   // formula / arithmetic
#let ico-note   = "※"   // margin caveat
#let ico-win    = "✓"   // the correct path
#let ico-fail   = "▲"   // failure mode  (warning triangle)
#let ico-ask    = "?"   // interview question
#let ico-diag   = "◆"   // diagram / architecture
#let ico-tbl    = "■"   // trade-off matrix
#let ico-exec   = "●"   // execution / delivery strategy

// ------------------------------------------------------------------- INDEX --
// Index entries register themselves where the term is DEFINED or substantially
// discussed, exactly as reg() does for the contents. The index is therefore
// generated from real positions and cannot drift when content moves — the
// hand-written version it replaces was already wrong after one repagination.
#let indexentry = state("indexentry", ())

// Mark a term at the point it is discussed. Invisible in the text.
#let ix(term) = {
  context {
    let pg = counter(page).get().first()
    let here = here()
    indexentry.update(e => e + ((term: term, page: pg, loc: here),))
  }
}

// Mark AND display the term in one call, for use inline in prose.
#let ixt(term, body) = { ix(term); body }

// Renders the collected entries: alphabetical, de-duplicated, page list per
// term, each page number a live link.
#let indexbody() = context {
  let entries = indexentry.final()
  // group by term
  let groups = (:)
  for e in entries {
    let k = e.term
    if k in groups { groups.insert(k, groups.at(k) + (e,)) }
    else { groups.insert(k, (e,)) }
  }
  // case-insensitive sort, or "mTLS" and "preStop" land after Z
  let terms = groups.keys().sorted(key: k => lower(k))
  let letter = ""
  for t in terms {
    let first = upper(t.first())
    if first != letter {
      letter = first
      v(2mm)
      text(font: headfont, size: 9.5pt, fill: blue)[#letter]
      v(0.8mm)
    }
    // unique pages, in order
    let seen = ()
    let locs = ()
    for e in groups.at(t) {
      if not seen.contains(e.page) { seen.push(e.page); locs.push(e) }
    }
    block(above: 0.9mm, below: 0mm)[
      #grid(columns: (1fr, auto), gutter: 3mm,
        text(size: 8.3pt)[#t],
        text(size: 8.3pt, fill: luma(100))[
          #locs.map(e => link(e.loc)[#str(e.page)]).join(", ")
        ])
    ]
  }
}

// ------------------------------------------------- NAMED ANCHORS / APPENDIX --
// A registry of jump targets so any page can link to an appendix, the glossary
// or the index by name. Each target calls `anchor("name")` where it begins;
// `jump("name")[label]` links to it and prints the page number for a printed
// copy. One mechanism, both media — same principle as reg()/tocrow-linked.
#let anchors = state("anchors", (:))

#let anchor(name) = context {
  let pg = counter(page).get().first()
  let here = here()
  anchors.update(a => { a.insert(name, (page: pg, loc: here)); a })
}

#let jump(name, label) = context {
  let a = anchors.final()
  if name in a {
    link(a.at(name).loc)[#text(fill: blue)[#label] #text(size: 7.6pt, fill: luma(110))[p.#str(a.at(name).page)]]
  } else { text(fill: red)[#label] }
}


}

// --------------------------------------------------------------- CROSS-REFS --
// One mechanism serves both readers. On screen the reference is a live link;
// on paper it prints "M13, p. 47" so the page is findable without the link.
// `xref` is used for chapters; `xsec` adds a section mark for paragraph-level
// precision in a printed copy.
#let xref(target, label) = context {
  let loc = query(target)
  if loc.len() == 0 { text(fill: red)[#label] } else {
    link(target)[#text(fill: blue)[#label], p.#str(counter(page).at(target).first())]
  }
}
#let xsec(target, label, sec) = context {
  let loc = query(target)
  if loc.len() == 0 { text(fill: red)[#label] } else {
    link(target)[#text(fill: blue)[#label] §#sec, p.#str(counter(page).at(target).first())]
  }
}

// ------------------------------------------------------------------ HEADINGS --
// A chapter heading. ALWAYS starts a fresh page: this is a reference book, so a
// reader flipping to a module must find it at a page top, and a heading must
// never be orphaned from the diagram that follows it.
#let h1(t, c: blue) = {
  pagebreak(weak: true)
  text(font: headfont, size: 18pt, fill: ink)[#t]
  place(dx: 0mm, dy: -1mm, line(length: 60mm, stroke: 2pt + c))
  v(5mm)
}
#let h2(t, c: blue) = { v(2mm); text(font: headfont, size: 11.5pt, fill: c)[#t]; v(1.5mm) }
#let h3(t, c: ink)  = { v(1.5mm); text(font: headfont, size: 10pt, fill: c)[#t]; v(1mm) }

// ------------------------------------------------------------------ CALLOUTS --
// All breakable:false — see header note.

// The single takeaway of a section.
#let key(t) = block(fill: hl, inset: 2.5mm, radius: 1pt, width: 100%, breakable: false)[
  #text(size: 9pt)[#text(fill: purple, weight: "bold")[#ico-key KEY: ]#t]
]

// Mandatory per spec Section 0, rule 3: one anti-pattern per topic.
#let anti(title, t) = block(
  width: 100%, inset: 2.8mm, stroke: (left: 2.5pt + red),
  fill: rgb("#fdf0ee"), breakable: false,
)[
  #text(font: headfont, size: 9.5pt, fill: red)[#ico-anti ANTI-PATTERN -- #title]
  #v(1mm)
  #text(size: 8.8pt)[#t]
]

// Spec rule 2: capacity maths must show its arithmetic.
#let formula(title, t) = block(
  width: 100%, inset: 3.5mm, stroke: 1.2pt + orange,
  radius: 2pt, fill: rgb("#fff8f0"), breakable: false,
)[
  #text(font: headfont, size: 10pt, fill: orange)[#ico-math #title]
  #v(1.5mm)
  #t
]

// A margin caveat — the thing a student scribbles beside the main point.
#let note(t) = text(size: 8.5pt, fill: purple)[#ico-note #t]

// Two boxes side by side (e.g. HIT path vs MISS path).
#let compare(left_title, left_body, right_title, right_body) = grid(
  columns: (1fr, 1fr), gutter: 4mm,
  block(inset: 2.5mm, radius: 2pt, fill: rgb("#eef7f1"), stroke: (left: 2pt + green))[
    #text(size: 8.5pt)[#text(fill: green, weight: "bold")[#left_title ]#left_body]
  ],
  block(inset: 2.5mm, radius: 2pt, fill: rgb("#fdf0ee"), stroke: (left: 2pt + red))[
    #text(size: 8.5pt)[#text(fill: red, weight: "bold")[#right_title ]#right_body]
  ],
)

// ------------------------------------------------------------ DIAGRAM HELPERS --
// Thin wrappers over CeTZ. The point of these is that a diagram is ASSEMBLED
// from named parts, so 36 modules' worth of diagrams are composition, not
// coordinate arithmetic.

#let dlbl(t, sz: 7.5pt, c: ink) = text(font: bodyfont, size: sz, fill: c)[#t]

// A labelled swimlane band. Call BEFORE the boxes that sit inside it.
#let swimlane(x1, y1, x2, y2, name, c, tint) = {
  import cetz.draw: *
  rect((x1, y1), (x2, y2),
    stroke: (paint: luma(200), dash: "dashed", thickness: 0.6pt), fill: tint)
  content((x1 + 1.2, y2 - 0.35), dlbl(name, sz: 7pt, c: c))
}

// A component box. `name` becomes the CeTZ anchor — use it for every arrow.
#let node(x, y, name, label, c, w: 2.5, h: 0.95) = {
  import cetz.draw: *
  rect((x - w/2, y - h/2), (x + w/2, y + h/2),
    stroke: 1.3pt + c, radius: 0.1, fill: white, name: name)
  content(name + ".center", dlbl(label))
}

// RICH node: title + a coloured technology/capacity subtitle underneath.
// Use this wherever the concrete tech or sizing is part of the lesson
// ("Envoy · mTLS", "Go · 12 pods", "primary · 8vCPU", "LRU 10k · 0.05ms").
#let rnode(x, y, name, title, sub, c, w: 3.2, h: 1.3) = {
  import cetz.draw: *
  rect((x - w/2, y - h/2), (x + w/2, y + h/2),
    stroke: 1.3pt + c, radius: 0.12, fill: white, name: name)
  content((x, y + 0.22), dlbl(title, sz: 8pt, c: ink))
  content((x, y - 0.26), dlbl(sub, sz: 6.3pt, c: c))
}

// A numbered step badge — put these ON the arrows to make a flow readable
// in order, so the prose can refer to "step 3" unambiguously.
#let badge(x, y, n, c) = {
  import cetz.draw: *
  circle((x, y), radius: 0.32, stroke: 1.1pt + c, fill: white)
  content((x, y), dlbl(n, sz: 7pt, c: c))
}

// An annotation bracket spanning a range of the diagram, for latency budgets,
// ownership boundaries, "this part is one transaction", etc.
#let bracket(x1, x2, y, label, c) = {
  import cetz.draw: *
  line((x1, y + 0.35), (x1, y), (x2, y), (x2, y + 0.35), stroke: 0.9pt + c)
  content(((x1 + x2) / 2, y - 0.45), dlbl(label, sz: 7pt, c: c))
}

// A stacked "database" cylinder — reads instantly as storage in a diagram.
#let cylinder(x, y, name, label, c, w: 2.2, h: 1.1) = {
  import cetz.draw: *
  rect((x - w/2, y - h/2), (x + w/2, y + h/2 - 0.18),
    stroke: 1.3pt + c, fill: white, name: name)
  line((x - w/2, y + h/2 - 0.18), (x - w/2, y + h/2 - 0.05), stroke: 1.3pt + c)
  line((x + w/2, y + h/2 - 0.18), (x + w/2, y + h/2 - 0.05), stroke: 1.3pt + c)
  content((x, y - 0.05), dlbl(label, sz: 7.5pt))
}

// Line styles carry meaning, so a greyscale print still reads:
//   hot    = solid thick green   : the happy path
//   lookup = dashed green        : a cache probe
//   miss   = solid red           : fallthrough / failure
//   async  = dashed purple       : replication, eventual consistency
//   cold   = dotted orange       : archival / cold storage
#let hot    = 1.4pt + green
#let lookup = (paint: green,  thickness: 1.1pt, dash: "dashed")
#let miss   = 1.1pt + red
#let async  = (paint: purple, thickness: 1.1pt, dash: "dashed")
#let cold   = (paint: orange, thickness: 1.0pt, dash: "dotted")

// ----------------------------------------------------------------- BOOK PARTS --
// Book-structure helpers. A standard engineering book is front matter in roman
// numerals, body in arabic restarting at 1, running heads on body pages only,
// and part-title pages that start recto with no header.

// --- BOOK STATE -----------------------------------------------------------
// The master document (book.typ) configures the page header ONCE and reads
// these. A chapter fragment sets them via `chapterhead()` as its first line.
// Rationale: `set page(header: ..)` inside a function does not escape that
// function's scope — an earlier version did exactly that and silently produced
// no header at all on every page.
#let partname    = state("partname", "")
#let chaptername = state("chaptername", "")
#let bodystart   = state("bodystart", false)

// Declared at the top of every chapter fragment.
#let chapterhead(part, chapter) = {
  partname.update(part)
  chaptername.update(chapter)
}

// Registered by each chapter so the Contents page can be generated from real
// page numbers instead of hand-maintained guesses that rot on every edit.
#let tocentry = state("tocentry", ())
// Registers a TOC entry. The page number is read AFTER a weak pagebreak, because
// h1() breaks to a fresh page: without this, every entry records the page the
// PREVIOUS chapter ended on and the whole contents is off by one.
// Registers a TOC entry AND drops a navigable anchor at that point, so the
// contents page can link straight to it in a PDF reader. The page number is
// read after the weak pagebreak because h1() starts chapters on a fresh page.
#let reg(lvl, label, title) = {
  pagebreak(weak: true)
  // anchor: a zero-size figure carrying a label derived from the entry
  context {
    let pg = counter(page).get().first()
    let here = here()
    tocentry.update(e => e + ((lvl: lvl, label: label, title: title, page: pg, loc: here),))
  }
}

// A TOC row that links to its destination. `dest` is a page number; PDF readers
// honour a page-level link, which is what makes the contents clickable.
#let tocrow-linked(lvl, label, title, page, dest) = {
  let indent = (0mm, 6mm, 13mm).at(lvl)
  let sz = (10.5pt, 9.4pt, 8.6pt).at(lvl)
  let wt = ("bold", "bold", "regular").at(lvl)
  let col = (ink, ink, luma(85)).at(lvl)
  let fnt = (headfont, bodyfont, bodyfont).at(lvl)
  block(above: if lvl == 0 { 4.5mm } else { 1.5mm }, below: 0mm)[
    #pad(left: indent)[
      #link(dest)[
        #grid(columns: (auto, 1fr, auto), gutter: 2mm,
          text(font: fnt, size: sz, weight: wt, fill: col)[
            #if label != none [#label#h(2.2mm)]#title
          ],
          align(bottom)[#box(width: 100%, inset: (bottom: 1.6pt),
            repeat(text(size: 7pt, fill: luma(175))[.]))],
          text(font: bodyfont, size: sz, fill: col)[#page])
      ]
    ]
  ]
}

// A part-title page: large numeral, title, and a short orientation paragraph.
#let parttitle(number, title, blurb) = {
  partname.update("")
  // A part-title page is unnumbered AND does not advance the printed count,
  // so chapter 1 opens on page 1 as it does in a printed book.
  set page(numbering: none)
  counter(page).update(n => n - 1)
  v(1fr)
  align(center)[
    #text(font: headfont, size: 13pt, fill: orange)[PART #number]
    #v(5mm)
    #text(font: headfont, size: 30pt, fill: ink)[#title]
    #v(4mm)
    #line(length: 90mm, stroke: 2pt + orange)
    #v(8mm)
    #block(width: 115mm)[
      #set par(justify: false)
      #align(center, text(font: bodyfont, size: 10pt, fill: luma(80))[#blurb])
    ]
  ]
  v(1fr)
  pagebreak(weak: true)
}

// Front-matter page heading (no numbering, no running head interference).
#let fmhead(t) = {
  v(2mm)
  text(font: headfont, size: 20pt, fill: ink)[#t]
  v(2mm)
  line(length: 55mm, stroke: 2pt + blue)
  v(6mm)
}

// A TOC row with dot leaders. `lvl` 0 = part, 1 = chapter, 2 = section.
// Label and title sit on ONE line, leaders fill to the page number.
#let tocrow(lvl, label, title, page) = {
  let indent = (0mm, 6mm, 13mm).at(lvl)
  let sz = (10.5pt, 9.4pt, 8.6pt).at(lvl)
  let wt = ("bold", "bold", "regular").at(lvl)
  let col = (ink, ink, luma(85)).at(lvl)
  let fnt = (headfont, bodyfont, bodyfont).at(lvl)
  block(above: if lvl == 0 { 4.5mm } else { 1.5mm }, below: 0mm)[
    #pad(left: indent)[
      #grid(columns: (auto, 1fr, auto), gutter: 2mm,
        text(font: fnt, size: sz, weight: wt, fill: col)[
          #if label != none [#label#h(2.2mm)]#title
        ],
        align(bottom)[#box(width: 100%, inset: (bottom: 1.6pt),
          repeat(text(size: 7pt, fill: luma(175))[.]))],
        text(font: bodyfont, size: sz, fill: col)[#page])
    ]
  ]
}

// Index entry: term + page list.
#let idxrow(term, pages) = block(above: 0.9mm, below: 0mm)[
  #grid(columns: (1fr, auto), gutter: 3mm,
    text(size: 8.3pt)[#term],
    text(size: 8.3pt, fill: luma(100))[#pages])
]

// Glossary entry.
#let glos(term, def) = block(above: 1.6mm, below: 0mm)[
  #text(size: 8.6pt, weight: "bold", fill: purple)[#term] #h(1mm)
  #text(size: 8.6pt)[#def]
]

// Bibliography entry.
#let ref(authors, year, title, note) = block(above: 1.6mm, below: 0mm)[
  #text(size: 8.4pt)[#text(weight: "bold")[#authors] (#year).
  #text(style: "italic")[#title]. #text(fill: luma(100))[#note]]
]

// -------------------------------------------------------- FLOWCHART SHAPES --
// Standard flowchart vocabulary. Shape carries meaning independently of colour,
// so the semantics survive a greyscale print:
//   rounded  = start / end          diamond = decision
//   rect     = process / service    parallelogram = input / output (I/O)
//   cylinder = datastore            hexagon = preparation / config
//   doc      = report / document    queue  = buffered channel

// Decision diamond. Label the outgoing edges yes/no at the call site.
#let decision(x, y, name, label, c, w: 3.2, h: 1.5) = {
  import cetz.draw: *
  // An invisible rect supplies the compass anchors; the diamond is drawn over
  // it. CeTZ polygons expose only a centroid, so edges could not attach.
  rect((x - w/2, y - h/2), (x + w/2, y + h/2), stroke: none, name: name)
  line((x - w/2, y), (x, y + h/2), (x + w/2, y), (x, y - h/2), close: true,
    stroke: 1.3pt + c, fill: white)
  content((x, y), dlbl(label, sz: 7pt))
}

// Terminator: the start or end of a flow.
#let terminal(x, y, name, label, c, w: 2.8, h: 0.9) = {
  import cetz.draw: *
  rect((x - w/2, y - h/2), (x + w/2, y + h/2),
    stroke: 1.3pt + c, radius: h/2, fill: white, name: name)
  content((x, y), dlbl(label, sz: 7.5pt))
}

// Parallelogram: input or output crossing a system boundary.
#let io(x, y, name, label, c, w: 3.4, h: 0.95) = {
  import cetz.draw: *
  let sk = 0.35
  rect((x - w/2, y - h/2), (x + w/2, y + h/2), stroke: none, name: name)
  line((x - w/2 + sk, y + h/2), (x + w/2 + sk, y + h/2),
       (x + w/2 - sk, y - h/2), (x - w/2 - sk, y - h/2), close: true,
    stroke: 1.3pt + c, fill: white)
  content((x, y), dlbl(label, sz: 7pt))
}

// Hexagon: preparation, configuration, or a gate.
#let prep(x, y, name, label, c, w: 3.4, h: 1.0) = {
  import cetz.draw: *
  let k = 0.45
  rect((x - w/2, y - h/2), (x + w/2, y + h/2), stroke: none, name: name)
  line((x - w/2 + k, y + h/2), (x + w/2 - k, y + h/2), (x + w/2, y),
       (x + w/2 - k, y - h/2), (x - w/2 + k, y - h/2), (x - w/2, y), close: true,
    stroke: 1.3pt + c, fill: white)
  content((x, y), dlbl(label, sz: 7pt))
}

// Queue / buffered channel: an open-ended box with division marks.
#let queue(x, y, name, label, c, w: 3.6, h: 0.9) = {
  import cetz.draw: *
  rect((x - w/2, y - h/2), (x + w/2, y + h/2), stroke: 1.3pt + c, fill: white, name: name)
  for i in (1, 2) {
    line((x - w/2 + i * w/4, y - h/2), (x - w/2 + i * w/4, y + h/2),
      stroke: 0.6pt + luma(170))
  }
  content((x, y + h/2 + 0.28), dlbl(label, sz: 6.5pt, c: c))
}

// Document / report shape (wavy bottom approximated by a step).
#let doc(x, y, name, label, c, w: 3.0, h: 0.95) = {
  import cetz.draw: *
  rect((x - w/2, y - h/2), (x + w/2, y + h/2), stroke: none, name: name)
  line((x - w/2, y + h/2), (x + w/2, y + h/2), (x + w/2, y - h/2 + 0.12),
       (x + w/4, y - h/2 - 0.1), (x - w/4, y - h/2 + 0.12), (x - w/2, y - h/2 - 0.08),
       close: true, stroke: 1.3pt + c, fill: white)
  content((x, y + 0.05), dlbl(label, sz: 7pt))
}

// A routed edge through intermediate waypoints, for orthogonal routing around
// other shapes. Pass any number of points between the endpoints.
#let route(points, c, kind: "solid") = {
  import cetz.draw: *
  let st = if kind == "dash" { (paint: c, thickness: 1.1pt, dash: "dashed") }
           else if kind == "dot" { (paint: c, thickness: 1.0pt, dash: "dotted") }
           else { 1.2pt + c }
  line(..points, mark: (end: ">"), stroke: st)
}

// A labelled edge between two named shapes.
#let edge(from, to, label, c, kind: "solid") = {
  import cetz.draw: *
  let st = if kind == "dash" { (paint: c, thickness: 1.1pt, dash: "dashed") }
           else if kind == "dot" { (paint: c, thickness: 1.0pt, dash: "dotted") }
           else { 1.2pt + c }
  line(from, to, mark: (end: ">"), stroke: st)
}

// ------------------------------------------------------------------- PAGE CONF --
// `conf` is the entry point pandoc's typst template calls.
#let conf(
  title: none, subtitle: none, authors: (), keywords: (), date: none,
  lang: "en", region: "US", abstract: none, abstract-title: none, thanks: none,
  margin: (top: 13mm, bottom: 13mm, left: 14mm, right: 14mm),
  paper-size: "a4",
  font: (bodyfont,), fontsize: 9.5pt, mathfont: none, codefont: ("DejaVu Sans Mono",),
  linestretch: 1.0, sectionnumbering: none, pagenumbering: "1",
  linkcolor: none, citecolor: none, filecolor: none, cols: 1,
  doc,
) = {
  set page(paper: paper-size, margin: margin, numbering: pagenumbering, fill: paper)
  set par(leading: 0.62em, justify: true)
  set text(font: font, size: fontsize, fill: ink, lang: lang, region: region)
  set heading(numbering: sectionnumbering)

  show heading.where(level: 1): it => {
    text(font: headfont, size: 18pt, fill: ink)[#it.body]
    place(dx: 0mm, dy: -1mm, line(length: 60mm, stroke: 2pt + blue))
    v(5mm)
  }
  show heading.where(level: 2): it => {
    v(2mm); text(font: headfont, size: 11.5pt, fill: blue)[#it.body]; v(1.5mm)
  }
  show heading.where(level: 3): it => {
    v(1.5mm); text(font: headfont, size: 10pt, fill: ink)[#it.body]; v(1mm)
  }

  show raw: set text(font: codefont, size: 8.5pt)
  show raw.where(block: true): it => block(
    width: 100%, breakable: false, inset: (x: 3pt, y: 5pt),
    fill: rgb("#f3f1ea"), radius: 2pt, it,
  )

  set table(inset: (x: 4mm, y: 2.4mm), stroke: 0.5pt + luma(190))
  show link: it => underline(it)

  // Title page. Forced break lives here because pandoc's typst writer silently
  // DROPS a markdown `\newpage` — discovered during the first proof build.
  if title != none {
    set page(numbering: none)
    v(1fr)
    align(center)[
      #text(font: headfont, size: 28pt, fill: ink)[#title]
      #v(3mm)
      #line(length: 70mm, stroke: 2pt + orange)
      #if subtitle != none [ #v(6mm) #text(font: bodyfont, size: 13pt, fill: ink)[#subtitle] ]
      #if authors != () [ #v(12mm) #text(size: 10pt)[#authors.map(a => a.name).join(", ")] ]
      #if date != none [ #v(4mm) #text(size: 9pt, fill: purple)[#date] ]
    ]
    v(1fr)
    pagebreak(weak: true)
  }

  doc
}
