#import "/shared/lib/template.typ": *
#reg(1, "CS3", "Flash Sale & Financial Ledger")
#chapterhead("Part 4 · Case Studies", "CS3 · Flash Sale & Ledger")

#h1("CS3 · Flash Sale & Financial Ledger", c: red)

#text[
  Prime Day / Big Billion Days scale. Ten million people want the same thousand units at
  10:00:00.000. Two invariants must hold absolutely: #underline(stroke: 1pt + red)[never oversell]
  and #underline(stroke: 1pt + red)[never double-charge]. Everything else — latency, fairness,
  even availability — is negotiable in service of those two.
]
#v(2mm)

#h2("1 · Requirements", c: blue)

#grid(columns: (1fr, 1fr), gutter: 4mm,
  block(inset: 2.5mm, radius: 2pt, fill: rgb("#fdf0ee"), stroke: (left: 2pt + red))[
    #text(size: 8.4pt)[#text(fill: red, weight: "bold")[Hard invariants — never violated] \
      Units sold ≤ units available \
      Each order charged exactly once \
      Ledger balances: #sym.sum debits = #sym.sum credits, always \
      No order lost once acknowledged]
  ],
  block(inset: 2.5mm, radius: 2pt, fill: rgb("#f4f8fd"), stroke: (left: 2pt + blue))[
    #text(size: 8.4pt)[#text(fill: blue, weight: "bold")[Non-functional] \
      #text(weight: "bold")[10M concurrent users] at T-0 \
      Peak #text(weight: "bold")[500k RPS] on the sale endpoint \
      Reserve decision p99 < 500 ms \
      Ledger durable, auditable, 7-year retention \
      Bots must not win disproportionately]
  ])
#v(1.5mm)

#text(size: 8.8pt)[
  #text(fill: purple, weight: "bold")[The framing that wins the interview:] 10M users competing
  for 1,000 units means #underline(stroke: 1pt + green)[99.99% of requests must be rejected].
  The system's job is not to serve 10M purchases — it is to
  #text(fill: green, weight: "bold")[reject 9,999,000 requests cheaply and correctly] while
  processing 1,000 perfectly. Designing for 10M successful checkouts is designing the wrong system.
]
#v(2mm)

#h2("2 · Capacity estimation", c: orange)

#formula("Where the load actually lands")[
  #text(size: 8.5pt)[
    #text(weight: "bold")[Arrival.] 10M users refreshing in the 10 s around T-0 =
    #text(fill: red, weight: "bold")[~1M RPS peak], far above steady state. Autoscaling cannot
    respond in time (M25) — this must be
    #underline(stroke: 1pt + green)[pre-provisioned and pre-warmed].
    #linebreak() #v(1mm)
    #text(weight: "bold")[Rejection must be cheap.] If rejection costs a database call at
    1M RPS, the database dies. Decrementing a Redis counter costs
    #text(fill: green, weight: "bold")[~0.2 ms]; sold-out responses are served from the edge at
    #text(fill: green, weight: "bold")[~0 cost] once the counter hits zero.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Inventory decrement throughput.] 1,000 units, so only
    #text(weight: "bold")[1,000 successful] decrements are needed — but every request attempts
    one. A single Redis key doing `DECR` sustains ~100k ops/s; at 1M RPS it is a
    #text(fill: red, weight: "bold")[hot key] (S11).
    #linebreak()
    #text(fill: green, weight: "bold")[Fix: shard the inventory into 100 buckets of 10 units].
    Each bucket takes 10k ops/s. A request hashes to a bucket; if empty, it may try one neighbour,
    then fails fast.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Ledger writes.] 1,000 orders × 2 entries (double-entry) =
    #text(weight: "bold")[2,000 rows] — utterly trivial. #underline(stroke: 1pt + green)[The
    ledger is never the bottleneck]; the admission path is. Candidates who optimise the ledger
    have mis-located the problem.
  ]
]
#v(2mm)

#h2("3 · Topology", c: blue)

