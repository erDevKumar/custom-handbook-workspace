#import "/shared/lib/template.typ": *
#reg(1, "S9", "Multi-tenant webhook dispatch at scale")
#chapterhead("Part 3 · Interview Scenarios", "S9 · Webhook Dispatch Engine")

#h1("S9 · A Webhook Dispatch Engine", c: green)

#text[
  #text(fill: purple, weight: "bold")[The prompt.] Millions of events per hour must be delivered
  to thousands of customer-controlled HTTP endpoints. Those endpoints are slow, unreliable,
  occasionally hostile, and entirely outside your control. Design the engine.
]
#v(2mm)

#h2("1 · The dilemma and its root cause", c: red)

#text(size: 9pt)[
  You are building a system whose performance is determined by
  #underline(stroke: 1pt + red)[other people's infrastructure]. One customer's endpoint takes 30
  seconds; another returns 500s all weekend; a third is on a home broadband connection. A naive
  worker pool shared across tenants means the slowest customer
  #text(fill: red, weight: "bold")[consumes every worker] and nobody receives anything.

  #text(fill: purple, weight: "bold")[Root cause.] Treating dispatch as one queue. The required
  property is #underline(stroke: 1pt + green)[per-tenant isolation] — a bulkhead problem (Part 1
  §6.3) rather than a throughput problem.
]
#v(2mm)

#formula("Worker maths — why the slow tenant wins")[
  #text(size: 8.6pt)[
    2M events/hour = #text(weight: "bold")[556/s]. At a healthy 200 ms per delivery, Little's Law
    gives L = 556 × 0.2 = #text(fill: green, weight: "bold")[111 concurrent workers]. Comfortable.
    #linebreak() #v(1mm)
    Now one tenant's endpoint degrades to #text(weight: "bold")[30 s] and receives 10% of events
    (55.6/s): L = 55.6 × 30 = #text(fill: red, weight: "bold")[1,668 workers] consumed by
    #underline(stroke: 1pt + red)[one customer]. With a shared pool of 200, that tenant takes all
    of them and the other 90% of events stop moving entirely.
    #linebreak() #v(1mm)
    #text(fill: green, weight: "bold")[With per-tenant concurrency caps (say 20 each):] the slow
    tenant occupies 20 workers, its own queue backs up, and
    #underline(stroke: 1pt + green)[every other tenant is unaffected]. Their problem stays their
    problem — which is the entire design goal.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Retry storage:] 2M/hour × 1% failing × 24 h retry window × 2 KB =
    #text(fill: orange, weight: "bold")[~1 GB] of pending retries. Small, but it must be durable
    — losing it means losing customer events.
  ]
]
#v(2mm)

#h2("2 · The design", c: green)

#align(center, cetz.canvas(length: 0.8cm, {
  import cetz.draw: *
  swimlane(-0.4, -2.3, 18.4, 2.0, "PER-TENANT QUEUES, CAPPED CONCURRENCY, BREAKERS", green,
    rgb("#f6fbf7"))
  rnode(2.2, 1.0, "ev", "event bus", "Kafka (M8)", purple, w: 3.0, h: 0.95)
  rnode(6.4, 1.0, "rt", "router", "key = tenant_id", blue, w: 3.2, h: 0.95)
  line("ev.east", "rt.west", mark: (end: ">"), stroke: hot)
  for (i, y) in ((0, 1.6), (1, 0.6), (2, -0.4)).enumerate() {
    rnode(10.8, y.at(1), "q" + str(i), "tenant " + str(i + 1) + " queue", "cap 20 in-flight",
      green, w: 3.6, h: 0.7)
    line("rt.east", "q" + str(i) + ".west", mark: (end: ">"), stroke: lookup)
  }
  rnode(15.8, 1.6, "ok", "endpoint ok", "200", green, w: 3.0, h: 0.7)
  rnode(15.8, 0.6, "slow", "endpoint SLOW", "breaker opens", red, w: 3.0, h: 0.7)
  rnode(15.8, -0.4, "dlq", "DLQ after 24 h", "customer-visible", orange, w: 3.4, h: 0.7)
  line("q0.east", "ok.west", mark: (end: ">"), stroke: hot)
  line("q1.east", "slow.west", mark: (end: ">"), stroke: miss)
  line("q2.east", "dlq.west", mark: (end: ">"), stroke: miss)
  content((9.0, -1.3), dlbl("one tenant's backlog NEVER consumes another tenant's capacity",
    sz: 6.6pt, c: green))
  content((9.0, -2.0), dlbl("ordering preserved per tenant by partitioning on tenant_id",
    sz: 6.5pt, c: purple))
}))
#v(1.5mm)

