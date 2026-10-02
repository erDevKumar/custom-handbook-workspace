#import "/shared/lib/template.typ": *
// CHAPTER-HEAD: Part 2 · Modules | M4 · Distributed Transactions & Saga
#reg(1, "M4", "Distributed Transactions & Saga")
#chapterhead("Part 2 · Modules", "M4 · Distributed Transactions & Saga")
#ix("Saga")
#ix("Two-phase commit")
#ix("Compensating transaction")

#h1("M4 · Distributed Transactions & Saga", c: purple)

#text[
  A local transaction gives you atomicity for free. The moment a business operation spans two
  services with two databases, that guarantee is gone --- and every mechanism to get it back
  costs either #text(fill: red)[availability] or #text(fill: orange)[isolation]. The modern answer
  is to stop trying to recreate ACID across the network.
]
#v(2mm)

#h2("1 · Why 2PC fails in practice", c: red)

#text(size: 9pt)[
  Two-phase commit does work, and its guarantees are real. The problem is the
  #underline(stroke: 1pt + red)[window between phases]. In phase 1 every participant promises it
  can commit and takes locks. In phase 2 the coordinator tells everyone to commit or abort. If
  the coordinator dies after phase 1, every participant sits
  #text(fill: red, weight: "bold")[blocked, holding locks], unable to decide --- committing risks
  inconsistency, aborting risks losing a promised commit. This is not a bug; it is inherent.
  2PC is a #text(fill: red)[blocking] protocol.

  Layer that onto synchronous microservices and the availability maths is brutal: the transaction
  needs #underline(stroke: 1pt + red)[every] participant up simultaneously, so availability is
  the product of all of them, and lock hold time becomes a network round trip instead of a
  microsecond.
]
#v(2mm)

#align(center, cetz.canvas(length: 0.84cm, {
  import cetz.draw: *
  swimlane(-0.4, -2.3, 8.4, 3.6, "2PC — blocking", red, rgb("#fdf0ee"))
  rnode(4.0, 2.6, "co", "coordinator", "single point of failure", red, w: 4.6, h: 0.9)
  rnode(1.5, 0.7, "p1", "svc A", "LOCKED", orange, w: 2.2, h: 0.85)
  rnode(4.0, 0.7, "p2", "svc B", "LOCKED", orange, w: 2.2, h: 0.85)
  rnode(6.5, 0.7, "p3", "svc C", "LOCKED", orange, w: 2.2, h: 0.85)
  line("co.south", "p1.north", mark: (end: ">"), stroke: 1.1pt + orange)
  line("co.south", "p2.north", mark: (end: ">"), stroke: 1.1pt + orange)
  line("co.south", "p3.north", mark: (end: ">"), stroke: 1.1pt + orange)
  content((4.0, -0.4), dlbl("phase 1: all vote YES, all hold locks", sz: 6.4pt, c: orange))
  content((4.0, -1.1), dlbl("coordinator dies HERE ->", sz: 6.6pt, c: red))
  content((4.0, -1.75), dlbl("everyone blocked, locks held, indefinitely", sz: 6.6pt, c: red))

  swimlane(9.2, -2.3, 18.4, 3.6, "SAGA — non-blocking, compensating", green, rgb("#f6fbf7"))
  rnode(11.4, 2.3, "s1", "T1 reserve", "inventory", green, w: 3.0, h: 0.85)
  rnode(15.6, 2.3, "s2", "T2 charge", "payment", green, w: 3.0, h: 0.85)
  rnode(15.6, 0.6, "s3", "T3 ship", "fulfilment", red, w: 3.0, h: 0.85)
  line("s1.east", "s2.west", mark: (end: ">"), stroke: hot)
  badge(13.5, 2.3, "1", green)
  line("s2.south", "s3.north", mark: (end: ">"), stroke: hot)
  badge(15.6, 1.45, "2", green)
  content((17.6, 0.6), dlbl("FAILS", sz: 6.5pt, c: red))
  // compensations run backwards
  line("s3.west", (11.4, 0.6), "s1.south", mark: (end: ">"), stroke: miss)
  content((13.3, 0.0), dlbl("C2: refund", sz: 6.3pt, c: red))
  content((13.3, -0.65), dlbl("C1: release stock", sz: 6.3pt, c: red))
  content((13.8, -1.5), dlbl("each step commits locally — NO locks held", sz: 6.5pt, c: green))
}))
#v(2mm)

#h2("2 · Orchestration vs choreography", c: blue)