#pfig("Fig CS3.1 · topology — each tier's job is to reject more cheaply than the tier below it")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  swimlane(-0.4, -1.1, 20.4, 2.1, "EDGE — reject 99.99% here", red, rgb("#fdf0ee"))
  rnode(2.8, 0.5, "cli", "clients", "10M · attested (M34)", purple, w: 4.2, h: 0.9)
  rnode(9.4, 0.5, "cdn", "CDN + WAF", "static sold-out page", blue, w: 4.8, h: 0.9)
  rnode(16.4, 0.5, "gate", "waiting room", "token admission", orange, w: 4.6, h: 0.9)
  line("cli.east", "cdn.west", mark: (end: ">"), stroke: hot)
  line("cdn.east", "gate.west", mark: (end: ">"), stroke: hot)
  badge(6.5, 0.5, "1", green)
  plabel(6.5, 0.5, "~1M RPS at T-0", c: red, dy: -0.72)
  badge(13.2, 0.5, "2", green)
  plabel(13.2, 0.5, "~0 cost once sold out", c: green, dy: -0.72)

  swimlane(-0.4, -5.0, 20.4, -1.6, "RESERVATION — the only synchronous part", green, rgb("#f6fbf7"))
  rnode(3.4, -2.7, "res", "reserve svc", "DECR sharded key", green, w: 4.6, h: 0.9)
  for (i, x) in ((0, 8.8), (1, 10.8), (2, 12.8)).enumerate() {
    rnode(x.at(1), -2.7, "b" + str(i), "bkt" + str(i), "10 units", orange, w: 1.8, h: 0.8)
  }
  rnode(17.6, -2.7, "ob", "outbox", "order event (M9)", purple, w: 4.4, h: 0.9)
  line("gate.south", (16.4, -1.95), (3.4, -1.95), "res.north", mark: (end: ">"), stroke: hot)
  line("res.east", "b0.west", mark: (end: ">"), stroke: lookup)
  line("b2.east", "ob.west", mark: (end: ">"), stroke: hot)
  badge(6.8, -2.7, "3", green)
  plabel(6.8, -2.7, "hash to a bucket", c: green, dy: -0.72)
  badge(15.4, -2.7, "4", green)
  plabel(15.4, -2.7, "DECR ≥ 0 — won", c: green, dy: -0.72)
  plabel(10.8, -2.7, "100 buckets × 10 units · 10k ops/s each", c: orange, dy: 0.72)
  content((10.8, -4.3), dlbl("a reservation holds for 10 minutes, then auto-releases to its bucket",
    sz: 6.6pt, c: purple))

  swimlane(-0.4, -8.0, 20.4, -5.5, "FULFILMENT & MONEY — asynchronous, never the bottleneck", orange, rgb("#fdf7f2"))
  rnode(3.6, -6.8, "kf", "Kafka", "order stream", purple, w: 3.8, h: 0.9)
  rnode(9.4, -6.8, "pay", "payment saga", "idempotent (S4)", red, w: 4.6, h: 0.9)
  cylinder(16.4, -6.8, "led", "double-entry ledger — 2,000 rows", red, w: 7.4, h: 1.0)
  line("ob.south", (17.6, -5.7), (3.6, -5.7), "kf.north", mark: (end: ">"), stroke: async)
  line("kf.east", "pay.west", mark: (end: ">"), stroke: hot)
  line("pay.east", "led.west", mark: (end: ">"), stroke: hot)
  badge(6.5, -6.8, "5", green)
  badge(12.5, -6.8, "6", red)
  plabel(12.5, -6.8, "Σ debits = Σ credits", c: red, dy: -0.74)
  plabel(11.6, -5.7, "outbox, not dual-write", c: purple, dy: -0.34)
  bracket(0.4, 20.0, -8.4,
    "reservation is SYNCHRONOUS (p99 500 ms); payment and fulfilment are ASYNCHRONOUS", purple)
}))
#pcards(
  [Everything pre-provisioned and pre-warmed before T-0 — autoscaling cannot respond inside the
   10-second arrival window (M25).],
  [In: ~1M RPS of purchase attempts. Out: 1,000 reservations, 1,000 orders, 2,000 ledger rows —
   and 9,999,000 cheap, honest rejections.],
  [CDN + WAF · waiting room · Redis sharded counters · Postgres reservations · Kafka · ledger],
)
#v(2mm)

