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

#align(center, cetz.canvas(length: 0.78cm, {
  import cetz.draw: *
  swimlane(-0.4, -1.0, 19.0, 2.0, "EDGE — reject 99.99% here", red, rgb("#fdf0ee"))
  rnode(2.8, 0.7, "cli", "clients", "10M, attested", purple, w: 3.4, h: 0.85)
  rnode(7.8, 0.7, "cdn", "CDN + WAF", "static sold-out page", blue, w: 4.2, h: 0.85)
  rnode(13.6, 0.7, "gate", "waiting room", "token admission", orange, w: 4.4, h: 0.85)
  line("cli.east", "cdn.west", mark: (end: ">"), stroke: hot)
  line("cdn.east", "gate.west", mark: (end: ">"), stroke: hot)
  content((17.6, 0.7), dlbl("1M → 5k RPS", sz: 6.4pt, c: green))

  swimlane(-0.4, -4.4, 19.0, -1.4, "RESERVATION", green, rgb("#f6fbf7"))
  rnode(3.2, -2.4, "res", "reserve svc", "DECR sharded key", green, w: 4.0, h: 0.85)
  for (i, x) in ((0, 8.0), (1, 10.0), (2, 12.0)).enumerate() {
    rnode(x.at(1), -2.4, "b" + str(i), "bkt" + str(i), "10 units", orange, w: 1.8, h: 0.75)
  }
  rnode(16.4, -2.4, "ob", "outbox", "order event (M9)", purple, w: 4.0, h: 0.85)
  line("gate.south", (13.6, -1.7), (3.2, -1.7), "res.north", mark: (end: ">"), stroke: hot)
  line("res.east", "b0.west", mark: (end: ">"), stroke: lookup)
  line("b2.east", "ob.west", mark: (end: ">"), stroke: hot)
  content((9.0, -3.6), dlbl("reservation holds for 10 min, then auto-releases", sz: 6.4pt, c: purple))

  swimlane(-0.4, -7.2, 19.0, -4.8, "FULFILMENT & MONEY", orange, rgb("#fdf7f2"))
  rnode(3.6, -6.0, "kf", "Kafka", "order stream", purple, w: 3.4, h: 0.8)
  rnode(8.4, -6.0, "pay", "payment saga", "idempotent (S4)", red, w: 4.2, h: 0.8)
  cylinder(14.2, -6.0, "led", "double-entry ledger", red, w: 5.0, h: 0.95)
  line("ob.south", (16.4, -5.1), (3.6, -5.1), "kf.north", mark: (end: ">"), stroke: async)
  line("kf.east", "pay.west", mark: (end: ">"), stroke: hot)
  line("pay.east", "led.west", mark: (end: ">"), stroke: hot)
  bracket(0.6, 18.4, -7.6, "reservation is SYNCHRONOUS; payment and fulfilment are ASYNCHRONOUS", purple)
}))
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
