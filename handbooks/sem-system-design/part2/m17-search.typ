#import "/shared/lib/template.typ": *
#reg(1, "M17", "Full-Text Search & Autocomplete")
#chapterhead("Part 2 · Modules", "M17 · Search & Autocomplete")
#ix("Inverted index")
#ix("Edge n-grams")
#ix("Deep pagination")

#h1("M17 · Full-Text Search & Autocomplete", c: orange)

#text[
  `LIKE '%term%'` cannot use an index, so it scans every row. A search engine inverts the
  problem: instead of asking each document whether it contains the term, it keeps a map
  #underline(stroke: 1pt + green)[from term to documents]. That one inversion is the whole idea.
]
#v(2mm)

#h2("1 · The inverted index", c: blue)

#pfig("Fig M17.1 · a document becomes postings; a keystroke and a query take different paths out")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.4, 20.6, 3.0, "the index is a derived projection — the DB is the source of truth · clients query through an alias, never an index name")

  // indexing row
  ppill(1.7, 0, "doc", "\"The Quick Fox\"", w: 3.2, c: purple)
  pstep(6.2, 0, "tok", "tokenise", "ICU analyzer · 20µs/doc", st-auto, n: 1, actor: "indexer", w: 3.4)
  pstep(10.8, 0, "filt", "stopword + stem", "lowercase, porter2 · 10µs", st-auto, n: 2, actor: "indexer", w: 3.8)
  pstep(15.6, 0, "seg", "append segment", "Lucene, immutable · 1s", st-auto, n: 3, actor: "shard", w: 4.0)
  ppill(19.6, 0, "post", "postings", w: 2.2, c: green)

  line("doc.east", "tok.west", mark: (end: ">"), stroke: hot)
  line("tok.east", "filt.west", mark: (end: ">"), stroke: hot)
  line("filt.east", "seg.west", mark: (end: ">"), stroke: hot)
  line("seg.east", "post.west", mark: (end: ">"), stroke: hot)
  ploop("post.north", "seg.north", 1.95, "merge drops tombstones · p99 spikes here", c: purple)

  // query row
  pdec(3.0, -3.8, "d", "keystroke?", w: 1.9)
  pstep(9.6, -3.8, "ta", "exact key GET", "Redis top-k prefix · 0.3ms", st-man, n: 4, actor: "typeahead", w: 4.6)
  pstep(9.6, -7.0, "mrg", "merge postings", "O(n+m), sorted doc ids · 4ms", st-auto, n: 5, actor: "coordinator", w: 4.6)
  pstep(15.4, -7.0, "bm", "BM25 score", "rarity × tf × field len · 3ms", st-auto, n: 6, actor: "shard", w: 4.4)
  ppill(19.4, -5.4, "out", "top 10 hits", w: 2.8, c: green)

  line("post.south", (19.6, -2.1), (3.0, -2.1), "d.north", mark: (end: ">"), stroke: wrap)
  line("d.east", "ta.west", mark: (end: ">"), stroke: lookup)
  plabel(6.3, -3.8, "yes", c: green)
  line("d.south", "mrg.west", mark: (end: ">"), stroke: hot)
  plabel(6.4, -5.9, "no — full query", c: luma(110), dy: 0)
  line("mrg.east", "bm.west", mark: (end: ">"), stroke: hot)
  line("ta.east", "out.west", mark: (end: ">"), stroke: hot)
  line("bm.east", "out.west", mark: (end: ">"), stroke: hot)
}))
#pcards(
  [Explicit mappings with `dynamic: strict`; shards sized 20–40 GB so a query fans out to 4, not 50],
  [In: 100M docs × 1 KB → ~40 GB inverted index · Out: 10 scored hits, or 10 precomputed completions in < 1 ms],
  [Lucene / Elasticsearch (alias-fronted) · Redis for the prefix→top-k table (10M prefixes ≈ 4 GB) · CDC from the primary store],
)
#v(2mm)

#text(size: 9pt)[
  Postings lists are kept #text(fill: green, weight: "bold")[sorted by document id], so
  intersecting two terms is a linear merge rather than a nested loop, and the lists compress
  extremely well (delta encoding plus variable-byte or roaring bitmaps).
  #note[Lucene segments are #underline(stroke: 1pt + green)[immutable], exactly like LSM
  SSTables (M1). A "delete" writes a tombstone and the document is filtered from results until a
  background merge removes it. Same trade: fast writes, deferred compaction cost, p99 spikes
  during merges.]
]
#v(2mm)

#h2("2 · Autocomplete is a different problem", c: purple)

#table(
  columns: (auto, 1fr, auto, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#f5eefa") } else { none },
  text(font: headfont, size: 8.5pt, fill: purple)[Approach],
  text(font: headfont, size: 8.5pt, fill: purple)[Mechanism],
  text(font: headfont, size: 8.5pt, fill: purple)[Latency],
  text(font: headfont, size: 8.5pt, fill: purple)[Cost],

  text(size: 8.3pt)[Prefix query],
  text(size: 8pt)[`term*` scanned at query time],
  text(size: 8.3pt, fill: red)[slow],
  text(size: 8.3pt, fill: green)[no extra index],

  text(size: 8.3pt, fill: green)[Edge n-grams],
  text(size: 8pt)[Index "fox" as f, fo, fox at write time — a prefix becomes an exact term match],
  text(size: 8.3pt, fill: green)[fast],
  text(size: 8.3pt, fill: orange)[index grows ~3–5×],

  text(size: 8.3pt)[FST / trie],
  text(size: 8pt)[Finite-state transducer in memory (Lucene suggester)],
  text(size: 8.3pt, fill: green)[fastest],
  text(size: 8.3pt, fill: orange)[RAM-resident],

  text(size: 8.3pt)[Precomputed top-k],
  text(size: 8pt)[Redis key per prefix holding the best 10 completions],
  text(size: 8.3pt, fill: green)[< 1 ms],
  text(size: 8.3pt, fill: red)[rebuild pipeline],
)
#v(1.5mm)