#h2("4 · The two invariants, mechanically enforced", c: purple)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Never oversell — atomic decrement, not check-then-act.]
  `DECR` on a sharded counter is atomic and returns the new value; if it is negative, the request
  lost and the value is restored. There is #underline(stroke: 1pt + green)[no window] between
  checking and taking (M22, S11). Reservation is then confirmed into Postgres within a 10-minute
  TTL; unconfirmed reservations auto-release back to the bucket.
  #note[Redis is the admission control, Postgres is the record. If Redis is lost mid-sale, the
  authoritative reserved count is recoverable from Postgres — you may undersell slightly, which is
  #text(fill: green)[the correct direction to fail].]

]
#v(1.5mm)

#pfig("Fig CS3.2 · the reserve critical path — one request at T-0, from 10M attempts to 1,000 wins")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.2, 20.2, 2.5,
    "fleet pre-warmed · 100 buckets seeded with 10 units each · client generated order_id before the first attempt")

  // ---- row 1: the edge sheds almost everything
  ppill(2.2, 0, "in", "tap BUY at 10:00:00", c: purple, w: 4.6)
  pstep(8.6, 0, "a", "WAF + attestation", "Play Integrity (M34)", st-integ, n: 1,
    actor: "edge", w: 4.6)
  pdec(13.2, 0, "d1", "counter\nalready 0?", w: 2.2)
  pstep(18.8, 0, "b", "waiting room", "admit 5k/s from queue", st-integ, n: 2,
    actor: "edge", w: 4.4)

  line("in.east", "a.west", mark: (end: ">"), stroke: hot)
  line("a.east", "d1.west", mark: (end: ">"), stroke: lookup)
  line("d1.east", "b.west", mark: (end: ">"), stroke: hot)
  plabel(15.6, 0, "no", c: green, dy: 0.34)

  // ---- wrap to row 2
  line("b.south", (18.8, -2.1), (2.6, -2.1), (2.6, -3.1), mark: (end: ">"), stroke: wrap)
  plabel(10.6, -2.1, "1M RPS collapsed to a rate we chose: ~5,000/s", c: luma(110), dy: 0.28)

  // ---- row 2: the only synchronous decision in the system
  pstep(2.6, -4.4, "c", "hash to a bucket", "order_id → 0..99", st-auto, n: 3,
    actor: "reserve svc", w: 4.4)
  pstep(8.2, -4.4, "e", "atomic DECR", "~0.2 ms · no check-then-act", st-auto, n: 4,
    actor: "Redis", w: 5.2)
  pdec(13.2, -4.4, "d2", "new value\n≥ 0?", w: 2.0)
  pstep(18.8, -4.4, "f", "write reservation", "Postgres · TTL 10 min", st-auto, n: 5,
    actor: "reserve svc", w: 4.6)

  line("c.east", "e.west", mark: (end: ">"), stroke: hot)
  line("e.east", "d2.west", mark: (end: ">"), stroke: hot)
  line("d2.east", "f.west", mark: (end: ">"), stroke: hot)
  plabel(15.5, -4.4, "yes — won", c: green, dy: 0.34)

  // ---- retry one neighbour before giving up: the bucket-skew rail
  ploop("d2.south", "c.south", -6.4, "empty bucket → probe up to two neighbours, then fail fast")

  // ---- wrap to row 3
  line("f.south", (18.8, -7.6), (3.4, -7.6), (3.4, -8.6), mark: (end: ">"), stroke: wrap)
  plabel(10.6, -7.6, "Redis is the admission control; Postgres is the record", c: luma(110), dy: 0.28)

  pstep(3.4, -9.9, "g", "outbox row", "same transaction (M9)", st-auto, n: 6,
    actor: "reserve svc", w: 4.8)
  ppill(10.6, -9.9, "out", "RESERVED — 10 min to pay", c: green, w: 6.4)
  line("g.east", "out.west", mark: (end: ">"), stroke: hot)

  // ---- the exception that 99.99% of requests take
  pstep(17.6, -9.9, "x", "SOLD OUT", "static page · Retry-After", st-dec, n: 0,
    actor: "edge", w: 4.8)
  line("d1.south", (13.2, -5.9), (0.3, -5.9), (0.3, -11.7), (17.6, -11.7), "x.south",
    mark: (end: ">"), stroke: except)
  plabel(9.6, -11.7, "sold out, or lost the DECR — rejecting cheaply IS the system's job", c: red, dy: 0.28)
}))
#pcards(
  [Fleet pre-provisioned and pre-warmed; inventory pre-sharded into 100 buckets; the client
   generated its `order_id` before the first attempt (M14, S4).],
  [In: one of ~10M purchase attempts. Out: either a reservation held for 10 minutes, or a rejection
   served from the edge at near-zero cost. Nothing in between.],
  [CDN + WAF · Play Integrity / App Attest · waiting room · Redis `DECR` · Postgres + outbox],
)
#v(2mm)

