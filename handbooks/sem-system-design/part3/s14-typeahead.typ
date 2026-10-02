#import "/shared/lib/template.typ": *
#reg(1, "S14", "Typeahead at 300k QPS, p99 < 30 ms")
#chapterhead("Part 3 · Interview Scenarios", "S14 · Global Typeahead")

#h1("S14 · Typeahead at 300k QPS", c: orange)

#text[
  #text(fill: purple, weight: "bold")[The prompt.] Search suggestions, globally, at 300,000
  queries per second with a p99 under 30 ms end to end. Every keystroke is a request, so the
  volume is a multiple of actual searches.
]
#v(2mm)

#h2("1 · The dilemma and its root cause", c: red)

#text(size: 9pt)[
  A 30 ms #underline(stroke: 1pt + red)[end-to-end] budget includes the network. A cross-country
  round trip alone is 70 ms, so the answer must be served from somewhere
  #text(fill: red, weight: "bold")[geographically near the user] — the architecture is decided by
  the speed of light before any software choice is made.

  #text(fill: purple, weight: "bold")[Root cause of naive designs.] Treating typeahead as search.
  It is not: it is a #underline(stroke: 1pt + green)[precomputed popularity lookup]. Running an
  Elasticsearch prefix query per keystroke at 300k QPS is neither affordable nor fast enough, and
  the ranking you actually want ("what do people pick") is historical, not textual.
]
#v(2mm)

#formula("The latency budget, allocated")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[30 ms total, spent:]
    #linebreak()
    #h(3mm) client → regional edge (same continent): #text(weight: "bold")[10–15 ms]
    #linebreak()
    #h(3mm) edge → cache lookup: #text(weight: "bold")[0.5 ms]
    #linebreak()
    #h(3mm) serialise + return: #text(weight: "bold")[1 ms]
    #linebreak()
    #h(3mm) #text(fill: green, weight: "bold")[remaining headroom: ~13 ms]
    #linebreak()
    #text(fill: red, weight: "bold")[A single cross-region hop (150 ms) blows the budget by 5×.]
    Therefore: full replication to every region, no origin calls on the hot path.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Why replication is affordable:] 10M prefixes × 10 completions × 40 B =
    #text(fill: green, weight: "bold")[4 GB]. Small enough to hold entirely in memory in
    #underline(stroke: 1pt + green)[every region] — which is the fact that makes the whole design
    work.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Serving capacity:] 300,000 QPS ÷ ~100,000 ops/s per Redis node =
    #text(fill: orange, weight: "bold")[3 nodes minimum], ×2 for redundancy, ×4 regions =
    #text(weight: "bold")[24 nodes]. Modest for the traffic — because every request is a single
    key lookup.
  ]
]
#v(2mm)

#h2("2 · The design", c: green)

#align(center, cetz.canvas(length: 0.8cm, {
  import cetz.draw: *
  swimlane(-0.4, -1.3, 9.0, 2.2, "OFFLINE — rebuild hourly", purple, rgb("#f5eefa"))
  rnode(2.2, 1.3, "logs", "query logs", "what users PICKED", purple, w: 3.2, h: 0.85)
  rnode(6.6, 1.3, "job", "ranking job", "top-10 per prefix", purple, w: 3.2, h: 0.85)
  line("logs.east", "job.west", mark: (end: ">"), stroke: async)
  content((4.4, 0.3), dlbl("popularity, not text matching", sz: 6.3pt, c: purple))
  content((4.4, -0.35), dlbl("CTR-weighted, spam-filtered", sz: 6.3pt, c: purple))

  swimlane(9.8, -1.3, 18.4, 2.2, "ONLINE — one key lookup", green, rgb("#f6fbf7"))
  rnode(11.8, 1.3, "cli", "client", "debounce 150 ms", blue, w: 2.8, h: 0.85)
  rnode(15.6, 1.3, "edge", "regional Redis", "GET pfx:\"lond\"", green, w: 3.6, h: 0.85)
  line("cli.east", "edge.west", mark: (end: ">"), stroke: hot)
  content((14.2, 0.3), dlbl("no search engine on the hot path", sz: 6.3pt, c: green))
  content((14.2, -0.35), dlbl("full 4 GB replicated per region", sz: 6.3pt, c: green))
}))
#v(1.5mm)