#text(size: 9pt)[
  #text(fill: green, weight: "bold")[Per-tenant queues with capped concurrency] are the
  load-bearing decision. Everything else is detail.

  #text(fill: green, weight: "bold")[Circuit breakers per endpoint.] After N consecutive
  failures, stop attempting for a cooldown (Part 1 §6.1). Hammering a dead endpoint for hours
  wastes your capacity and, for a customer recovering from their own incident,
  #underline(stroke: 1pt + red)[is a denial-of-service attack you are running against them].

  #text(fill: green, weight: "bold")[Exponential backoff with full jitter,] 24-hour window:
  roughly 1s, 5s, 30s, 2m, 10m, 1h, 6h. Then the dead-letter queue, with the failures
  #underline(stroke: 1pt + green)[visible to the customer] in their dashboard along with the
  response bodies you received. They cannot fix what they cannot see.

  #text(fill: green, weight: "bold")[Signed payloads, at-least-once delivery.] HMAC with a
  per-tenant secret and a timestamp so customers can verify authenticity and reject replays.
  Delivery is at-least-once; publish that fact and include a stable event id so consumers
  deduplicate (S4).

  #text(fill: red, weight: "bold")[SSRF defence is mandatory.] Customer-supplied URLs are an
  attack vector: validate the scheme, resolve the hostname and
  #underline(stroke: 1pt + red)[reject private IP ranges], re-check after redirects, and dispatch
  from an egress-restricted network. Without this, a customer can point a webhook at your internal
  metadata endpoint and read your cloud credentials.
]
#v(2mm)

#key[
  Webhook delivery is #underline(stroke: 1pt + green)[at-least-once, best-effort, and
  eventually-consistent] — say so in the public documentation. Customers who assume exactly-once
  build systems that break, then raise support tickets against your correctness. The contract is
  part of the product.
]
#v(2mm)

#h2("3 · SEM execution strategy", c: purple)

#text(size: 8.9pt)[
  #text(fill: purple, weight: "bold")[Define the SLO as something you control.]
  #text(fill: green)["99.9% of events are #underline(stroke: 1pt + green)[attempted] within 60
  seconds"] — never "delivered", because delivery depends on the customer's endpoint. This
  distinction protects the team from being measured on someone else's uptime, and it is the first
  thing to establish with product.

  #text(fill: purple, weight: "bold")[Make failures self-serve.] A dashboard showing recent
  deliveries, response codes, bodies and a replay button deflects the majority of support tickets
  and lets customers debug their own endpoints. The engineering cost is modest; the support saving
  is large and permanent.

  #text(fill: purple, weight: "bold")[Blast radius.] Per-tenant isolation #emph[is] the
  containment. Additionally cap total concurrency per destination
  #underline(stroke: 1pt + green)[host], since many tenants may share one SaaS provider — without
  it you aggregate into an unintentional attack on a third party.

  #text(fill: purple, weight: "bold")[The conversation with the slow customer.] Some endpoints are
  chronically slow and their backlog grows indefinitely. Publish a documented policy —
  "endpoints consistently slower than 10 s may have delivery throttled" — and notify before you
  throttle. An undocumented throttle discovered during an incident becomes an escalation.

  #text(fill: purple, weight: "bold")[Team.] Two engineers for a solid v1 in a quarter; the
  dependency is a durable event bus (M8). Budget time for the security review —
  #underline(stroke: 1pt + red)[SSRF in a webhook system is a critical finding], and discovering
  it in a pen test after launch is far more expensive than designing for it.
]
#v(2mm)

#anti("one shared worker pool for all tenants")[
  A single pool of 200 workers dispatches to every customer. One customer's endpoint starts taking
  30 seconds — not down, just slow, so no breaker trips. Within minutes all 200 workers are
  blocked on that one tenant, and #text(fill: red, weight: "bold")[every other customer stops
  receiving events entirely]. Your status page says healthy; your error rate is zero; the queue
  simply is not moving. The incident is reported by customers, diagnosis takes hours because
  nothing is #underline(stroke: 1pt + red)[failing], and the eventual fix — per-tenant caps —
  could have prevented it from day one. #text(fill: green)[Fix:] bulkhead by tenant, cap
  concurrency per tenant and per destination host, and alert on per-tenant queue age rather than
  on error rate.
]
