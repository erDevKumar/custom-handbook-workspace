#import "/shared/lib/template.typ": *
// CHAPTER-HEAD: Part 1 · Core Architectural Foundations | 3 · The Consistency Spectrum
#reg(1, "3", "The Consistency Spectrum")
#chapterhead("Part 1 · Core Architectural Foundations", "3 · The Consistency Spectrum")
#ix("Linearizability")
#ix("Causal consistency")
#ix("Eventual consistency")
#ix("Read-your-writes")
#ix("Monotonic reads")
#ix("PACELC")

#h1("3. The Consistency Spectrum", c: purple)

#text[
  Consistency models are #text(fill: purple, weight: "bold")[contracts about what a read is
  allowed to return]. They are not a quality ladder where stronger is better --- stronger models
  cost coordination, and coordination costs latency and availability. The job is to pick the
  weakest model that still makes the product correct, then say so out loud in the design doc.
]
#v(2.5mm)

// ---------------------------------------------------------------- 3.1 --------
#h2("3.1  The ladder, strongest first", c: purple)

#pfig("Fig 3.1 · the ladder: each rung down trades a guarantee for coordination you stop paying")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.6, 20.6, 4.9, "the invariants have been enumerated first — which operations must never be wrong, and which may merely be late")

  ppill(2.6, 3.2, "need", "a read arrives", c: purple, w: 3.4)
  pdec(7.2, 3.2, "d1", "real-time order?", w: 2.4)
  pstep(16.0, 3.2, "lin", "LINEARIZABLE", "Spanner · etcd · single-node RDBMS", st-dec,
    n: 1, actor: "one global timeline", w: 7.6)
  line("need.east", "d1.west", mark: (end: ">"), stroke: hot)
  line("d1.east", "lin.west", mark: (end: ">"), stroke: miss)
  plabel(10.9, 3.2, "must have it", c: red)

  pdec(7.2, 0.9, "d2", "one agreed order?", w: 2.4)
  pstep(16.0, 0.9, "seq", "SEQUENTIAL", "ZooKeeper writes · RSM designs", st-integ,
    n: 2, actor: "agreed, not real-time", w: 7.6)
  line("d1.south", "d2.north", mark: (end: ">"), stroke: 1pt + luma(150))
  line("d2.east", "seq.west", mark: (end: ">"), stroke: 1.1pt + orange)
  plabel(10.9, 0.9, "this is enough", c: orange)

  pdec(7.2, -1.4, "d3", "cause → effect?", w: 2.4)
  pstep(16.0, -1.4, "cau", "CAUSAL", "COPS · Mongo causal sessions", st-start,
    n: 3, actor: "concurrent is free", w: 7.6)
  line("d2.south", "d3.north", mark: (end: ">"), stroke: 1pt + luma(150))
  line("d3.east", "cau.west", mark: (end: ">"), stroke: 1.1pt + blue)
  plabel(10.9, -1.4, "this is enough", c: blue)

  pstep(16.0, -3.7, "eve", "EVENTUAL", "Dynamo · Cassandra ONE · S3", st-man,
    n: 4, actor: "converges… when?", w: 7.6)
  line("d3.south", (7.2, -3.7), "eve.west", mark: (end: ">"), stroke: hot)
  plabel(9.9, -3.7, "nothing to protect", c: green)

  content((2.8, 2.0), dlbl("more coordination", sz: 6.5pt, c: red))
  content((2.8, 1.4), dlbl("more latency", sz: 6.5pt, c: red))
  content((2.8, -2.4), dlbl("more speed", sz: 6.5pt, c: green))
  content((2.8, -3.0), dlbl("more availability", sz: 6.5pt, c: green))
  line((5.0, 2.4), (5.0, -3.4), stroke: (paint: luma(150), dash: "dashed", thickness: 0.8pt), mark: (end: ">"))
  bracket(0.6, 19.8, -4.9, "pick the WEAKEST rung that still keeps the product correct — then write it in the design doc", purple)
}))
#pcards(
  [A named invariant per operation (never oversell, never double-charge) — not one global level for the whole system.],
  [In: one operation and what it must never get wrong. Out: the model to route it through, and the coordination bill.],
  [Spanner / etcd for the top rung · ZooKeeper · MongoDB causal sessions · Dynamo, Cassandra, S3 at the bottom.],
)
#v(1.5mm)

