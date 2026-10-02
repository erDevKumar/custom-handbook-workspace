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

#align(center, cetz.canvas(length: 0.86cm, {
  import cetz.draw: *
  rnode(4.2, 2.6, "lin", "LINEARIZABLE", "Spanner · etcd · single-node RDBMS", red, w: 7.4, h: 1.15)
  rnode(4.2, 1.1, "seq", "SEQUENTIAL", "ZooKeeper writes · some RSM designs", orange, w: 7.4, h: 1.15)
  rnode(4.2, -0.4, "cau", "CAUSAL", "COPS · MongoDB causal sessions", blue, w: 7.4, h: 1.15)
  rnode(4.2, -1.9, "eve", "EVENTUAL", "Dynamo · Cassandra ONE · S3", green, w: 7.4, h: 1.15)
  line("lin.south", "seq.north", mark: (end: ">"), stroke: 1pt + luma(150))
  line("seq.south", "cau.north", mark: (end: ">"), stroke: 1pt + luma(150))
  line("cau.south", "eve.north", mark: (end: ">"), stroke: 1pt + luma(150))

  content((12.6, 2.6), dlbl("real-time order; one global timeline", sz: 7pt, c: red))
  content((12.5, 1.1), dlbl("one agreed order, NOT real-time", sz: 7pt, c: orange))
  content((12.8, -0.4), dlbl("cause before effect; concurrent is free", sz: 7pt, c: blue))
  content((12.2, -1.9), dlbl("converges... eventually", sz: 7pt, c: green))

  line((17.4, 3.1), (17.4, -2.5), stroke: (paint: luma(150), dash: "dashed", thickness: 0.8pt))
  content((18.1, 2.5), dlbl("more", sz: 6.5pt, c: red))
  content((18.1, 2.0), dlbl("coord", sz: 6.5pt, c: red))
  content((18.1, -1.5), dlbl("more", sz: 6.5pt, c: green))
  content((18.1, -2.0), dlbl("speed", sz: 6.5pt, c: green))
  bracket(0.4, 7.9, -2.9, "pick the WEAKEST model that keeps the product correct", purple)
}))
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

#align(center, cetz.canvas(length: 0.9cm, {
  import cetz.draw: *
  content((2.0, 2.3), dlbl("READ-YOUR-WRITES violated", sz: 8pt, c: red))
  node(1.6, 1.2, "u1", "user", blue, w: 1.6, h: 0.7)
  node(5.2, 1.7, "p1", "primary\n[x=1]", green, w: 2.1, h: 0.9)
  node(5.2, 0.3, "r1", "replica\n[x=0]", red, w: 2.1, h: 0.9)
  line("u1.east", "p1.west", mark: (end: ">"), stroke: hot)
  content((3.4, 1.85), dlbl("write x=1", sz: 6.5pt, c: green))
  line("r1.west", "u1.east", mark: (end: ">"), stroke: miss)
  content((3.4, 0.15), dlbl("read x -> 0 !", sz: 6.5pt, c: red))
  line("p1.south", "r1.north", mark: (end: ">"), stroke: async)
  content((6.6, 1.0), dlbl("lag", sz: 6.5pt, c: purple))

  content((12.0, 2.3), dlbl("MONOTONIC READS violated", sz: 8pt, c: red))
  node(10.6, 1.0, "u2", "user", blue, w: 1.6, h: 0.7)
  node(14.4, 1.7, "ra", "replica A\n[x=1]", green, w: 2.1, h: 0.9)
  node(14.4, 0.3, "rb", "replica B\n[x=0]", red, w: 2.1, h: 0.9)
  line("u2.east", "ra.west", mark: (end: ">"), stroke: hot)
  content((12.6, 1.75), dlbl("read -> 1", sz: 6.5pt, c: green))
  line("u2.east", "rb.west", mark: (end: ">"), stroke: miss)
  content((12.6, 0.25), dlbl("read -> 0", sz: 6.5pt, c: red))
  content((14.4, -0.8), dlbl("time went backwards", sz: 7pt, c: red))
}))
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
