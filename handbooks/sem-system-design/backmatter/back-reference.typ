#import "/shared/lib/template.typ": *

#reg(1, none, "Glossary")
#anchor("glossary")
#fmhead("Glossary")

#columns(2, gutter: 6mm)[
  #glos("Amdahl's Law", "Speedup bound set by the serial fraction of a workload; ceiling is 1/s.")
  #glos("Anti-entropy", "Background process reconciling divergent replicas, e.g. Merkle-tree repair.")
  #glos("Backpressure", "Signalling upstream to slow down rather than silently queueing or dropping.")
  #glos("Bloom filter", "Probabilistic set membership; false positives possible, false negatives not.")
  #glos("Bulkhead", "Partitioned resource pools so one dependency cannot exhaust all capacity.")
  #glos("Burn rate", "Rate of error-budget consumption relative to even spend across the window.")
  #glos("Causal consistency", "Causally-related operations are ordered; concurrent ones may differ per replica.")
  #glos("CDC", "Change Data Capture — streaming a database's commit log as events.")
  #glos("Compaction", "Merging LSM SSTables to drop overwritten rows and tombstones.")
  #glos("Coordinated omission", "Load-test artefact where a stalled generator fails to issue the requests that would have been slow.")
  #glos("CRDT", "Conflict-free Replicated Data Type; merge is commutative, associative, idempotent.")
  #glos("Error budget", "Allowed failure volume implied by an SLO: (1 − SLO) × total.")
  #glos("Fencing token", "Monotonic number issued with a lock and enforced at the resource, defeating stale holders.")
  #glos("Golden Signals", "Latency, traffic, errors, saturation.")
  #glos("Hedged request", "Duplicate request issued after p95 to cut tail latency; idempotent reads only.")
  #glos("Idempotency key", "Client-supplied identifier letting a server deduplicate retried writes.")
  #glos("ISR", "In-Sync Replicas — Kafka replicas caught up enough to be eligible for leadership.")
  #glos("Linearizability", "Operations appear instantaneous and in real-time order; composable.")
  #glos("Little's Law", "L = λW. Concurrency equals arrival rate times residence time.")
  #glos("LSM-tree", "Log-Structured Merge tree: sequential writes, background compaction.")
  #glos("LWW", "Last-Write-Wins; simple, clock-dependent, silently discards concurrent writes.")
  #glos("MTBF / MTTR", "Mean time between failures / mean time to recover.")
  #glos("PACELC", "If Partition: A or C; Else: Latency or Consistency.")
  #glos("Quorum", "Minimum responders for an operation; majority is ⌊N/2⌋+1.")
  #glos("Raft", "Leader-based consensus designed for understandability (Ongaro & Ousterhout, 2014).")
  #glos("RPO / RTO", "Data loss tolerated / downtime tolerated.")
  #glos("Saga", "Long-running transaction as local steps plus compensating actions.")
  #glos("SLI / SLO / SLA", "Measurement / internal target / external contract with penalty.")
  #glos("SSTable", "Sorted String Table; immutable on-disk file in an LSM engine.")
  #glos("Tail amplification", "Fan-out turning a backend p99 into the user-visible median.")
  #glos("Tombstone", "Marker recording a deletion until compaction removes it.")
  #glos("Transactional outbox", "Event written in the same local transaction as the data, relayed separately.")
  #glos("Virtual node", "Multiple ring positions per physical node, evening load and spreading failure.")
  #glos("Write amplification", "Bytes physically written per logical byte.")
  #glos("XFetch", "Probabilistic early expiry that desynchronises cache refills.")
]
#pagebreak()

// ========================================================== BIBLIOGRAPHY
#chapterhead("Appendices & Reference", "Bibliography")
#reg(1, none, "Bibliography")
#anchor("biblio")
#fmhead("References & Bibliography")

#text(size: 9pt)[
  Canonical sources for the algorithms and results cited in this handbook. Where a claim in the
  text rests on a paper, that paper is here.
]
#v(3mm)

#text(font: headfont, size: 10pt, fill: blue)[Consensus and replication]
#v(1.5mm)
#ref("Ongaro, D. & Ousterhout, J.", "2014", "In Search of an Understandable Consensus Algorithm",
  "USENIX ATC. The Raft paper — read §5 for log replication and safety.")
#ref("Lamport, L.", "1998", "The Part-Time Parliament",
  "ACM TOCS. Paxos. See also Paxos Made Simple (2001).")
#ref("Lamport, L.", "1978", "Time, Clocks, and the Ordering of Events in a Distributed System",
  "CACM. Happens-before; the foundation of causal consistency.")
#ref("Lamport, L.", "1979", "How to Make a Multiprocessor Computer That Correctly Executes Multiprocess Programs",
  "IEEE Trans. Computers. The definition of sequential consistency.")
#ref("Herlihy, M. & Wing, J.", "1990", "Linearizability: A Correctness Condition for Concurrent Objects",
  "ACM TOPLAS.")
#ref("DeCandia, G. et al.", "2007", "Dynamo: Amazon's Highly Available Key-Value Store",
  "SOSP. Quorums, vector clocks, consistent hashing in production.")
#ref("Shapiro, M. et al.", "2011", "Conflict-Free Replicated Data Types",
  "SSS. The CRDT formalism.")
