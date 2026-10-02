#import "/shared/lib/template.typ": *

// ============================================================================
// FRONT MATTER — roman numerals, no running heads.
// Order follows standard trade/technical book convention:
//   half-title · (blank) · title · copyright · dedication · contents ·
//   figures · tables · preface · how to use · methodology · notation · author
// ============================================================================


// ---------------------------------------------------------------- i · HALF-TITLE
#set page(numbering: none)
#v(1fr)
#align(center)[
  #text(font: headfont, size: 24pt, fill: ink)[Senior Engineering Manager]
  #v(3mm)
  #text(font: headfont, size: 15pt, fill: luma(110))[System Design & Infrastructure]
]
#v(1fr)
#pagebreak()

// --------------------------------------------------------------- ii · (blank)
#v(1fr)
#align(center, text(size: 8pt, fill: luma(160))[#emph[This page intentionally left blank.]])
#v(1fr)
#pagebreak()

// --------------------------------------------------------------- iii · TITLE
#v(1fr)
#align(center)[
  #text(font: headfont, size: 30pt, fill: ink)[Senior Engineering Manager]
  #v(4mm)
  #line(length: 110mm, stroke: 2.2pt + orange)
  #v(6mm)
  #text(font: bodyfont, size: 14pt, fill: ink)[System Design & Infrastructure Handbook]
  #v(3mm)
  #text(font: bodyfont, size: 10pt, fill: luma(110))[
    Foundations · 36 Modules · Interview Scenarios · Case Studies
  ]
  #v(18mm)
  #text(font: bodyfont, size: 11pt, fill: ink)[Devender Kumar]
  #v(14mm)
  #text(font: bodyfont, size: 9pt, fill: purple)[Edition 1.0 · October 2026]
]
#v(1fr)
#pagebreak()

// ----------------------------------------------------------- iv · COPYRIGHT
#v(1fr)
#block(width: 100%)[
  #set par(justify: false, leading: 0.72em)
  #text(size: 8.6pt)[
    *Senior Engineering Manager: System Design & Infrastructure Handbook* \
    Edition 1.0 — October 2026 \
    #v(3mm)
    Copyright © 2026 Devender Kumar. All rights reserved. \
    #v(3mm)
    #text(fill: purple)[Personal study edition.] Prepared as interview-preparation and
    reference material. Not for redistribution or commercial use.
    #v(3mm)
    *On accuracy.* Every topic in this handbook was written against the five-point
    verification procedure described on page xi. Algorithms follow their canonical papers;
    all capacity arithmetic is shown step by step so it can be checked rather than trusted.
    Where a figure is illustrative rather than measured, it is marked as such.
    #v(3mm)
    *On third-party systems.* Product names (PostgreSQL, Cassandra, Kafka, Redis, Envoy,
    Kubernetes and others) are referenced for technical illustration only. Architectural
    descriptions are drawn from public documentation and published papers; no proprietary
    or internal implementation detail is claimed as fact.
    #v(3mm)
    Set in Chalkboard SE and Marker Felt. Typeset with Typst and CeTZ. \
    Printed to A4 (210 × 297 mm).
  ]
]
#v(1fr)
#pagebreak()

// ----------------------------------------------------------- v · DEDICATION
#v(1fr)
#align(center)[
  #block(width: 105mm)[
    #set par(justify: false)
    #text(size: 10.5pt, style: "italic", fill: luma(80))[
      For every engineer who has been paged at 3am \
      by a system they were told could not fail.
    ]
    #v(8mm)
    #line(length: 30mm, stroke: 0.8pt + luma(170))
    #v(8mm)
    #text(size: 9pt, fill: luma(110))[
      "Everything fails all the time."
    ]
    #v(2mm)
    #text(size: 8.2pt, fill: luma(130))[— Werner Vogels]
  ]
]
#v(1fr)
#pagebreak()

// ------------------------------------------------------------- vii · CONTENTS
#set page(numbering: "i", number-align: center)
#fmhead("Contents")

// Generated from the registrations each chapter makes, so page numbers are the
// REAL ones. The previous edition hand-typed them and they were wrong the
// moment any chapter changed length.
#context {
  for e in tocentry.final() {
    // body pages are offset by the front matter; locate() gives the true target
    tocrow-linked(e.lvl, e.label, e.title, str(e.page), e.loc)
  }
}