#text(size: 8.8pt)[
  #text(fill: red, weight: "bold")[Never double-charge — double-entry plus idempotency.] Every
  movement is two rows (debit one account, credit another) in
  #underline(stroke: 1pt + green)[one transaction], so #sym.sum debits = #sym.sum credits is a
  checkable invariant run continuously. The ledger is
  #text(fill: red, weight: "bold")[append-only] — corrections are reversing entries, never
  updates — so the history is auditable. Every charge carries an idempotency key derived from the
  order id (S4), and the payment service deduplicates on it.
]
#v(1.5mm)

#table(
  columns: (auto, auto, 1fr, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#f5eefa") } else { none },
  text(font: headfont, size: 8.4pt, fill: purple)[Entity],
  text(font: headfont, size: 8.4pt, fill: purple)[Store],
  text(font: headfont, size: 8.4pt, fill: purple)[Key],
  text(font: headfont, size: 8.4pt, fill: purple)[Property],

  text(size: 8.2pt)[Inventory bucket],
  text(size: 8.2pt)[Redis],
  text(size: 8pt)[`sku:{id}:bkt:{0..99}` → integer],
  text(size: 8pt)[Atomic DECR; sharded to avoid a hot key],

  text(size: 8.2pt)[Reservation],
  text(size: 8.2pt)[Postgres],
  text(size: 8pt)[PK `reservation_id`; TTL index on `expires_at`],
  text(size: 8pt)[Authoritative; auto-release on expiry],

  text(size: 8.2pt)[Order],
  text(size: 8.2pt)[Postgres],
  text(size: 8pt)[PK `order_id` (UUIDv7, client-supplied)],
  text(size: 8pt)[Doubles as the idempotency key],

  text(size: 8.2pt)[Ledger entry],
  text(size: 8.2pt)[Postgres],
  text(size: 8pt)[Append-only; `(account_id, seq)`],
  text(size: 8pt)[Immutable; balance = SUM, never a stored field],
)
#v(2mm)

#h2("5 · Client & edge contracts", c: green)

#text(size: 8.8pt)[
  #text(fill: orange, weight: "bold")[The waiting room is the single most important component.]
  Admit a controlled rate (say 5,000/s) from a queue, and give everyone else an honest position
  and estimate. It converts an uncontrolled stampede into a
  #underline(stroke: 1pt + green)[rate you chose], and it is far better UX than a timeout —
  users accept a queue and resent a spinner.

  #text(fill: red, weight: "bold")[Anti-scalper measures (M34).] Play Integrity / App Attest at
  session start, rate limits per account and per payment instrument, account-age and
  purchase-history weighting, and CAPTCHA only for high-risk sessions. Attestation
  #underline(stroke: 1pt + red)[raises cost, never prevents] — state this honestly rather than
  claiming bots are stopped.

  #text(fill: green, weight: "bold")[Client behaviour.] Client-generated `order_id` before the
  first attempt (M14, S4); retry with full jitter; and the UI must distinguish
  #text(fill: orange)["queued"], #text(fill: green)["reserved"] and
  #text(fill: red)["sold out"] — three genuinely different states that a naive implementation
  collapses into one spinner.
]
#v(2mm)