#text[
  #text(fill: red, weight: "bold")[Linearizable] (Herlihy & Wing, 1990). Every operation appears
  to take effect #underline(stroke: 1pt + red)[instantaneously] at some point between its
  invocation and its response, and that order matches real time. If a write completes at 10:00:00
  and your read starts at 10:00:01, you #text(fill: red)[must] see it. This is the model humans
  assume by default, and the only one that is safe for a balance check before a withdrawal.

  #text(fill: orange, weight: "bold")[Sequential] (Lamport, 1979). All nodes agree on
  #text(fill: orange)[one] interleaving of operations, and each process's own operations keep
  their program order --- but that global order need not match wall-clock time. A write that
  finished before your read began may legally be ordered after it.
  #note[The practical difference from linearizable: sequential is not composable. Two
  individually sequential subsystems glued together are not sequential as a whole. That is
  exactly why linearizability, which IS composable, is the one worth paying for at a boundary.]

  #text(fill: blue, weight: "bold")[Causal] (Lamport's happens-before, 1978). Only
  causally-related operations need a fixed order. If B was written after reading A, everyone sees
  A before B. Operations with no causal link are #text(fill: green)[concurrent] and may be seen
  in any order. This is the sweet spot for collaborative and social systems --- comments never
  appear before the post they reply to, but two unrelated posts can land in either order.

  #text(fill: green, weight: "bold")[Eventual.] If writes stop, replicas converge. It promises
  nothing about #text(fill: red)[when], and nothing about what you read in the meantime ---
  including reads that go #underline(stroke: 1pt + red)[backwards in time] when you hit a lagging
  replica.
]
#v(2mm)

#key[
  "Eventual consistency" is not a synonym for #text(fill: red, weight: "bold")[no consistency].
  It is a specific promise (convergence) with a missing parameter (when). Demand that parameter:
  #text(fill: purple)["eventual within 200ms at p99"] is an engineering requirement you can
  monitor and alert on. #text(fill: red)["eventual"] alone is a shrug.
]
#v(2.5mm)

// ---------------------------------------------------------------- 3.2 --------
#h2("3.2  Read anomalies these models permit", c: red)

