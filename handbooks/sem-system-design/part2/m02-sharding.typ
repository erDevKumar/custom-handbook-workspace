#import "/shared/lib/template.typ": *
// CHAPTER-HEAD: Part 2 · Modules | M2 · Sharding & Consistent Hashing
#reg(1, "M2", "Sharding & Consistent Hashing")
#chapterhead("Part 2 · Modules", "M2 · Sharding & Consistent Hashing")
#ix("Consistent hashing")
#ix("Virtual node")
#ix("Shard key")
#ix("Hot key")

#h1("M2 · Sharding & Consistent Hashing", c: blue)

#text[
  Sharding splits one logical dataset across many machines so that no single node holds all the
  data or serves all the traffic. The hard part was never the split --- it is
  #underline(stroke: 1pt + red)[changing your mind] about the split once there is live data on it.
]
#v(2mm)

#h2("1 · Core mechanics", c: blue)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Modulo hashing] (`shard = hash(key) % N`) is the obvious
  approach and the wrong one. Adding one node changes N, so
  #text(fill: red, weight: "bold")[nearly every key] maps somewhere new --- you must move
  almost the entire dataset to add a single machine.

  #text(fill: green, weight: "bold")[Consistent hashing] (Karger et al., 1997) maps both keys and
  nodes onto the same circular keyspace. A key belongs to the first node clockwise from it.
  Adding or removing a node only disturbs the arc between it and its neighbour, so on average
  only #text(fill: green, weight: "bold")[K/N] keys move.

  #text(fill: purple, weight: "bold")[Virtual nodes] fix the flaw in plain consistent hashing: a
  few random points on a circle produce very uneven arcs. Each physical node is instead placed at
  #text(fill: purple)[100--256] positions. Load evens out, and when a node dies its share is
  redistributed across #underline(stroke: 1pt + green)[all] remaining nodes rather than dumped
  entirely on its clockwise neighbour.
]
#v(2mm)

#align(center, cetz.canvas(length: 0.84cm, {
  import cetz.draw: *

  // ---- modulo: everything moves ----
  content((4.2, 4.6), dlbl("MODULO  hash(k) % N", sz: 8pt, c: red))
  rnode(1.6, 3.2, "a1", "N=4", "4 nodes", blue, w: 2.2, h: 0.8)
  rnode(6.6, 3.2, "a2", "N=5", "add 1 node", red, w: 2.6, h: 0.8)
  line("a1.east", "a2.west", mark: (end: ">"), stroke: miss)
  content((4.1, 2.35), dlbl("~80% of ALL keys relocate", sz: 7pt, c: red))
  content((4.1, 1.7), dlbl("hours of rebalancing, cold caches,", sz: 6.4pt, c: red))
  content((4.1, 1.15), dlbl("replication storm", sz: 6.4pt, c: red))

  // ---- consistent hashing ring ----
  content((13.4, 4.6), dlbl("CONSISTENT HASHING + vnodes", sz: 8pt, c: green))
  circle((13.4, 1.6), radius: 2.5, stroke: 1.3pt + luma(150))
  content((13.4, 1.6), dlbl("hash ring\n0 .. 2^32", sz: 6.5pt, c: luma(120)))
  // node positions around the ring
  for (ang, lbl, col) in ((40, "A", green), (105, "B", blue), (170, "C", orange),
                           (235, "A", green), (300, "B", blue), (350, "C", orange)) {
    let rx = 13.4 + 2.5 * calc.cos(ang * 1deg)
    let ry = 1.6 + 2.5 * calc.sin(ang * 1deg)
    circle((rx, ry), radius: 0.3, stroke: 1.2pt + col, fill: white)
    content((rx, ry), dlbl(lbl, sz: 6pt, c: col))
  }
  content((13.4, -1.5), dlbl("each node sits at 100-256 vnodes", sz: 6.6pt, c: purple))
  content((13.4, -2.1), dlbl("add a node -> only K/N keys move", sz: 6.6pt, c: green))
  bracket(10.3, 16.5, -2.7, "key -> first node CLOCKWISE", green)
}))
#v(2mm)

#h2("2 · Choosing a shard key — the decision you cannot undo", c: purple)