#h2("6 · Failure modes", c: red)

#text(size: 8.8pt)[
  #text(fill: red, weight: "bold")[Redis fails mid-sale.] #text(fill: green)[Fix:] fail
  #underline(stroke: 1pt + green)[closed] — stop selling. Serving without inventory control risks
  overselling, which is worse than a brief pause. Recover the authoritative count from confirmed
  reservations in Postgres, then resume.
]
#v(1.5mm)

#pfig("Fig CS3.3 · failure response — Redis dies at T+40 s with 400 units sold")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.2, 20.2, 2.5,
    "every confirmed reservation already written to Postgres · the edge can serve a static page with no origin")

  // ---- detection
  ppill(2.2, 0, "in", "DECR starts erroring", c: red, w: 4.8)
  pstep(9.0, 0, "a", "detect", "error rate + health probe", st-dec, n: 1,
    actor: "reserve svc", w: 5.0)
  pdec(14.2, 0, "d", "can we still\ncount stock?", w: 2.4)
  pstep(19.0, 0, "b", "FAIL CLOSED", "stop selling, now", st-dec, n: 2, actor: "on-call", w: 4.2)

  line("in.east", "a.west", mark: (end: ">"), stroke: miss)
  line("a.east", "d.west", mark: (end: ">"), stroke: except)
  line("d.east", "b.west", mark: (end: ">"), stroke: except)
  plabel(17.2, 0, "no", c: red, dy: 0.74)

  // ---- wrap to mitigation
  line("b.south", (19.0, -2.1), (2.6, -2.1), (2.6, -3.1), mark: (end: ">"), stroke: wrap)
  plabel(10.6, -2.1,
    "overselling is unrecoverable; a pause is not — so pause", c: luma(110), dy: 0.28)

  pstep(2.6, -4.4, "c", "edge serves queue", "\"paused, hold your place\"", st-integ, n: 3,
    actor: "CDN + WAF", w: 5.0)
  pstep(8.6, -4.4, "e", "count confirmed", "SELECT from reservations", st-auto, n: 4,
    actor: "Postgres", w: 5.2)
  pstep(14.6, -4.4, "f", "reseed buckets", "units − confirmed", st-auto, n: 5,
    actor: "reserve svc", w: 4.6)
  pstep(19.4, -4.4, "g", "undersell slightly", "the correct direction", st-man, n: 6,
    actor: "commerce", w: 4.4)

  line("c.east", "e.west", mark: (end: ">"), stroke: hot)
  line("e.east", "f.west", mark: (end: ">"), stroke: hot)
  plabel(11.7, -4.4, "authoritative count", c: green, dy: -0.74)
  line("f.east", "g.west", mark: (end: ">"), stroke: hot)

  // ---- wrap to recovery
  line("g.south", (19.4, -6.4), (3.4, -6.4), (3.4, -7.4), mark: (end: ">"), stroke: wrap)
  plabel(10.6, -6.4, "in-flight TTLs expire on their own; nothing has to be reconciled by hand",
    c: luma(110), dy: 0.28)

  pstep(3.4, -8.7, "h", "resume admission", "waiting room reopens", st-auto, n: 7,
    actor: "waiting room", w: 5.0)
  ppill(11.4, -8.7, "out", "sale resumes · oversell = 0", c: green, w: 7.0)
  line("h.east", "out.west", mark: (end: ">"), stroke: hot)

  // ---- the alternative branch, and why it is never taken
  pstep(18.4, -8.7, "x", "sell blind", "oversell — P0, never", st-dec, n: 0, actor: "rejected", w: 4.6)
  line("d.south", (14.2, -5.9), (0.3, -5.9), (0.3, -10.5), (18.4, -10.5), "x.south",
    mark: (end: ">"), stroke: except)
  plabel(9.4, -10.5, "the branch we refuse: availability is negotiable, the invariants are not",
    c: red, dy: 0.28)

  ploop("out.south", "h.south", -11.9, "recovered — Redis is admission control, Postgres is the record")
}))
#pcards(
  [Every confirmed reservation is already durable in Postgres, so the authoritative sold count
   never lived only in Redis.],
  [In: the loss of the inventory counters mid-sale. Out: a brief, honest pause, reseeded buckets,
   and an oversell count of zero — possibly a handful of units undersold.],
  [Redis (admission control) · Postgres (the record) · reservation TTL · CDN static queue page],
)
#v(2mm)