#pfig("Fig 3.2 · the two anomalies that generate support tickets, and the cheap session-level fix")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  swimlane(-0.4, -2.6, 20.4, 2.6, "READ-YOUR-WRITES violated", red, rgb("#fdf0ee"))
  content((5.6, 2.25), dlbl("— \"my edit did not save\"", sz: 6.8pt, c: red))
  ppill(2.6, 0, "u1", "user edits profile", w: 4.4)
  pstep(9.8, 1.3, "pr", "primary", "x = 1 · committed", st-man, n: 1, actor: "the write lands here", w: 4.2, h: 1.1)
  pstep(9.8, -1.3, "rp", "replica", "x = 0 · still lagging", st-dec, n: 2, actor: "the read is routed here", w: 4.2, h: 1.1)
  line("u1.east", "pr.west", mark: (end: ">"), stroke: hot)
  plabel(6.1, 0.72, "write x=1", c: green)
  line("rp.west", "u1.east", mark: (end: ">"), stroke: miss)
  plabel(5.9, -0.72, "read x → 0 !", c: red, dy: -0.4)
  line("pr.south", "rp.north", mark: (end: ">"), stroke: async)
  plabel(10.5, 0, "lag", c: purple, dy: 0)
  pstep(17.2, 0, "fix1", "sticky reads", "pin the session for ~5s", st-auto,
    n: 3, actor: "the cheap fix", w: 5.0)
  line("rp.east", "fix1.west", mark: (end: ">"), stroke: lookup)
  plabel(13.4, -0.75, "for one user only", c: green, dy: 0)

  swimlane(-0.4, -9.4, 20.4, -4.2, "MONOTONIC READS violated", red, rgb("#fdf0ee"))
  content((5.8, -4.55), dlbl("— \"the count went 5, 4, 5\"", sz: 6.8pt, c: red))
  ppill(2.6, -6.8, "u2", "two reads in a row", w: 4.4)
  pstep(9.8, -5.5, "ra", "replica A", "x = 1 · caught up", st-man, n: 1, actor: "read 1 lands here", w: 4.2, h: 1.1)
  pstep(9.8, -8.1, "rb", "replica B", "x = 0 · staler", st-dec, n: 2, actor: "read 2 lands here", w: 4.2, h: 1.1)
  line("u2.east", "ra.west", mark: (end: ">"), stroke: hot)
  plabel(6.1, -6.08, "read → 1", c: green)
  line("u2.east", "rb.west", mark: (end: ">"), stroke: miss)
  plabel(6.1, -7.52, "read → 0", c: red, dy: -0.4)
  pstep(17.2, -6.8, "fix2", "pin the session", "one replica · LB read token", st-auto,
    n: 3, actor: "the cheap fix", w: 5.0)
  line("rb.east", "fix2.west", mark: (end: ">"), stroke: lookup)
  content((11.4, -9.0), dlbl("time went backwards for this one user", sz: 6.6pt, c: red))
}))
#pcards(
  [Asynchronous replication with measurable lag, and a session the load balancer can identify.],
  [In: a write followed by reads routed anywhere. Out: either a stale answer, or a per-session illusion of strong consistency.],
  [Primary + async replicas (MySQL, Postgres) · load balancer with session affinity · a write-version token in the session.],
)
#v(1.5mm)

#text[
  These two anomalies cause more support tickets than any exotic distributed-systems failure.
  #text(fill: red, weight: "bold")[Read-your-writes] breaks when a user edits their profile, the
  write lands on the primary, and the subsequent read is load-balanced to a replica that has not
  caught up --- the edit "did not save". #text(fill: red, weight: "bold")[Monotonic reads] breaks
  when two consecutive reads hit different replicas and the second is staler than the first ---
  the item count goes 5, then 4, then 5 again.
  #note[Both are fixed cheaply without upgrading your whole consistency model: pin a session to
  one replica (sticky reads) for a few seconds after a write, or carry the write's version token
  in the session and have replicas wait until they have caught up to it. You buy the illusion of
  strong consistency for one user, which is usually all the product needs.]
]
#v(2.5mm)

// ---------------------------------------------------------------- 3.3 --------
#h2("3.3  PACELC — the theorem that actually describes production", c: orange)

#formula("PACELC (Abadi, 2012)")[
  #align(center, text(size: 10.5pt)[
    if (#text(fill: red, weight: "bold")[P])artition: choose
    #text(fill: red, weight: "bold")[A]vailability or #text(fill: red, weight: "bold")[C]onsistency
    #h(4mm) #text(fill: luma(120))[|] #h(4mm)
    #text(fill: blue, weight: "bold")[E]lse: choose
    #text(fill: blue, weight: "bold")[L]atency or #text(fill: blue, weight: "bold")[C]onsistency
  ])
  #v(1.5mm)
  #text(size: 8.8pt)[
    CAP only describes the #text(fill: red)[rare] case --- a network partition. PACELC adds the
    #text(fill: blue, weight: "bold")[99.9% of the time] when the network is fine and you are
    #underline(stroke: 1pt + blue)[still] trading consistency for latency on every single write.
  ]
]
#v(2mm)

