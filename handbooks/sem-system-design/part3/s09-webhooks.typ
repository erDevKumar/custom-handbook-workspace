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

#pfig("Fig S9.1 · webhook delivery — a per-tenant cap is what stops one dead endpoint eating the fleet")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.3, 20.7, 3.0, "at-least-once published in the docs with a stable event id; SSRF validation on every customer-supplied URL")

  ppill(1.7, 0, "ev", "2M events/hour", w: 3.2)
  pstep(6.15, 0, "rt", "key by tenant", "Kafka key · order kept", st-start, n: 1, actor: "router", w: 4.8)
  pstep(11.4, 0, "cap", "cap 20 in-flight", "per tenant, not fleet", st-auto, n: 2, actor: "dispatcher", w: 4.8)
  pstep(16.66, 0, "post", "signed POST", "HMAC + ts · 200ms", st-integ, n: 3, actor: "customer", w: 4.8)
  pdec(15.84, -3.8, "ok", "2xx within\ntimeout?")
  pstep(10.2, -3.8, "bo", "backoff + jitter", "1s 5s 30s 2m 10m 1h 6h", st-auto, n: 4, actor: "retrier", w: 4.8)
  pstep(4.6, -3.8, "brk", "breaker opens", "stop hammering it", st-integ, n: 5, actor: "dispatcher", w: 4.8)
  ppill(19.6, -3.8, "done", "delivered", w: 2.6)
  ppill(4.6, -7.2, "dlq", "DLQ at 24h, with bodies", c: orange, w: 4.9)

  line("ev.east", "rt.west", mark: (end: ">"), stroke: hot)
  line("rt.east", "cap.west", mark: (end: ">"), stroke: hot)
  line("cap.east", "post.west", mark: (end: ">"), stroke: hot)
  line("post.south", (16.66, -2.0), (15.84, -2.0), "ok.north", mark: (end: ">"), stroke: lookup)
  line("ok.east", "done.west", mark: (end: ">"), stroke: hot)
  plabel(18.3, -2.6, "yes", c: green, dy: 0.0)
  line("ok.west", "bo.east", mark: (end: ">"), stroke: except)
  plabel(13.4, -2.6, "no — 30s endpoint", c: red, dy: 0.0)
  line("bo.west", "brk.east", mark: (end: ">"), stroke: except)
  line("brk.west", (0.9, -3.8), (0.9, -7.2), "dlq.west", mark: (end: ">"), stroke: except)
  plabel(4.6, -5.5, "customer-visible, ~1GB pending", c: orange, dy: 0.5)

  ploop("brk.south", "cap.south", -5.6, "half-open probe — that tenant's own 20 slots, nobody else's", c: blue)
}))
#pcards(
  [Per-tenant queues and concurrency caps before anything else; durable retry storage; per-tenant HMAC secret; URL scheme and resolved-IP validation],
  [In: 556 events/s, ~1% failing · Out: at-least-once signed delivery with a stable event id; one tenant's 30s endpoint occupies 20 workers and its own backlog, never the other 90%],
  [Kafka partitioned on `tenant_id` (M8) · per-tenant dispatcher with a concurrency cap · circuit breaker per endpoint · exponential backoff with full jitter · 24h DLQ with response bodies],
)
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
