#import "/shared/lib/template.typ": *
// CHAPTER-HEAD: Part 2 · Modules | M1 · Distributed Storage Engines
#reg(1, "M1", "Distributed Storage Engines")
#chapterhead("Part 2 · Modules", "M1 · Distributed Storage Engines")
#ix("LSM-tree")
#ix("B-tree")
#ix("Write amplification")
#ix("Compaction")
#ix("Bloom filter")
#ix("Tombstone")

#h1("M1 · Distributed Storage Engines", c: orange)

#text[
  Every database is a bet about your workload, made at the storage-engine layer.
  #text(fill: blue, weight: "bold")[B-trees] optimise for reads and in-place updates;
  #text(fill: green, weight: "bold")[LSM-trees] optimise for writes by never updating in place at
  all. Choosing wrongly is not a tuning problem --- it is a rewrite.
]
#v(2mm)

#h2("1 · Core mechanics", c: blue)

#text(size: 9pt)[
  #text(fill: blue, weight: "bold")[B-tree.] A balanced tree of fixed-size pages (typically 4--16
  KB) held in place on disk. A write finds the leaf page, mutates it, and writes it
  #underline(stroke: 1pt + blue)[back where it was]. Lookups are O(log n) with a small, bounded
  number of page reads --- usually 3--4 for billions of rows, because the upper levels stay
  cached. The cost is that a 100-byte update rewrites an entire page, and random page writes are
  the worst case for any disk.

  #text(fill: green, weight: "bold")[LSM-tree] (O'Neil et al., 1996). Writes go to an in-memory
  #text(fill: purple)[memtable] (a sorted structure) plus a sequential
  #text(fill: purple)[write-ahead log] for durability, and return immediately. When the memtable
  fills, it is flushed as an immutable, sorted #text(fill: orange)[SSTable] file. Files
  accumulate, so a background #text(fill: orange)[compaction] process merges them, discarding
  overwritten and deleted keys. Writes are therefore always
  #underline(stroke: 1pt + green)[sequential]; reads may have to check several files.
]
#v(2mm)

#pfig("Fig M1.1 · LSM write path — every write is sequential, the cost is deferred to compaction")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.3, 20.9, 2.6, "durable device with fsync; memtable sized to fit RAM; compaction budget reserved on the same disk")

  ppill(1.55, 0, "in", "put(k, v)", w: 2.8)
  pstep(5.5, 0, "wal", "append WAL", "seq fsync · 0.1ms", st-auto, n: 1, actor: "engine", w: 3.8)
  pstep(10.6, 0, "mem", "memtable", "skiplist 64MB · 0.001ms", st-auto, n: 2, actor: "engine", w: 4.0)
  pdec(15.3, 0, "full", "memtable\nfull?", w: 1.6)
  ppill(19.25, 0, "ack", "ack client", w: 3.0)

  pstep(15.3, -4.0, "l0", "flush L0 SSTable", "immutable, sorted · 1 file", st-integ, n: 3, actor: "flusher", w: 4.4)
  pstep(5.5, -4.0, "cmp", "compact L1..Ln", "leveled · 10x write amp", st-integ, n: 4, actor: "compactor", w: 4.4)

  line("in.east", "wal.west", mark: (end: ">"), stroke: hot)
  line("wal.east", "mem.west", mark: (end: ">"), stroke: hot)
  line("mem.east", "full.west", mark: (end: ">"), stroke: hot)
  line("full.east", "ack.west", mark: (end: ">"), stroke: hot)
  plabel(17.55, 0, "no", c: green, dy: 0.62)
  line("full.south", "l0.north", mark: (end: ">"), stroke: async)
  plabel(17.1, -2.1, "yes", c: purple, dy: 0)
  line("l0.west", "cmp.east", mark: (end: ">"), stroke: async)
  plabel(10.3, -4.0, "merge, drop tombstones", c: purple, dy: 0.34)

  content((10.3, -6.0), dlbl("compaction is the deferred cost of a sequential write: it reclaims space and lowers read amplification, and it competes for the same disk", sz: 6.5pt, c: purple))
}))
#pcards(
  [WAL on a device whose `fsync` is honoured; RAM for the memtable; spare IOPS for compaction],
  [In: `put(k,v)` · Out: ack after WAL fsync, not after flush. A read must check memtable + N SSTables],
  [RocksDB / LevelDB · WAL · skiplist memtable · leveled compaction · Bloom filter per SSTable],
)
#v(2mm)

#h2("2 · Trade-off matrix", c: purple)