#v(5mm)
#text(size: 8.3pt, fill: luma(110))[
  Front matter is numbered in roman numerals; the body restarts at 1.
  Complete: 6 foundation topics, 36 modules, 15 interview scenarios, 3 case studies.
]

#pagebreak()

// ------------------------------------------------- viii · FIGURES AND TABLES
#fmhead("Figures & Tables")

#text(size: 9.5pt)[
  Every chapter opens with at least one diagram and carries at least one table. Rather than
  reproduce a list that would rot with each revision, figures and tables are numbered by their
  chapter — #text(fill: purple)[Figure 4.2] is the second figure of chapter 4;
  #text(fill: purple)[Table M13.1] is the first table of module 13. The Contents and the Index
  are the navigation aids this book maintains automatically.
]
#v(4mm)

#text(font: headfont, size: 10.5pt, fill: blue)[Where to find the recurring reference material]
#v(2.5mm)

#text(size: 9pt)[
  #jump("appA")[Appendix A — Formulae: Amdahl, Little, quorum, burn rate] \
  #jump("appB")[Appendix B — Latency numbers, powers of two, typical sizes] \
  #jump("appC")[Appendix C — Every anti-pattern in the book, consolidated] \
  #jump("appD")[Appendix D — The day before an interview] \
  #jump("appE")[Appendix E — Quick-reference card] \
  #jump("appF")[Appendix F — Interview playbook: 30 / 45 / 60 minute frameworks] \
  #jump("appG")[Appendix G — Three worked mock interviews] \
  #v(2mm)
  #jump("glossary")[Glossary] #h(4mm) #jump("biblio")[Bibliography]
  #h(4mm) #jump("index")[Index] #h(4mm) #jump("colophon")[Colophon]
]
#v(4mm)

#text(size: 8.5pt, fill: luma(110))[
  In the PDF every entry above is a live link. In print, each carries its page
  number so the reference is findable without one.
]

#pagebreak()

// ---------------------------------------------------------------- ix · PREFACE
#fmhead("Preface")

#text(size: 9.5pt)[
  This handbook exists because system design interviews at the senior-engineering-manager level
  test something different from what most preparation material covers. They are not quizzes about
  whether you can name a consensus algorithm. They test whether you can
  #underline(stroke: 1pt + green)[reason about a system you have never seen], out loud, under
  time pressure, while someone interrupts you with constraints.

  That reasoning has a shape. You establish what the system must do, estimate how much of it
  there will be, identify where it will break first, and then make the trade-offs explicit rather
  than implicit. The candidate who says "we'll use Kafka" has answered nothing. The candidate who
  says "writes are 50k/s and bursty, consumers are slow, and we need replay — so a log, and
  here's what partition count costs us at rebalance time" has demonstrated the entire skill.

  #text(fill: purple, weight: "bold")[What this book assumes.] That you are already a working
  engineer. There is no chapter explaining what an API is. Concepts are introduced at the depth
  an experienced engineer needs to #text(fill: green)[use] them in an argument — mechanics,
  numbers, failure modes — and not one line further.

  #text(fill: purple, weight: "bold")[What it refuses to do.] It does not present any technology
  as universally correct. Every module ends with an anti-pattern, because knowing when a
  technique is wrong is worth more in an interview, and in production, than knowing when it is
  right. Anyone can recommend Redis. The job is knowing what it costs you.

  #text(fill: purple, weight: "bold")[On the numbers.] Every capacity figure shows its
  arithmetic. This is deliberate: in an interview you will be asked to estimate under pressure,
  and the only way that becomes possible is if you have done the multiplication yourself enough
  times to recognise when an answer is implausible. Memorising that a year is 525,960 minutes is
  worth more than memorising any architecture diagram.
]
#pagebreak()

// ------------------------------------------------------- x · HOW TO USE THIS
#fmhead("How to Use This Handbook")

#text(size: 9.5pt)[
  There are three ways through this material, depending on how much time you have.
]
#v(3mm)

