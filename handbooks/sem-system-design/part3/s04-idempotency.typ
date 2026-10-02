#import "/shared/lib/template.typ": *
#reg(1, "S4", "End-to-end idempotency framework")
#chapterhead("Part 3 · Interview Scenarios", "S4 · Idempotency Framework")

#h1("S4 · An End-to-End Idempotency Framework", c: green)

#text[
  #text(fill: purple, weight: "bold")[The prompt.] A payment traverses a mobile app, a gateway,
  three microservices and an external processor. Any hop may time out ambiguously. Design the
  framework that guarantees a customer is charged #underline(stroke: 1pt + green)[exactly once],
  across a stack where every individual layer is at-least-once.
]
#v(2mm)

#h2("1 · The dilemma and its root cause", c: red)

#text(size: 9pt)[
  A timeout is #text(fill: red, weight: "bold")[not a failure] — it is the absence of
  information. The request may have succeeded, failed, or still be in flight. The caller must
  retry (otherwise legitimate transient failures lose orders), and retrying is exactly what
  causes double charges.

  #text(fill: purple, weight: "bold")[Root cause.] Exactly-once
  #underline(stroke: 1pt + red)[delivery] is impossible across an unreliable network (M8). What
  is achievable is exactly-once #underline(stroke: 1pt + green)[effect]: at-least-once delivery
  plus deduplication at the point of effect. The framework's job is to make every layer
  deduplicate against a key that survives every retry.
]
#v(2mm)

#h2("2 · The solution — one key, carried end to end", c: green)

#align(center, cetz.canvas(length: 0.8cm, {
  import cetz.draw: *
  swimlane(-0.4, -2.2, 18.4, 2.0, "ONE KEY, GENERATED ONCE, CARRIED EVERYWHERE", green,
    rgb("#f6fbf7"))
  rnode(2.2, 1.0, "app", "mobile app", "UUIDv7 at intent", purple, w: 3.4, h: 0.95)
  rnode(6.6, 1.0, "gw", "gateway", "passes through", blue, w: 2.8, h: 0.95)
  rnode(10.6, 1.0, "ord", "order svc", "dedupe table", green, w: 3.0, h: 0.95)
  rnode(14.6, 1.0, "pay", "payment svc", "derives child key", green, w: 3.2, h: 0.95)
  cylinder(17.6, 1.0, "psp", "processor", orange, w: 2.4, h: 0.95)
  for (a, b) in (("app", "gw"), ("gw", "ord"), ("ord", "pay"), ("pay", "psp")) {
    line(a + ".east", b + ".west", mark: (end: ">"), stroke: hot)
  }
  content((9.0, -0.1), dlbl("Idempotency-Key: 018f3c...  — never regenerated on retry", sz: 6.5pt, c: purple))
  content((9.0, -0.85), dlbl("each service stores (key → response) and REPLAYS the stored result",
    sz: 6.5pt, c: green))
  content((9.0, -1.6), dlbl("payment key = hash(parent key + \"charge\") — stable across retries",
    sz: 6.5pt, c: orange))
}))
#v(1.5mm)

#text(size: 9pt)[
  #text(fill: green, weight: "bold")[1 · The client generates the key at intent, not at send.]
  A UUIDv7 (M14) created when the user taps "Pay", stored locally
  #underline(stroke: 1pt + red)[before] the first attempt. If the app crashes and restarts, it
  resumes with the same key. A key generated per HTTP attempt is worthless — that is the most
  common implementation bug in this design.

  #text(fill: green, weight: "bold")[2 · Each service stores key → result, atomically.] The
  canonical implementation is a unique constraint:
  `INSERT INTO idempotency(key, status) VALUES (?, 'in_progress')`. If it succeeds, you are the
  first — do the work. If it violates the constraint, someone else is handling it: return their
  stored response, or 409 if still in progress. #note[The insert and the business write belong in
  #underline(stroke: 1pt + green)[one local transaction]. If they are separate, a crash between
  them leaves a key claimed with no effect — and the retry is rejected while nothing happened.]

  #text(fill: green, weight: "bold")[3 · Derive child keys deterministically.] The payment
  service must not invent a fresh key for the processor, or its own retry double-charges.
  `child = hash(parent_key + operation_name)` is stable across every retry at every level.

  #text(fill: green, weight: "bold")[4 · Store the response, not just the key.] A retry must
  receive the #underline(stroke: 1pt + green)[same response] as the original — same order id,
  same status. Returning "already processed" forces the client to reconcile, which it cannot do.

  #text(fill: green, weight: "bold")[5 · Expire deliberately.] Keys are retained longer than the
  longest plausible retry window — 24–72 hours for payments. Expiring at one hour means a client
  retrying after a long offline period gets charged twice.
]
#v(2mm)