#table(
  columns: (auto, 1fr, 1fr, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#f5eefa") } else { none },
  text(font: headfont, size: 8.5pt, fill: purple)[Dimension],
  text(font: headfont, size: 8.5pt, fill: purple)[B-tree],
  text(font: headfont, size: 8.5pt, fill: purple)[LSM-tree],
  text(font: headfont, size: 8.5pt, fill: purple)[Pick by],

  text(size: 8.3pt)[Write amp.],
  text(size: 8pt, fill: red)[High — page per update],
  text(size: 8pt, fill: green)[Low at ingest, paid later in compaction],
  text(size: 8pt)[write:read ratio],

  text(size: 8.3pt)[Read amp.],
  text(size: 8pt, fill: green)[Low — 3-4 page reads],
  text(size: 8pt, fill: red)[Checks memtable + N SSTables],
  text(size: 8pt)[point-read latency],

  text(size: 8.3pt)[Space amp.],
  text(size: 8pt, fill: orange)[Fragmentation, ~30% slack],
  text(size: 8pt, fill: green)[Compact; obsolete rows removed],
  text(size: 8pt)[\$/TB],

  text(size: 8.3pt)[Range scans],
  text(size: 8pt, fill: green)[Excellent — leaves linked],
  text(size: 8pt, fill: orange)[Merge across levels],
  text(size: 8pt)[analytics?],

  text(size: 8.3pt)[Latency shape],
  text(size: 8pt, fill: green)[Predictable],
  text(size: 8pt, fill: red)[p99 spikes during compaction],
  text(size: 8pt)[tail SLO],

  text(size: 8.3pt)[Used by],
  text(size: 8pt)[Postgres, MySQL/InnoDB],
  text(size: 8pt)[Cassandra, RocksDB, ScyllaDB],
  text(size: 8pt)[--],
)
#v(2mm)

#key[
  The three amplifications --- #text(fill: red, weight: "bold")[write], #text(fill: red,
  weight: "bold")[read], #text(fill: red, weight: "bold")[space] --- form a
  #underline(stroke: 1pt + green)[pick two] triangle. Compaction tuning does not escape it, it
  only moves you around it. Levelled compaction buys read and space amplification by spending
  write; size-tiered does the reverse.
]
#v(2mm)

#h2("3 · Capacity arithmetic", c: orange)

#formula("Write amplification, worked")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[B-tree:] 100-byte row update, 8 KB page
    #sym.arrow.r 8,192 / 100 = #text(fill: red, weight: "bold")[~82#sym.times] amplification
    (plus the WAL write).
    #linebreak() #v(1mm)
    #text(weight: "bold")[LSM levelled, 7 levels, fan-out 10:] each row is rewritten roughly once
    per level #sym.arrow.r #text(fill: orange, weight: "bold")[~10--30#sym.times] total, but
    every write is #underline(stroke: 1pt + green)[sequential].
    #linebreak() #v(1mm)
    #text(weight: "bold")[Why it matters:] 10,000 writes/s #sym.times 100 B = 1 MB/s logical.
    At 82#sym.times that is #text(fill: red, weight: "bold")[82 MB/s of random I/O] — beyond a
    single disk's random budget. At 20#sym.times sequential it is 20 MB/s sequential, which is
    trivial. #text(fill: purple)[This is the entire reason LSM exists.]
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Compaction debt.] Ingest outruns compaction, so SSTable count
  climbs. Every read now checks more files and read latency degrades
  #underline(stroke: 1pt + red)[without any change in query load]. Left alone it ends in write
  stalls when the engine refuses new writes to let compaction catch up.
  #text(fill: green)[Watch:] pending compaction bytes, L0 file count.

  #text(fill: red, weight: "bold")[Tombstone accumulation.] A delete writes a
  #text(fill: purple)[tombstone], not a removal. Scanning a range that once held a million
  deleted rows reads a million tombstones. Cassandra operators meet this as a query that got
  slower #text(fill: red)[after] a cleanup.
  #text(fill: green)[Fix:] `gc_grace_seconds` tuning, avoid queue-like tables in an LSM store.

  #text(fill: red, weight: "bold")[WAL unflushed on crash.] `fsync` is the durability boundary.
  Group commit batches fsyncs for throughput, so a crash loses the last batch. Know your
  engine's default --- several trade a few ms of durability for a large throughput win, which is
  correct for a session store and wrong for a ledger.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Why is Cassandra fast at writes?]
  #linebreak()
  Writes are an append to a WAL plus an in-memory insert --- no disk seek, no read-before-write.
  #note[Testing: do you know the cost is deferred, not removed? Compaction pays it back later,
  and that is where the p99 spikes come from. The weak answer stops at "it's distributed".]

  #text(fill: green, weight: "bold")[Q: Why not use LSM for everything?]
  #linebreak()
  Read amplification and unpredictable tail latency. A point read may touch several SSTables;
  bloom filters help but do not eliminate it. #note[Testing: whether you can argue
  #underline(stroke: 1pt + green)[against] the fashionable choice. Range-scan-heavy and
  latency-SLO-strict workloads still favour B-trees.]

  #text(fill: green, weight: "bold")[Q: What does a bloom filter do here?]
  #linebreak()
  A probabilistic set membership test per SSTable: "definitely not present" or "maybe present".
  It skips most files on a miss. #note[Testing: do you understand false positives are allowed and
  false negatives are not --- that asymmetry is what makes it safe to use as a skip filter.]
]
#v(2mm)

#anti("using an LSM store as a work queue")[
  A team stores jobs in Cassandra and deletes each row when processed. Every delete leaves a
  #text(fill: red)[tombstone], and the "fetch next N pending jobs" query scans straight through
  them. Throughput degrades daily and the fix looks like it should be adding capacity --- it is
  not. The access pattern (#text(fill: red)[high-churn, delete-heavy, range-scanned]) is the
  precise worst case for the engine. #text(fill: green)[Fix:] use a real queue (SQS, Kafka,
  Redis streams), or a B-tree store with partial indexes.
]