#table(
  columns: (auto, 1fr, auto, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#f5eefa") } else { none },
  text(font: headfont, size: 8.5pt, fill: purple)[Key],
  text(font: headfont, size: 8.5pt, fill: purple)[Behaviour],
  text(font: headfont, size: 8.5pt, fill: purple)[Hotspot?],
  text(font: headfont, size: 8.5pt, fill: purple)[Use when],

  text(size: 8.3pt)[`user_id` hash],
  text(size: 8pt)[Even spread; all of one user's data co-located],
  text(size: 8pt, fill: green)[rare],
  text(size: 8pt)[per-user access (most OLTP)],

  text(size: 8.3pt)[`timestamp`],
  text(size: 8pt, fill: red)[All writes land on the newest shard],
  text(size: 8pt, fill: red)[always],
  text(size: 8pt, fill: red)[never, for writes],

  text(size: 8.3pt)[`tenant_id`],
  text(size: 8pt)[Clean isolation; skewed by tenant size],
  text(size: 8pt, fill: orange)[big tenants],
  text(size: 8pt)[B2B, with overflow plan],

  text(size: 8.3pt)[Composite],
  text(size: 8pt)[`tenant#user` spreads a whale across shards],
  text(size: 8pt, fill: green)[mitigated],
  text(size: 8pt)[known skew],

  text(size: 8.3pt)[Range],
  text(size: 8pt)[Scans are cheap; splits need rebalancing],
  text(size: 8pt, fill: orange)[sequential ins.],
  text(size: 8pt)[range queries dominate],
)
#v(2mm)

#key[
  The shard key is chosen once and is #text(fill: red, weight: "bold")[the most expensive
  decision to reverse] in the system --- changing it means rewriting every row and every query.
  Pick it from the #underline(stroke: 1pt + green)[dominant access pattern], not from what looks
  tidy in the schema.
]
#v(2mm)

#h2("3 · Capacity arithmetic", c: orange)

#formula("How many shards, and how much moves")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[Sizing:] 4 TB dataset, 2 TB usable per node (50% headroom for
    compaction and growth) #sym.arrow.r minimum #text(fill: orange, weight: "bold")[2 shards];
    provision #text(fill: green, weight: "bold")[4] so you can double load without resharding.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Data moved, modulo, N: 4 #sym.arrow.r 5:] keys keep their shard only
    when `h%4 == h%5`, roughly 1 in 5 #sym.arrow.r
    #text(fill: red, weight: "bold")[~80% of 4 TB = 3.2 TB] relocates.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Consistent hashing, 4 #sym.arrow.r 5:] K/N = 1/5 #sym.arrow.r
    #text(fill: green, weight: "bold")[~800 GB] relocates — a 4#sym.times reduction.
    #linebreak()
    At 100 MB/s of transfer budget: 3.2 TB = #text(fill: red)[~9 hours];
    800 GB = #text(fill: green)[~2.2 hours].
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Hot key.] One key --- a celebrity account, a viral product ---
  receives a disproportionate share of traffic. Consistent hashing does not help: the key maps to
  exactly one shard by definition. #text(fill: green)[Fix:] salt the key into N sub-keys
  (`celebrity#0..celebrity#9`) and scatter-gather on read, or promote that single key into a
  dedicated cache tier.

  #text(fill: red, weight: "bold")[Hot shard.] A whole shard is overloaded because its key range
  is unlucky or a tenant grew. #text(fill: green)[Fix:] split the range, raise vnode count, or
  move specific vnodes to quieter nodes.

  #text(fill: red, weight: "bold")[Resharding under load.] Moving data while serving traffic
  means the same key may be readable in two places. #text(fill: green)[Fix:] dual-write +
  backfill + verify + cut over, with a version or routing epoch so readers know which copy is
  authoritative. Never a one-shot migration.

  #text(fill: red, weight: "bold")[Cross-shard query.] Any query that does not include the shard
  key must fan out to #underline(stroke: 1pt + red)[every] shard, and its latency becomes the
  slowest shard's p99 (see Part 1, topic 4 --- tail amplification).
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Why not just `hash(key) % N`?]
  #linebreak()
  Because N appears in the formula, so changing N remaps nearly everything.
  #note[Testing: can you quantify it? "~80% moves" beats "it rebalances a lot". Interviewers are
  listening for whether you have actually done a migration.]

  #text(fill: green, weight: "bold")[Q: What do virtual nodes actually buy?]
  #linebreak()
  Even load distribution, and failure spreading --- a dead node's share goes to all survivors
  rather than only its clockwise neighbour. #note[Testing: do you know the failure-distribution
  benefit, not just the load-evenness one? Most candidates give half the answer.]

  #text(fill: green, weight: "bold")[Q: How do you handle a celebrity hot key?]
  #linebreak()
  Sharding cannot fix it --- one key is one shard. Salt it, cache it, or replicate that key
  specifically. #note[Testing: whether you recognise when the chosen technique is simply the
  wrong tool, instead of trying to tune your way out.]
]
#v(2mm)

#anti("sharding before you need to")[
  A team shards at 50 GB "to be ready". They inherit cross-shard joins, distributed transactions,
  fan-out queries and a rebalancing runbook --- to manage a dataset that
  #text(fill: green)[fits in RAM on one machine]. Every feature now costs more to build and every
  query more to reason about. #text(fill: green)[Fix:] scale vertically, add read replicas, and
  shard when a #underline(stroke: 1pt + green)[measured] limit is approaching — but design the
  shard key early, so the eventual migration is a move rather than a rewrite.
]