#text[
  This is the correction that matters. CAP gets quoted in interviews as if partitions were the
  main event; they are not. The permanent, every-request cost is the
  #text(fill: blue, weight: "bold")[ELSE] branch: if a write must be acknowledged by a quorum in
  three regions before you return, you have added a cross-region round trip --- perhaps
  #text(fill: red)[150ms] --- to every write, on a perfectly healthy network, forever. That is
  not a disaster-recovery cost. That is your p99.
]
#v(2mm)

#table(
  columns: (auto, auto, auto, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#fff3e8") } else { none },
  text(font: headfont, size: 9pt, fill: orange)[System],
  text(font: headfont, size: 9pt, fill: orange)[P #sym.arrow.r],
  text(font: headfont, size: 9pt, fill: orange)[E #sym.arrow.r],
  text(font: headfont, size: 9pt, fill: orange)[What that buys you],

  text(size: 8.5pt)[Spanner],
  text(size: 8.5pt, fill: red)[PC], text(size: 8.5pt, fill: red)[EC],
  text(size: 8.2pt)[external consistency via TrueTime; you pay commit-wait on writes],

  text(size: 8.5pt)[DynamoDB (default)],
  text(size: 8.5pt, fill: green)[PA], text(size: 8.5pt, fill: green)[EL],
  text(size: 8.2pt)[fast and available; reads may be stale unless you ask otherwise],

  text(size: 8.5pt)[Cassandra],
  text(size: 8.5pt, fill: green)[PA], text(size: 8.5pt, fill: green)[EL],
  text(size: 8.2pt)[tunable per query via R + W > N],

  text(size: 8.5pt)[etcd / ZooKeeper],
  text(size: 8.5pt, fill: red)[PC], text(size: 8.5pt, fill: red)[EC],
  text(size: 8.2pt)[small, strongly-ordered metadata; not a data store],

  text(size: 8.5pt)[MySQL + async replica],
  text(size: 8.5pt, fill: green)[PA], text(size: 8.5pt, fill: green)[EL],
  text(size: 8.2pt)[the accidental default nobody wrote down],
)
#v(2mm)

#formula("Tunable quorum: R + W > N")[
  #text(size: 8.8pt)[
    N = replicas, W = acks required to write, R = replicas read.
    #text(weight: "bold")[R + W > N] guarantees the read set and write set overlap, so a read
    sees the latest write.
    #linebreak() #v(1mm)
    N=3, W=2, R=2 #sym.arrow.r 2+2 > 3 #sym.arrow.r
    #text(fill: green, weight: "bold")[strong]; tolerates 1 node down.
    #linebreak()
    N=3, W=1, R=1 #sym.arrow.r 1+1 < 3 #sym.arrow.r
    #text(fill: red, weight: "bold")[eventual]; fastest, may read stale.
    #linebreak()
    N=3, W=3, R=1 #sym.arrow.r fast reads, but #text(fill: red)[any] node down blocks all writes.
  ]
]
#v(2mm)

#key[
  Consistency is a #underline(stroke: 1pt + green)[per-operation] decision, not a database
  choice. In one checkout flow: read the product description #text(fill: green)[eventually]
  (stale by a minute is fine), read inventory #text(fill: orange)[causally], and read-modify-write
  the payment #text(fill: red)[linearizably]. Picking one global level for the whole system means
  overpaying everywhere to protect the few operations that actually need it.
]
#v(2mm)

#anti("\"we use eventual consistency\" as an architecture")[
  Stated system-wide, this sentence is an abdication. It usually means nobody identified which
  operations have an #underline(stroke: 1pt + red)[invariant to protect]. Then a race on
  inventory sells the last unit twice, and the fix arrives as a distributed lock bolted onto a
  store deliberately chosen for not having one. #text(fill: green)[Fix:] enumerate the
  invariants first (never oversell, never double-charge, balance never negative), route those
  specific operations to a linearizable path, and leave everything else fast and eventual.
]