#table(
  columns: (auto, 1fr, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#eef4fb") } else { none },
  text(font: headfont, size: 8.5pt, fill: blue)[Aspect],
  text(font: headfont, size: 8.5pt, fill: blue)[Orchestration (central)],
  text(font: headfont, size: 8.5pt, fill: blue)[Choreography (events)],

  text(size: 8.3pt)[Flow lives in],
  text(size: 8pt, fill: green)[One workflow definition you can read],
  text(size: 8pt, fill: orange)[Emergent across N services],

  text(size: 8.3pt)[Debugging],
  text(size: 8pt, fill: green)[One place shows current state],
  text(size: 8pt, fill: red)[Reconstruct from logs across services],

  text(size: 8.3pt)[Coupling],
  text(size: 8pt, fill: orange)[Orchestrator knows every participant],
  text(size: 8pt, fill: green)[Services only know event shapes],

  text(size: 8.3pt)[Adding a step],
  text(size: 8pt)[Edit the workflow],
  text(size: 8pt)[New subscriber, no central edit],

  text(size: 8.3pt)[Failure risk],
  text(size: 8pt, fill: orange)[Orchestrator is critical infrastructure],
  text(size: 8pt, fill: red)[Cyclic event storms, no global view],

  text(size: 8.3pt)[Use when],
  text(size: 8pt)[Business-critical, auditable, > 3 steps],
  text(size: 8pt)[Loose notification fan-out, 2--3 steps],
)
#v(2mm)

#key[
  Saga trades atomicity for availability, and what you give up is
  #text(fill: red, weight: "bold")[isolation]. Mid-saga, the system is in a state no ACID database
  would ever expose: payment taken, stock not yet reserved. The user may
  #underline(stroke: 1pt + red)[see] that state. Design for it --- "pending" is a real status that
  belongs in your UI and your data model, not an edge case.
]
#v(2mm)

#h2("3 · Capacity & correctness arithmetic", c: orange)

#formula("Availability and retry maths")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[2PC across 4 services, each 99.9%:] the transaction needs all four
    simultaneously #sym.arrow.r 0.999#super[4] = #text(fill: red, weight: "bold")[99.6%]
    #sym.arrow.r 0.004 #sym.times 525,960 = #text(fill: red, weight: "bold")[2,104 min/yr]
    (~35 hours) of transaction-level unavailability.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Saga, same services:] each step retries independently, so a step's
    temporary failure delays rather than fails the saga. Effective completion approaches
    #text(fill: green, weight: "bold")[99.99%+] at the cost of a longer tail --- some orders
    settle in minutes, not milliseconds.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Compensation volume:] 100k orders/day, 0.5% fail after the payment step
    #sym.arrow.r #text(fill: orange, weight: "bold")[500 refunds/day] to execute automatically.
    #underline(stroke: 1pt + red)[Compensations are production traffic] — size, monitor and alert
    on them like any other path.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Compensation itself fails.] You cannot un-send an email or
  un-ship a parcel. #text(fill: green)[Fix:] order the saga so
  #underline(stroke: 1pt + green)[irreversible steps go last], and make everything before them
  retryable. If a step truly cannot be compensated, it must be the final one.

  #text(fill: red, weight: "bold")[Duplicate execution.] Retries mean every step runs
  #text(fill: red)[at least once]. Charging twice is unacceptable.
  #text(fill: green)[Fix:] an idempotency key per step, stored with the result, so a replay
  returns the original outcome rather than repeating the effect.

  #text(fill: red, weight: "bold")[Out-of-order compensation.] C1 runs before C2 completes and
  releases stock that T2's refund still references. #text(fill: green)[Fix:] compensate in
  strict reverse order, and persist saga state after every transition --- a durable workflow
  engine (Temporal, Cadence) exists precisely to get this right.

  #text(fill: red, weight: "bold")[Lost saga state.] The orchestrator crashes mid-saga with the
  state in memory. #text(fill: green)[Fix:] event-sourced saga log; recovery replays to the last
  committed step.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Why not 2PC across microservices?]
  #linebreak()
  It blocks: a coordinator failure between phases leaves participants holding locks with no way
  to decide. Availability is the product of all participants.
  #note[Testing: can you name the #underline(stroke: 1pt + green)[specific] window? Saying "2PC
  is slow" is the shallow answer; "it blocks on coordinator failure after the prepare phase" is
  the real one.]

  #text(fill: green, weight: "bold")[Q: How do you roll back a saga?]
  #linebreak()
  You do not roll back --- each step already committed. You run compensating transactions in
  reverse order, which are new forward transactions that semantically undo. #note[Testing:
  whether you understand that a refund is not a rollback. The money moved; the ledger records
  both events.]

  #text(fill: green, weight: "bold")[Q: Orchestration or choreography?]
  #linebreak()
  Orchestration for anything business-critical or longer than ~3 steps --- you need one place to
  see where an order is. Choreography for loose fan-out notifications. #note[Testing: do you have
  a decision rule, or just a preference? The strong answer names the breaking point.]
]
#v(2mm)

#anti("the dual write")[
  A service writes to its database and then publishes an event to Kafka. These are two systems
  and there is #underline(stroke: 1pt + red)[no transaction spanning them]. Crash in between and
  you have a committed row with no event (downstream never learns) or an event with no row
  (downstream acts on a fiction). Wrapping both in a `try/catch` does not help --- the crash can
  land between the two calls. #text(fill: green)[Fix:] the
  #text(fill: green, weight: "bold")[transactional outbox] --- write the event into an `outbox`
  table in the #text(fill: green)[same] local transaction as the data, and let a separate relay
  (CDC, see M9) publish it. One atomic commit, no distributed transaction.
]