#text(size: 9pt)[
  #text(fill: purple, weight: "bold")[Offline: rank by what users chose, not by what matches.]
  Mine query logs for the completions people actually clicked, weight by click-through and
  recency, filter spam and offensive terms, and materialise the top ten per prefix. This runs
  hourly; nothing about it is latency-sensitive.

  #text(fill: green, weight: "bold")[Online: one `GET` per keystroke.] The entire request is a
  single key lookup against an in-memory store in the user's own region. No ranking, no scoring,
  no index traversal at query time.

  #text(fill: blue, weight: "bold")[The client is part of the design.] Debounce 100–150 ms (do not
  query on every character), cancel in-flight requests when a newer keystroke arrives, and cache
  prefixes locally — typing "l-o-n-d-o-n" should not produce six uncancelled round trips.
  #underline(stroke: 1pt + green)[Client-side work removes more load than any server optimisation
  available here.]

  #text(fill: orange, weight: "bold")[Personalisation, if required, is a merge at the edge:] the
  global top-10 blended with a small per-user recent-queries list held client-side. Never a
  per-user server-side query — that destroys cacheability and the latency budget with it.
]
#v(2mm)

#key[
  Typeahead is a #underline(stroke: 1pt + green)[cache problem wearing a search problem's
  clothes]. Recognising that --- and therefore precomputing, replicating globally, and serving a
  single key lookup --- is the entire answer. Candidates who reach for Elasticsearch per keystroke
  have misread the question.
]
#v(2mm)

#h2("3 · SEM execution strategy", c: purple)

#text(size: 8.9pt)[
  #text(fill: purple, weight: "bold")[Freshness is the negotiable requirement.] Suggestions
  rebuilt hourly are fine for 99% of queries and
  #underline(stroke: 1pt + green)[radically simplify the system]. The exception is breaking news
  and trending terms, which need a fast path — a small, separately-updated trending set merged at
  read time. Negotiate this explicitly: "hourly, plus a 5-minute trending overlay" is far cheaper
  than "always current" and nearly as good.

  #text(fill: purple, weight: "bold")[Quality is a product problem, not an infrastructure one.]
  The hard work is the ranking: offensive-term filtering, spam suppression, locale handling,
  diversity so one popular query does not crowd out the rest. Budget for a data/relevance engineer
  — the serving layer is a week of work and the ranking is a quarter.

  #text(fill: purple, weight: "bold")[Blast radius.] A bad ranking build pushes poor or offensive
  suggestions to every user globally within minutes. #text(fill: green)[Gate it:] automated
  quality checks on the new dataset (overlap with the previous build, blocklist scan, volume
  sanity), then canary the dataset to one region before global promotion. Treat the data as a
  release artefact with the same rigour as code (M26).

  #text(fill: purple, weight: "bold")[Cost awareness.] 300k QPS of keystrokes is
  #text(fill: orange)[~26 billion requests/day]. Even at a tiny cost per request this is a
  material line item, and client-side debouncing is the single largest lever — a 150 ms debounce
  can halve the volume. Measure requests-per-search as the efficiency metric (M30).

  #text(fill: purple, weight: "bold")[Monitor what the user feels:] p99 measured
  #underline(stroke: 1pt + green)[at the client] (M19), suggestion click-through rate, and empty
  result rate. Server-side p99 looks excellent in every version of this system, including the
  broken ones.
]
#v(2mm)

#anti("querying the search engine on every keystroke")[
  Elasticsearch handles the real search well, so typeahead is pointed at the same cluster with a
  prefix query. At 300k QPS the cluster needs #text(fill: red, weight: "bold")[hundreds of
  nodes]; each query scores documents it will discard, p99 sits in the hundreds of milliseconds,
  and the typeahead load #underline(stroke: 1pt + red)[degrades the real search] that shares the
  cluster. The team's instinct is to add nodes, which is the most expensive possible response to
  an architectural mismatch. #text(fill: green)[Fix:] precompute completions offline, serve them
  from replicated memory, and leave the search engine for actual searches — of which there are
  perhaps 1% as many.
]
