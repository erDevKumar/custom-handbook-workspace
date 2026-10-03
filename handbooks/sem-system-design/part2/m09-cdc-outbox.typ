#import "/shared/lib/template.typ": *
#reg(1, "M9", "CDC & the Transactional Outbox")
#chapterhead("Part 2 · Modules", "M9 · CDC & Transactional Outbox")
#ix("Change Data Capture")
#ix("Transactional outbox")
#ix("Dual write")

#h1("M9 · CDC & the Transactional Outbox", c: green)

#text[
  The dual write is the most common data-integrity bug in service architectures: write to the
  database, then publish an event. Two systems, #underline(stroke: 1pt + red)[no transaction
  spanning them]. Crash in between and the two disagree permanently. Both techniques here exist
  to make that impossible rather than merely unlikely.
]
#v(2mm)

#h2("1 · Why the dual write cannot be fixed with care", c: red)

#pfig("Fig M9.1 · outbox + CDC — one commit, so the row and the event cannot disagree")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.3, 20.9, 2.6, "outbox table in the same database as the business rows; a replication slot with monitored lag; idempotent consumers")

  ppill(1.65, 0, "in", "place order", w: 3.0)
  pstep(5.7, 0, "tx", "ONE transaction", "row + outbox · 4ms", st-man, n: 1, actor: "service", w: 4.2)
  pdec(10.5, 0, "c", "commit\nsucceeded?", w: 1.6)
  pstep(14.9, 0, "rel", "tail the WAL", "Debezium · sub-100ms", st-auto, n: 2, actor: "CDC relay", w: 4.2)
  ppill(19.25, 0, "out", "Kafka topic", w: 3.0)

  pstep(10.5, -4.0, "none", "nothing happened", "no row and no event", st-dec, n: 3, actor: "service", w: 4.6)

  line("in.east", "tx.west", mark: (end: ">"), stroke: hot)
  line("tx.east", "c.west", mark: (end: ">"), stroke: hot)
  line("c.east", "rel.west", mark: (end: ">"), stroke: hot)
  plabel(12.55, 0, "yes", c: green, dy: 0.62)
  line("rel.east", "out.west", mark: (end: ">"), stroke: async)
  line("c.south", "none.north", mark: (end: ">"), stroke: except)
  plabel(11.9, -2.1, "no", c: red, dy: 0)
  content((4.6, -4.2), dlbl("a dual write opens a crash\nwindow here: the row commits,\nthe event is never sent, and the\ntwo disagree permanently", sz: 6.5pt, c: red))
  content((16.9, -4.2), dlbl("an unconsumed slot pins the\nWAL and the disk fills — alert\non slot lag, not on consumer\nlag alone", sz: 6.5pt, c: red))
}))
#pcards(
  [Outbox rows written inside the business transaction; the replication slot alerted on lag; keyed, idempotent consumers],
  [In: a business command · Out: a domain event, at-least-once, in commit order. Either both land or neither does],
  [Postgres logical replication · Debezium · outbox table · Kafka · a slot-lag alert],
)
#v(2mm)

#text(size: 9pt)[
  #text(fill: green, weight: "bold")[The transactional outbox.] Write the event as a row in an
  `outbox` table inside the #underline(stroke: 1pt + green)[same local transaction] as the
  business data. One commit; either both land or neither does. A separate relay then reads the
  outbox and publishes. Delivery becomes at-least-once rather than maybe-once, which is a
  problem you can solve with idempotency.

  #text(fill: purple, weight: "bold")[Change Data Capture.] Rather than polling the outbox, tail
  the database's own write-ahead log --- Postgres logical replication, MySQL binlog --- with
  Debezium or equivalent. The WAL is already the authoritative ordered record of every committed
  change, so you get ordering and completeness for free, with no polling load on the primary.
]
#v(2mm)

#h2("2 · Outbox polling vs. log tailing", c: purple)

