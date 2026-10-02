#import "/shared/lib/template.typ": *
#reg(1, "S1", "100× traffic spike on Tier-0 checkout")
#chapterhead("Part 3 · Interview Scenarios", "S1 · 100× Traffic Spike")

#h1("S1 · A 100× Spike on Checkout", c: red)

#text[
  #text(fill: purple, weight: "bold")[The prompt.] A marketing campaign you were not told about
  goes live. Checkout traffic rises 100× in ninety seconds. Autoscaling will not finish in time.
  Dropping requests costs revenue directly. What do you do, and what do you tell the VP who is
  already asking?
]
#v(2mm)

#h2("1 · The dilemma and its root cause", c: red)

#text(size: 9pt)[
  The instinct is to add capacity, and it is wrong on the timescale that matters.
  Scale-up takes #underline(stroke: 1pt + red)[2–6 minutes] (M25) and the spike is 90 seconds
  old. Worse, more checkout pods multiply pressure on the
  #text(fill: red, weight: "bold")[shared bottleneck] — usually a single primary database — so
  scaling can accelerate the collapse rather than prevent it.

  #text(fill: purple, weight: "bold")[Root cause, stated precisely:] checkout is a
  #underline(stroke: 1pt + green)[synchronous, stateful, non-idempotent] path that holds a
  database connection and a row lock for its duration. Its ceiling is not CPU; it is
  #text(weight: "bold")[concurrency against the primary]. Little's Law (Appendix A) fixes that
  number, and no amount of application capacity moves it.
]
#v(2mm)

#formula("What actually breaks first")[
  #text(size: 8.6pt)[
    Baseline 500 checkouts/s, DB transaction 40 ms
    #sym.arrow.r L = 500 × 0.04 = #text(weight: "bold")[20 concurrent transactions].
    #linebreak()
    At 100× #sym.arrow.r 50,000/s would need
    #text(fill: red, weight: "bold")[2,000 concurrent transactions] against a primary that
    supports perhaps #text(weight: "bold")[200]. Requests queue, transaction time inflates to
    400 ms, and L rises again — #underline(stroke: 1pt + red)[the queue is self-reinforcing].
    #linebreak() #v(1mm)
    #text(fill: green, weight: "bold")[Therefore:] the system can serve ~5,000/s of real
    checkouts, not 50,000. The job is to make sure the 5,000 it serves are
    #text(weight: "bold")[real orders] and that the other 45,000 fail in a way that
    #underline(stroke: 1pt + green)[preserves the sale] rather than losing it.
  ]
]
#v(2mm)

#h2("2 · The solution, in the order you do it", c: green)

#align(center, cetz.canvas(length: 0.82cm, {
  import cetz.draw: *
  swimlane(-0.4, -2.3, 18.4, 2.1, "DEGRADE → QUEUE → DRAIN", green, rgb("#f6fbf7"))
  rnode(2.6, 1.1, "cli", "clients", "100× burst", purple, w: 3.2, h: 0.95)
  rnode(7.2, 1.1, "edge", "edge / gateway", "shed by priority", orange, w: 4.0, h: 0.95)
  rnode(12.4, 1.1, "q", "order intake queue", "accept + ack fast", green, w: 4.6, h: 0.95)
  cylinder(16.8, 1.1, "db", "primary", orange, w: 2.8, h: 1.0)
  line("cli.east", "edge.west", mark: (end: ">"), stroke: hot); badge(4.9, 1.65, "1", green)
  line("edge.east", "q.west", mark: (end: ">"), stroke: hot);   badge(9.8, 1.65, "2", green)
  line("q.east", "db.west", mark: (end: ">"), stroke: lookup);  badge(14.6, 1.65, "3", orange)
  content((14.6, 0.35), dlbl("drained at 5,000/s — the DB's real rate", sz: 6.3pt, c: orange))
  content((7.2, 0.1), dlbl("recommendations, reviews, analytics → 0%", sz: 6.3pt, c: red))
  content((7.2, -0.5), dlbl("browse → cached · checkout → always admitted", sz: 6.3pt, c: green))
  bracket(0.6, 17.6, -1.4, "the user sees \"order received\" in 200 ms; fulfilment is async", purple)
}))
#v(1.5mm)