#key[
  Typeahead is a #underline(stroke: 1pt + green)[cache lookup], not a search. At 300k QPS with a
  sub-30 ms budget you cannot afford to score documents on every keystroke — you precompute the
  top completions per prefix and serve them from memory. Search engines answer "what matches";
  typeahead answers "what did people pick", which is a popularity ranking computed offline.
]
#v(2mm)

#h2("3 · Capacity arithmetic", c: orange)

#formula("Sizing an index and a typeahead tier")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[Index size:] 100M documents × 1 KB text = 100 GB raw. An inverted index
    is typically 30–50% of source after compression #sym.arrow.r
    #text(fill: orange, weight: "bold")[~40 GB], plus stored fields and doc values.
    #linebreak()
    Shard for both RAM and recovery: keep shards at 20–40 GB #sym.arrow.r
    #text(fill: green, weight: "bold")[4 primary shards], × 2 replicas = 12 shard copies.
    #note[Over-sharding is the common error: each shard carries fixed overhead and every query
    fans out to all of them, so 50 tiny shards means 50 sub-queries and a p99 set by the slowest.]
    #linebreak() #v(1mm)
    #text(weight: "bold")[Typeahead at 300k QPS, p99 < 30 ms:] serving from Redis at ~0.3 ms per
    lookup, one node sustains ~100k ops/s #sym.arrow.r
    #text(fill: orange, weight: "bold")[4–6 replicas] behind a round-robin, with the full prefix
    set replicated to each.
    #linebreak()
    Memory: 10M prefixes × 10 completions × 40 B =
    #text(fill: green, weight: "bold")[4 GB] — small enough to replicate everywhere, which is why
    this design works.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Edge n-gram blow-up:] indexing every prefix of every term multiplies
    index size by roughly the average term length. A 40 GB index becomes
    #text(fill: red, weight: "bold")[~160 GB]. Apply n-grams to a
    #underline(stroke: 1pt + green)[suggestion field only], never to full document text.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Deep pagination.] `from=100000&size=10` forces every shard to
  build and return the top 100,010 hits so the coordinator can merge and discard almost all of
  them. Memory and latency grow linearly with the offset.
  #text(fill: green)[Fix:] `search_after` with a cursor over the sort key, or `scroll` / PIT for
  exports. Cap `from` — this is a standard denial-of-service vector against search clusters.

  #text(fill: red, weight: "bold")[Mapping conflicts.] A field is auto-detected as `long` from
  the first document, then a later document sends `"12a"` and indexing fails silently for that
  document. #text(fill: green)[Fix:] explicit mappings, `dynamic: strict`, and alert on indexing
  failures — a search index that quietly drops documents is worse than one that errors.

  #text(fill: red, weight: "bold")[Reindex with no alias.] A mapping change requires a reindex,
  and pointing clients at the new index means downtime.
  #text(fill: green)[Fix:] always query through an #text(fill: purple)[alias]; build the new
  index, verify, then atomically repoint the alias.

  #text(fill: red, weight: "bold")[Search is not the source of truth.] A cluster failure loses
  the index. #text(fill: green)[Fix:] the index is always rebuildable from the primary store, and
  the rebuild is rehearsed. If reindexing takes 20 hours and nobody has tried it, your RTO is
  unknown.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Design typeahead for 300k QPS at p99 < 30 ms.]
  #linebreak()
  Precompute top-k completions per prefix offline from query logs, store them in replicated
  Redis, serve by exact key lookup, refresh the ranking on a schedule.
  #note[Testing: do you avoid querying the search engine per keystroke? Recognising this as a
  cache problem rather than a search problem is the whole answer.]

  #text(fill: green, weight: "bold")[Q: Why is `LIKE '%term%'` unusable?]
  #linebreak()
  A leading wildcard makes the index inapplicable, so it scans every row and matches substrings
  rather than tokens. #note[Testing: understanding of why an inverted index exists at all.]

  #text(fill: green, weight: "bold")[Q: How do you paginate 1M results?]
  #linebreak()
  Cursor-based `search_after` on a stable sort key. Offsets force every shard to materialise the
  whole prefix. #note[Testing: whether you know deep pagination is an availability risk, not a
  performance nuisance.]
]
#v(2mm)

#anti("using the search index as the primary datastore")[
  Search is fast and flexible, so a team writes orders directly to Elasticsearch and stops
  writing them anywhere else. Then: a mapping change requires a reindex of data that
  #text(fill: red, weight: "bold")[exists nowhere else]; there are no transactions, so partial
  writes are permanent; refresh is near-real-time, so a read right after a write may miss it; and
  a cluster loss is #underline(stroke: 1pt + red)[data loss] rather than a rebuild.
  #text(fill: green)[Fix:] the system of record is a database; the index is a
  #underline(stroke: 1pt + green)[derived, disposable projection] kept in sync by CDC (M9) and
  rebuildable on demand.
]