#table(
  columns: (auto, auto, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#eef4fb") } else { none },
  text(font: headfont, size: 9pt, fill: blue)[Path],
  text(font: headfont, size: 9pt, fill: blue)[Time],
  text(font: headfont, size: 9pt, fill: blue)[Route],

  text(size: 8.6pt, fill: red, weight: "bold")[The day before],
  text(size: 8.6pt)[2--3 hours],
  text(size: 8.4pt)[Appendix D, then every KEY box and anti-pattern in Part 1. Skip the prose.],

  text(size: 8.6pt, fill: orange, weight: "bold")[Interview prep],
  text(size: 8.6pt)[2--3 weeks],
  text(size: 8.4pt)[Part 1 end to end, then the Part 2 modules matching the role's stack, then
    Part 3 scenarios. Do the arithmetic yourself before reading the worked answer.],

  text(size: 8.6pt, fill: green, weight: "bold")[Reference],
  text(size: 8.6pt)[ongoing],
  text(size: 8.4pt)[Index or Contents to the module. Each is self-contained; cross-references
    are explicit where a concept is defined elsewhere.],
)
#v(4mm)

#text(size: 9.5pt)[
  #text(fill: purple, weight: "bold")[Reading the callouts.] Four kinds appear throughout, and
  they are consistent:
]
#v(2mm)

#key[A takeaway worth remembering past the end of the page. If you read nothing else in a
  section, read these.]
#v(2mm)
#anti("the name of the mistake")[
  A specific, common, costly error — the mechanism by which it happens, and the fix. Mandatory
  in every module.
]
#v(2mm)
#formula("Capacity arithmetic")[
  #text(size: 8.6pt)[Step-by-step numbers you should be able to reproduce without the book.]
]
#v(2mm)
#text(size: 9.5pt)[
  #note[Purple text is a margin caveat: the thing a careful engineer would add in the margin —
  the exception, the gotcha, the reason the simple version is not quite true.]
]
#pagebreak()

// ------------------------------------------- xi · THE VERIFICATION METHODOLOGY
#fmhead("The Verification Methodology")

#text(size: 9.5pt)[
  A reference book is only useful if you can trust it without re-deriving everything. Every topic
  in this handbook was written against the following five-point procedure, and the procedure is
  printed here so you can hold the book to it.
]
#v(3mm)

#text(size: 9.3pt)[
  #text(fill: red, weight: "bold")[1 · Theoretical and algorithmic rigour.] Consensus, storage and
  distributed-state algorithms follow their canonical papers — Raft (Ongaro & Ousterhout), Paxos
  (Lamport), LSM-trees (O'Neil), vector clocks (Fidge, Mattern), PACELC (Abadi). Where a paper
  exists, it is named, so the primary source is one search away.

  #text(fill: orange, weight: "bold")[2 · Mathematical and capacity sanity.] Every QPS, IOPS,
  storage and bandwidth figure shows its full arithmetic. No number appears without its working.
  Any figure that is illustrative rather than measured is marked as such.

  #text(fill: green, weight: "bold")[3 · Anti-pattern audit.] Every topic names at least one
  common industry mistake explicitly — using Redlock for safety-critical locking, 2PC across
  synchronous microservices, averaging percentiles, naive offset pagination. Knowing the failure
  mode is the point.

  #text(fill: blue, weight: "bold")[4 · Current standards compliance.] Material reflects
  production practice as of 2026: OpenTelemetry and W3C `traceparent`, HTTP/3 and QUIC,
  Kubernetes lifecycle signals, eBPF, CNCF conventions. Superseded practice is marked as
  historical where it still appears in interviews.

  #text(fill: purple, weight: "bold")[5 · Visual clarity.] Diagrams are vector figures with
  consistent semantics: #text(fill: green)[green] is the healthy path,
  #text(fill: red)[red] is failure, #text(fill: orange)[orange] is formula or emphasis,
  #text(fill: purple)[purple] is definition or caveat, #text(fill: blue)[blue] is structure.
  #note[This replaces the monochrome-ASCII constraint of the first draft. Colour is used
  semantically rather than decoratively, and line style (solid, dashed, dotted) carries meaning
  independently, so a greyscale print remains readable.]
]
#pagebreak()