#v(3mm)

#text(font: headfont, size: 10pt, fill: orange)[Storage and data structures]
#v(1.5mm)
#ref("O'Neil, P. et al.", "1996", "The Log-Structured Merge-Tree (LSM-Tree)",
  "Acta Informatica. The origin of the write-optimised design.")
#ref("Karger, D. et al.", "1997", "Consistent Hashing and Random Trees",
  "STOC. Minimal key movement under node change.")
#ref("Chang, F. et al.", "2006", "Bigtable: A Distributed Storage System for Structured Data",
  "OSDI.")
#ref("Corbett, J. et al.", "2012", "Spanner: Google's Globally-Distributed Database",
  "OSDI. TrueTime and external consistency.")
#v(3mm)

#text(font: headfont, size: 10pt, fill: green)[Performance and reliability]
#v(1.5mm)
#ref("Dean, J. & Barroso, L.", "2013", "The Tail at Scale",
  "CACM. Hedged and tied requests; why p99 becomes the median under fan-out.")
#ref("Amdahl, G.", "1967", "Validity of the Single Processor Approach to Achieving Large-Scale Computing Capabilities",
  "AFIPS.")
#ref("Gustafson, J.", "1988", "Reevaluating Amdahl's Law", "CACM.")
#ref("Gunther, N.", "2007", "Guerrilla Capacity Planning",
  "Springer. The Universal Scalability Law.")
#ref("Tene, G.", "2013", "How NOT to Measure Latency",
  "Talk. Coordinated omission, and why most load tests lie.")
#ref("Brooker, M.", "2015", "Exponential Backoff and Jitter",
  "AWS Architecture Blog. Full jitter measured against alternatives.")
#v(3mm)

#text(font: headfont, size: 10pt, fill: purple)[Practice]
#v(1.5mm)
#ref("Beyer, B. et al.", "2016", "Site Reliability Engineering", "O'Reilly. Golden signals, error budgets.")
#ref("Beyer, B. et al.", "2018", "The Site Reliability Workbook", "O'Reilly. Multi-window burn-rate alerting.")
#ref("Kleppmann, M.", "2017", "Designing Data-Intensive Applications",
  "O'Reilly. The single best companion to this handbook.")
#ref("Forsgren, N., Humble, J. & Kim, G.", "2018", "Accelerate",
  "IT Revolution. The DORA metrics and their evidence base.")
#ref("Abadi, D.", "2012", "Consistency Tradeoffs in Modern Distributed Database System Design",
  "IEEE Computer. PACELC.")
#ref("Nygard, M.", "2018", "Release It!", "2nd ed. Pragmatic. Circuit breakers, bulkheads, stability patterns.")
#pagebreak()

// ========================================================== INDEX
#chapterhead("Appendices & Reference", "Index")
#reg(1, none, "Index")
#chapterhead("Appendices & Reference", "Index")
#anchor("index")
#fmhead("Index")

#text(size: 8.6pt, fill: luma(100))[
  Page numbers are live links in the PDF. Entries are generated from the point
  each term is defined, so they cannot drift out of date.
]
#v(3mm)

#columns(3, gutter: 5mm)[
  #indexbody()
]
#pagebreak()

#reg(1, none, "Colophon")
#anchor("colophon")
#fmhead("Colophon")

#text(size: 9pt)[
  #text(font: headfont, size: 10pt, fill: blue)[Typesetting]
  #linebreak()
  Composed in #text(weight: "bold")[Typst 0.15.1] with the #text(weight: "bold")[CeTZ 0.4.2]
  vector graphics package. Body text is set in Chalkboard SE; headings in Marker Felt. Page size
  is A4 (210 × 297 mm) with 13–16 mm margins.

  #v(2mm)
  #text(font: headfont, size: 10pt, fill: blue)[On the diagrams]
  #linebreak()
  Every figure is drawn as vector geometry with named anchors, so arrows attach to component
  edges by construction rather than by hand-placed coordinates. An earlier draft positioned
  boxes manually; the result was arrows that terminated beside their targets instead of at them,
  which is why none of it survived into this edition.
  #note[The colour scheme is semantic, not decorative — green for the healthy path, red for
  failure, orange for arithmetic, purple for definitions and caveats, blue for structure. Line
  style carries the same information independently (solid, dashed, dotted), so the figures remain
  legible printed in greyscale.]

  #v(2mm)
  #text(font: headfont, size: 10pt, fill: blue)[Build]
  #linebreak()
  Sources are plain text under version control. `./build.sh` compiles each chapter and assembles
  the volume. Page counts, A4 geometry and diagram integrity are asserted programmatically on
  every build, after an earlier toolchain silently dropped five pages from a merged PDF and
  reported success.

  #v(2mm)
  #text(font: headfont, size: 10pt, fill: blue)[Edition]
  #linebreak()
  Edition 1.0, October 2026. Part 1 complete; Part 2 in progress.

  #v(4mm)
  #line(length: 50mm, stroke: 0.8pt + luma(170))
  #v(2mm)
  #text(size: 8.3pt, fill: luma(110))[
    Set, built and proofread with the assistance of Claude Code.
    Every figure in this volume was rendered and visually inspected before it was kept.
  ]
]