#text(size: 9pt)[
  #text(fill: green, weight: "bold")[Step 1 — shed everything that is not checkout.] Flip the
  kill switches (M24) for recommendations, reviews, related items and non-essential analytics.
  This is instant, reversible and frees both application capacity and database connections.

  #text(fill: green, weight: "bold")[Step 2 — convert checkout from synchronous to accepted.]
  The critical reframing: a user does not need their order #emph[fulfilled] in the request, only
  #underline(stroke: 1pt + green)[durably accepted]. Write the order to a queue with an
  idempotency key, return `202 Accepted` with an order id, and confirm by push or email when
  fulfilment completes. Revenue is captured at 200 ms; the database drains at its own pace.

  #text(fill: green, weight: "bold")[Step 3 — protect the inventory invariant.] Queued orders
  may exceed stock. Reserve atomically at drain time (M22) and notify the losers honestly ---
  overselling a thousand items is a far worse outcome than a thousand "sold out" emails.

  #text(fill: green, weight: "bold")[Step 4 — concurrency-limit the drain.] The worker pool is
  capped at the primary's measured concurrency, with the queue absorbing the difference. Never
  let scaled-out workers open unbounded connections (M25).
]
#v(2mm)

#key[
  The whole scenario turns on one question:
  #underline(stroke: 1pt + green)[what does the user actually need synchronously?] For checkout
  it is a durable acceptance, not a completed transaction. Recognising that converts an
  availability problem into a throughput problem, and throughput problems have queues.
]
#v(2mm)

#h2("3 · SEM execution strategy", c: purple)

#text(size: 8.9pt)[
  #text(fill: purple, weight: "bold")[SLOs under duress.] Declare which one you are defending
  before the incident, not during it. Here:
  #text(fill: green)[order acceptance ≥ 99.9%] is defended;
  #text(fill: orange)[order confirmation latency] is explicitly relaxed from seconds to minutes;
  #text(fill: red)[browse latency] is sacrificed. Writing this down in advance is what lets an
  on-call engineer act at 2am without escalating.

  #text(fill: purple, weight: "bold")[Blast radius containment.] Checkout, browse and
  recommendations must already be separate deployments with separate connection pools (M28) ---
  bulkheads built on a calm day. An incident is too late to discover that one pool serves
  everything.

  #text(fill: purple, weight: "bold")[Team structure.] One incident commander who does not touch
  a keyboard, one operator executing changes, one scribe on the timeline, one communications
  owner. #note[The commander's job is deciding what not to do. The common failure in a 100×
  incident is four engineers making simultaneous uncoordinated changes, after which nobody can
  say what helped.]

  #text(fill: purple, weight: "bold")[Stakeholder communication.] Lead with business impact, not
  mechanism: #text(fill: green)["Orders are being accepted. Confirmations are delayed by up to
  fifteen minutes. No revenue is being lost. Next update in twenty minutes."] That sentence stops
  the escalation. Avoid ETAs you cannot support; commit to update
  #underline(stroke: 1pt + green)[cadence] instead.

  #text(fill: purple, weight: "bold")[The follow-up that matters.] The real defect is
  organisational — a campaign launched without capacity notice. The remediation is a
  pre-launch checklist tying marketing events to a capacity review, not merely more autoscaling.
]
#v(2mm)

#anti("scaling up as the first move")[
  The reflex is to raise replica counts immediately. Each new pod opens connections to the same
  primary, pushing it past `max_connections`; existing healthy pods then fail to acquire
  connections and #underline(stroke: 1pt + red)[checkout fails completely] rather than partially.
  Scaling arrives after the spike has passed and makes the collapse faster in the meantime.
  #text(fill: green)[Fix:] shed, queue and degrade first — all of which take effect in seconds.
  Scale afterwards, behind a connection pooler, once the shared bottleneck is protected.
]