#key[
  Idempotency is a #underline(stroke: 1pt + green)[contract that must be honoured at every hop],
  not a feature of one service. The weakest link defines the guarantee: a single service that
  regenerates keys, or treats the dedupe insert as separate from its business write, breaks
  exactly-once for the whole chain regardless of how careful everyone else was.
]
#v(2mm)

#formula("Storage and the states you must handle")[
  #text(size: 8.6pt)[
    1M payments/day × 72 h retention = #text(weight: "bold")[3M keys], each with a stored
    response of ~1 KB #sym.arrow.r #text(fill: green, weight: "bold")[3 GB] — trivial in
    Postgres or Redis with a TTL.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Three states, all of which occur:]
    #linebreak()
    #h(3mm) `in_progress` #sym.arrow.r return #text(weight: "bold")[409] and let the client poll.
    Never block, or a stuck original hangs every retry behind it.
    #linebreak()
    #h(3mm) `completed` #sym.arrow.r replay the stored response verbatim.
    #linebreak()
    #h(3mm) `failed` #sym.arrow.r return the stored failure. A retry must not
    #underline(stroke: 1pt + red)[re-attempt] a deterministic failure, or a declined card is
    retried forever.
    #linebreak() #v(1mm)
    #text(fill: red, weight: "bold")[Stuck in_progress] is the state nobody plans for: the
    original process died after claiming the key. A sweeper must expire `in_progress` rows older
    than the maximum request duration and mark them failed, or that payment can never be retried.
  ]
]
#v(2mm)

#h2("3 · SEM execution strategy", c: purple)

#text(size: 8.9pt)[
  #text(fill: purple, weight: "bold")[This is a platform decision, not a service decision.] Ship
  it as a shared library and a middleware so every team gets the same semantics for free. Fifteen
  teams implementing idempotency independently will produce fifteen subtly different behaviours,
  and the differences only surface during an incident.

  #text(fill: purple, weight: "bold")[Make it testable and prove it.] A conformance test every
  service must pass: send the same key twice concurrently, assert
  #underline(stroke: 1pt + green)[one effect and two identical responses]. Run it in CI. Without
  this, correctness decays silently as services are refactored.

  #text(fill: purple, weight: "bold")[Blast radius.] Idempotency state is itself a dependency on
  the payment path. Decide the failure policy in advance: if the dedupe store is unreachable,
  payments #text(fill: red, weight: "bold")[fail closed] — refusing a payment is recoverable,
  double-charging is a refund, an apology and sometimes a regulator.

  #text(fill: purple, weight: "bold")[Stakeholder framing.] Finance and support care about one
  number: duplicate-charge rate. Instrument it, report it, and treat any non-zero value as a
  P1 defect. #note[The organisational failure mode here is that duplicate charges are discovered
  by #underline(stroke: 1pt + red)[customers], weeks later, via support tickets. Build the
  detection query before you need it: same user, same amount, same merchant, within minutes.]
]
#v(2mm)

#anti("generating the idempotency key on the server")[
  The server generates a key when the request arrives and uses it to deduplicate. This provides
  #text(fill: red, weight: "bold")[no protection whatsoever] against the case that matters: a
  client retry after a timeout arrives as a #emph[new] request and receives a
  #emph[new] key, so it deduplicates against nothing and the customer is charged twice. The key
  must originate at the #underline(stroke: 1pt + green)[only place that knows two requests
  represent one intent] — the client. Server-side generation looks correct in every test where
  the client does not retry, which is every test anyone writes.
]