#table(
  columns: (auto, 1fr, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#f5eefa") } else { none },
  text(font: headfont, size: 8.5pt, fill: purple)[Aspect],
  text(font: headfont, size: 8.5pt, fill: purple)[Outbox + polling relay],
  text(font: headfont, size: 8.5pt, fill: purple)[CDC / log tailing],

  text(size: 8.3pt)[Setup],
  text(size: 8pt, fill: green)[A table and a loop. Works anywhere],
  text(size: 8pt, fill: orange)[Connector, replication slot, ops burden],

  text(size: 8.3pt)[Latency],
  text(size: 8pt, fill: orange)[Poll interval — typically 100ms–1s],
  text(size: 8pt, fill: green)[Near-real-time, sub-100ms],

  text(size: 8.3pt)[Load on primary],
  text(size: 8pt, fill: orange)[Constant polling queries and deletes],
  text(size: 8pt, fill: green)[Reads the WAL, not the tables],

  text(size: 8.3pt)[Payload control],
  text(size: 8pt, fill: green)[You write the event — a real domain event],
  text(size: 8pt, fill: red)[Row deltas. Leaks your schema downstream],

  text(size: 8.3pt)[Schema coupling],
  text(size: 8pt, fill: green)[Decoupled by construction],
  text(size: 8pt, fill: red)[A column rename becomes a consumer's problem],

  text(size: 8.3pt)[Failure mode],
  text(size: 8pt)[Relay lag grows the outbox table],
  text(size: 8pt, fill: red)[Unconsumed slot pins WAL — #emph[disk fills]],
)
#v(2mm)

#key[
  Prefer the #text(fill: green, weight: "bold")[outbox] when the consumer wants a domain event
  ("OrderPlaced"), and #text(fill: purple, weight: "bold")[CDC] when the consumer wants the
  data itself (search index, warehouse, cache). Publishing raw row changes as your public event
  contract couples every downstream team to your
  #underline(stroke: 1pt + red)[internal schema] — and you will not be able to refactor it again.
]
#v(2mm)

#h2("3 · Capacity arithmetic", c: orange)

#formula("Relay throughput and outbox growth")[
  #text(size: 8.6pt)[
    10,000 orders/s, each producing 3 events #sym.arrow.r
    #text(fill: orange, weight: "bold")[30,000 events/s] through the relay.
    #linebreak()
    Poll every 200ms in batches of 1,000 #sym.arrow.r 5,000 events/s per relay instance
    #sym.arrow.r need #text(fill: orange, weight: "bold")[6 relay workers], partitioned by a
    hash of the aggregate id so ordering per entity is preserved.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Outbox table growth if the relay stalls:] 30,000/s × 500 B =
    #text(fill: red, weight: "bold")[15 MB/s] = 54 GB/hour. A relay down overnight is
    #text(fill: red, weight: "bold")[~650 GB] of outbox rows, and the delete sweep afterwards is
    itself a load event.
    #note[Alert on outbox depth and oldest-unpublished-age, not just on relay liveness. A relay
    that is running but falling behind looks healthy to a process check.]
    #linebreak() #v(1mm)
    #text(weight: "bold")[WAL retention for CDC:] a replication slot pins WAL until consumed. At
    15 MB/s, a consumer offline for 6 hours pins #text(fill: red, weight: "bold")[324 GB] on the
    primary. #underline(stroke: 1pt + red)[This fills the disk and takes the database down] —
    always set `max_slot_wal_keep_size`.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Duplicate publication.] The relay publishes, then crashes
  before marking the row sent, so it republishes on restart. This is unavoidable --- publishing
  and marking are themselves two systems. #text(fill: green)[Fix:] accept at-least-once and give
  every event a stable id so consumers deduplicate. Chasing exactly-once here recreates the
  original bug one level up.

  #text(fill: red, weight: "bold")[Ordering lost by parallelism.] Six relay workers publish
  concurrently, so `OrderCancelled` can overtake `OrderPlaced`.
  #text(fill: green)[Fix:] partition by aggregate id end to end --- same key, same Kafka
  partition, same consumer. Order within an entity is what matters; global order is almost never
  required and is expensive to provide.

  #text(fill: red, weight: "bold")[Replication slot abandoned.] A CDC connector is removed
  without dropping its slot. Nothing breaks for days, then the primary's disk fills and the
  database stops accepting writes. #text(fill: green)[Fix:] monitor slot lag as a first-class
  alert; treat an orphaned slot as an incident.

  #text(fill: red, weight: "bold")[Schema change breaks consumers.] A column rename flows
  straight through CDC into every downstream consumer.
  #text(fill: green)[Fix:] a transformation layer that maps row deltas to a stable published
  contract --- or use the outbox, where that stability is the default.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: How do you publish an event and write to the DB
  atomically?]
  #linebreak()
  You do not --- you remove the need. Write the event into an outbox table in the same
  transaction, and relay it separately. #note[Testing: do you recognise the dual write as
  structurally unsolvable rather than a bug to be coded around? Candidates often answer "use a
  distributed transaction", which trades one problem for a worse one (see M4).]

  #text(fill: green, weight: "bold")[Q: Outbox or CDC?]
  #linebreak()
  Outbox for domain events you control; CDC for replicating data to search, analytics or caches.
  #note[Testing: whether you see the schema-coupling cost of CDC. "Publish the binlog to Kafka"
  sounds elegant until a rename breaks four teams.]

  #text(fill: green, weight: "bold")[Q: Doesn't this give duplicates?]
  #linebreak()
  Yes, by design. At-least-once plus consumer idempotency is the correct trade; a stable event
  id makes deduplication trivial. #note[Testing: comfort with at-least-once as a
  #underline(stroke: 1pt + green)[deliberate choice] rather than a weakness to apologise for.]
]
#v(2mm)

#anti("the dual write")[
  `db.save(order); kafka.publish(event);` --- wrapped in `try/catch` for safety, which does
  nothing, because the process can die #underline(stroke: 1pt + red)[between the two lines].
  Rolling back the DB write in the catch block does not help either: the publish may have
  succeeded and the rollback may itself fail. The result is silent, permanent divergence
  discovered weeks later by a reconciliation job --- or a customer.
  #text(fill: green)[Fix:] outbox or CDC. There is no careful-coding version of this that works.
]
