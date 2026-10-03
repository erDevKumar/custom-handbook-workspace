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

#pfig("Fig S14.1 · typeahead in 30ms — precompute offline, replicate everywhere, one GET on the hot path")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.3, 20.7, 3.0, "4GB index fits in memory per region; ranking is historical, not textual; no cross-region hop on the hot path")

  ppill(1.9, 0, "key", "keystroke \"lond\"", w: 3.6)
  pstep(6.56, 0, "cli", "debounce 150ms", "cancel + local cache", st-man, n: 1, actor: "client", w: 4.8)
  pdec(11.42, 0, "loc", "prefix in\nlocal cache?")
  pstep(16.27, 0, "edge", "GET pfx:\"lond\"", "regional Redis · 0.5ms", st-auto, n: 2, actor: "edge", w: 4.8)
  ppill(18.9, -3.8, "ans", "top-10, 13ms spare", w: 4.0)

  pstep(14.04, -3.8, "orig", "cross-region hop", "150ms · never used", st-integ, n: 3, actor: "origin", w: 4.8)
  pstep(8.78, -3.8, "repl", "4GB replicated", "24 nodes · 4 regions", st-auto, n: 4, actor: "platform", w: 4.8)
  pstep(3.53, -3.8, "job", "hourly ranking", "CTR-weighted, filtered", st-auto, n: 5, actor: "batch", w: 4.8)
  ppill(4.0, -7.2, "logs", "query logs — what users PICKED", w: 5.6)

  line("key.east", "cli.west", mark: (end: ">"), stroke: hot)
  line("cli.east", "loc.west", mark: (end: ">"), stroke: lookup)
  line("loc.east", "edge.west", mark: (end: ">"), stroke: miss)
  plabel(13.3, 0, "miss", c: green)
  line("edge.south", (16.27, -2.0), (18.9, -2.0), "ans.north", mark: (end: ">"), stroke: hot)
  plabel(17.6, -2.0, "10-15ms RTT, same continent", c: green, dy: 0.34)
  line("edge.south", (16.27, -2.6), (14.04, -2.6), "orig.north", mark: (end: ">"), stroke: except)
  plabel(15.1, -2.6, "the hop the design removes", c: red, dy: 0.34)
  line("repl.east", "orig.west", mark: (end: ">"), stroke: lookup)
  line("job.east", "repl.west", mark: (end: ">"), stroke: async)
  line("logs.north", "job.south", mark: (end: ">"), stroke: async)

  ploop("loc.south", "cli.south", -1.8, "hit — answered locally, zero network", c: blue)
}))
#pcards(
  [A 30ms budget that the speed of light already spends 15ms of; an index small enough to replicate whole; personalisation merged client-side, never queried per user],
  [In: 300,000 QPS of keystrokes, debounced at 150ms · Out: the precomputed top-10 for that prefix from the user's own region, one `GET`, no ranking and no index traversal at query time],
  [Query-log mining weighted by click-through · hourly materialisation of top-10 per prefix · 4GB replicated to in-memory Redis in 4 regions (24 nodes) · client debounce, cancellation and local cache],
)
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