#text(size: 8.8pt)[
  #text(fill: red, weight: "bold")[Payment declines after reservation.] #text(fill: green)[Fix:]
  the saga compensates by returning the unit to its bucket (M4). Reservation TTL guarantees
  release even if the compensation itself fails.

  #text(fill: red, weight: "bold")[Bucket skew.] Hashing leaves some buckets empty while others
  hold stock, so a user is told "sold out" while units remain.
  #text(fill: green)[Fix:] on an empty bucket, probe up to two neighbours before failing; and
  rebalance buckets periodically during the sale.

  #text(fill: red, weight: "bold")[Ledger imbalance.] #text(fill: green)[Fix:] a continuous
  invariant check (#sym.sum debits − #sym.sum credits = 0) alerting at
  #text(fill: red, weight: "bold")[P1]. A non-zero result means stop and investigate, never
  "correct it and move on".

  #text(fill: red, weight: "bold")[The thundering retry.] Rejected users retry in unison.
  #text(fill: green)[Fix:] `Retry-After` honoured by the client, full jitter, and shed retries
  before first attempts (M20).
]
#v(2mm)

#h2("7 · Delivery roadmap", c: purple)

#text(size: 8.8pt)[
  #text(fill: purple, weight: "bold")[Team topology.]
  #text(weight: "bold")[Commerce] (inventory, reservation, waiting room),
  #text(weight: "bold")[Money] (payments, ledger, reconciliation — staffed with people who have
  done financial systems; this is not a rotation),
  #text(weight: "bold")[Edge/Platform] (CDN, WAF, attestation, load shedding),
  #text(weight: "bold")[Client].

  #text(fill: purple, weight: "bold")[Phasing.]
  #text(weight: "bold")[M0–M2:] ledger and idempotency framework first —
  #underline(stroke: 1pt + green)[the invariants before the scale].
  #text(weight: "bold")[M3–M4:] sharded inventory and reservation with the TTL release path.
  #text(weight: "bold")[M5:] waiting room and edge shedding.
  #text(weight: "bold")[M6:] attestation and anti-abuse.
  #text(weight: "bold")[M7:] #text(fill: red, weight: "bold")[full-scale load test at 2× expected
  peak] — non-negotiable, and the milestone leadership will try to cut.

  #text(fill: purple, weight: "bold")[Game day is the deliverable.] Rehearse the sale end to end
  with synthetic load at 2× peak, including a deliberate Redis failure and a payment-provider
  timeout. Everything in this design that has not been exercised under load
  #underline(stroke: 1pt + red)[is a hypothesis].

  #text(fill: purple, weight: "bold")[SLO targets.] Oversell rate
  #text(weight: "bold")[0] (any violation is a P0) · double-charge rate
  #text(weight: "bold")[0] · reserve decision p99 < 500 ms · waiting-room admission fairness
  within 10% · ledger imbalance #text(weight: "bold")[0].

  #text(fill: purple, weight: "bold")[The conversation with the business.] They will ask for
  "no queue" and "everyone gets a fair chance". Explain the trade honestly: with 10,000 units and
  10M buyers, #underline(stroke: 1pt + green)[the queue is the fairness mechanism] — the
  alternative is whoever has the fastest connection and the most aggressive retry loop, which in
  practice means bots.
]