// --------------------------------------------- xii · NOTATION & CONVENTIONS
#fmhead("Notation & Conventions")

#text(font: headfont, size: 10.5pt, fill: blue)[Diagram legend]
#v(2mm)
#align(center, cetz.canvas(length: 0.86cm, {
  import cetz.draw: *
  rnode(2.4, 2.4, "n1", "Component", "tech · capacity", blue, w: 4.0, h: 1.1)
  content((7.8, 2.4), dlbl("a service or store; the subtitle gives real tech and sizing", sz: 7.5pt))

  line((0.8, 1.2), (3.8, 1.2), mark: (end: ">"), stroke: hot)
  content((8.0, 1.2), dlbl("the healthy / hot path", sz: 7.5pt, c: green))
  line((0.8, 0.5), (3.8, 0.5), mark: (end: ">"), stroke: lookup)
  content((7.6, 0.5), dlbl("a cache probe or conditional lookup", sz: 7.5pt, c: green))
  line((0.8, -0.2), (3.8, -0.2), mark: (end: ">"), stroke: miss)
  content((7.5, -0.2), dlbl("failure, miss, or fallthrough", sz: 7.5pt, c: red))
  line((0.8, -0.9), (3.8, -0.9), mark: (end: ">"), stroke: async)
  content((7.9, -0.9), dlbl("asynchronous / eventually consistent", sz: 7.5pt, c: purple))
  line((0.8, -1.6), (3.8, -1.6), mark: (end: ">"), stroke: cold)
  content((7.3, -1.6), dlbl("cold tier / archival", sz: 7.5pt, c: orange))
  badge(2.3, -2.4, "n", green)
  content((7.2, -2.4), dlbl("a numbered step in the flow", sz: 7.5pt))
}))
#v(3mm)

#text(font: headfont, size: 10.5pt, fill: blue)[Units]
#v(2mm)
#text(size: 9pt)[
  Storage uses #text(fill: purple, weight: "bold")[decimal] units unless stated: 1 TB = 10#super[12]
  bytes. Memory uses #text(fill: purple, weight: "bold")[binary]: 1 GiB = 2#super[30] bytes. This
  mirrors how vendors bill and how allocators report, and the two differ by about 7% at terabyte
  scale — enough to matter in a capacity estimate.
  #linebreak()
  #text(weight: "bold")[QPS] is queries per second, measured at the service boundary.
  #text(weight: "bold")[p99] means the 99th percentile of a merged histogram, never an average
  of per-host percentiles (see §4.1).
  #text(weight: "bold")[N] is replica count, #text(weight: "bold")[W] write quorum,
  #text(weight: "bold")[R] read quorum.
  #linebreak()
  One year is taken as #text(fill: orange, weight: "bold")[525,960 minutes]
  (365.25 × 24 × 60) throughout.
]
#pagebreak()

// ---------------------------------------------------- xiii · ABOUT THE AUTHOR
#fmhead("About the Author")

#text(size: 9.5pt)[
  #text(weight: "bold")[Devender Kumar] is a fullstack engineer who works across the whole
  delivery path: Go services on the backend, Kotlin and Jetpack Compose on Android, Swift and
  UIKit on iOS, and React with TypeScript on the web.

  That range is the reason this handbook keeps returning to the client edge. Most system design
  material is written from the data centre outward and treats the mobile client as a thin
  consumer of an API. In practice the hardest problems arrive at precisely that boundary: offline
  synchronisation and conflict resolution, token rotation on a device you cannot reach, push
  delivery to a fleet you do not control, API evolution for app versions that will never be
  upgraded, and carrier networks that drop a connection mid-handshake. Those constraints shape
  backend architecture more than most backend engineers expect, and they are where interview
  answers most often fall apart.

  This handbook was assembled as preparation for senior engineering manager system design
  interviews, and then written down properly on the theory that material worth revising twice is
  worth typesetting once.
]
#v(5mm)
#line(length: 45mm, stroke: 0.8pt + luma(170))
#v(3mm)
#text(size: 8.5pt, fill: luma(100))[
  Corrections and disagreements are welcome. A technical book with no errata is a book nobody
  checked.
]
