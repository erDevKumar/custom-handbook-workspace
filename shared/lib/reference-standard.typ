#import "../template.typ": *
#set page(paper: "a4", margin: (x: 13mm, y: 12mm), fill: paper,
  numbering: "1", number-align: center)
#set text(font: bodyfont, size: 9.5pt, fill: ink)
#set par(leading: 0.62em, justify: true)

#h1("Sample — Multi-Tier Read Path", c: blue)

#text[
  This page is the #underline(stroke: 1pt + green)[reference standard] for every module in the
  handbook: a detailed numbered flow diagram, per-component reasoning with real technologies and
  capacities, failure modes, capacity arithmetic, and an anti-pattern. If a module page is less
  detailed than this, it is not finished.
]
#v(3mm)

#align(center, cetz.canvas(length: 0.86cm, {
  import cetz.draw: *

  // ---- swimlanes ----
  swimlane(-0.4, -1.1, 18.4, 2.1, "EDGE", blue, rgb("#f4f8fd"))
  swimlane(-0.4, -5.0, 18.4, -1.5, "SERVICE", green, rgb("#f6fbf7"))
  swimlane(-0.4, -8.6, 18.4, -5.4, "STORAGE", orange, rgb("#fdf7f2"))

  // ---- EDGE ----
  rnode(3.0, 0.7, "cli", "Mobile Client", "ETag · 5MB disk cache", blue, w: 3.6)
  rnode(8.2, 0.7, "cdn", "CDN PoP", "CloudFront · TTL 60s", blue, w: 3.6)
  rnode(13.4, 0.7, "gw", "API Gateway", "Envoy · mTLS · 2ms", blue, w: 3.8)

  // ---- SERVICE ----
  rnode(3.2, -2.9, "svc", "Read Service", "Go · 12 pods · HPA", green, w: 3.8)
  rnode(8.4, -2.9, "l1", "L1 cache", "in-proc LRU 10k · 0.05ms", green, w: 4.0)
  rnode(13.8, -2.9, "l2", "L2 Redis", "cluster · 6 shards · 1ms", green, w: 4.0)

  // ---- STORAGE ----
  cylinder(4.0, -7.0, "rep", "read replica", orange, w: 3.2, h: 1.3)
  cylinder(9.6, -7.0, "pri", "primary", orange, w: 3.0, h: 1.3)
  cylinder(15.0, -7.0, "obj", "S3 blobs", purple, w: 3.0, h: 1.3)

  // ---- happy path with numbered steps ----
  line("cli.east", "cdn.west", mark: (end: ">"), stroke: hot)
  badge(5.6, 1.35, "1", green)
  line("cdn.east", "gw.west", mark: (end: ">"), stroke: hot)
  badge(10.8, 1.35, "2", green)
  line("gw.south", (13.4, -1.3), (3.2, -1.3), "svc.north", mark: (end: ">"), stroke: hot)
  badge(8.3, -0.95, "3", green)
  line("svc.east", "l1.west", mark: (end: ">"), stroke: hot)
  badge(5.8, -2.4, "4", green)
  line("l1.east", "l2.west", mark: (end: ">"), stroke: lookup)
  badge(11.1, -2.4, "5", green)

  // ---- miss path ----
  line("l2.south", (13.8, -5.2), (4.0, -5.2), "rep.north", mark: (end: ">"), stroke: miss)
  badge(8.9, -5.2, "6", red)
  content((16.0, -4.6), dlbl("cache MISS -> replica", sz: 6.6pt, c: red))

  // ---- replication ----
  line("pri.west", "rep.east", mark: (end: ">"), stroke: async)
  content((6.8, -6.45), dlbl("async repl", sz: 6.5pt, c: purple))
  content((6.8, -7.55), dlbl("lag 50-200ms", sz: 6.5pt, c: red))
  line("pri.east", "obj.west", mark: (end: ">"), stroke: cold)
  content((12.3, -6.5), dlbl("cold tier", sz: 6.5pt, c: purple))

  // ---- latency budget bracket ----
  bracket(0.4, 13.4, -8.2, "end-to-end p99 budget: 120ms", purple)
}))
#v(2mm)

#h2("Why each hop exists — and what it costs", c: blue)

#text(size: 9pt)[
  #text(fill: blue, weight: "bold")[1 · Client cache (0ms).] The cheapest request is the one never
  sent. An `ETag` lets the client revalidate with a 304 instead of re-downloading a payload.
  #note[You cannot invalidate it. The device may be offline exactly when you need the change to
  land, so keep TTLs short or version the resource path.]

  #text(fill: blue, weight: "bold")[2 · CDN edge (15ms).] Absorbs the read-heavy tail of public
  content near the user and cuts origin egress cost, which is often the larger win.
  #note[A `Vary: Authorization` header silently drops hit rate to near zero — every user becomes
  a distinct cache key. Personalised responses do not belong at the CDN.]

  #text(fill: green, weight: "bold")[4 · L1 in-process (0.05ms).] A plain LRU map inside the
  service. No network hop at all, so it is two orders of magnitude faster than L2.
  #note[Bounded by heap: 10k entries, not 10M. Each pod holds its own copy, so 12 pods means 12
  independent cold starts after a deploy and 12 copies that go stale separately.]

  #text(fill: green, weight: "bold")[5 · L2 Redis (1ms).] Shared across pods, so one fill serves
  the whole fleet and a rolling deploy does not cold-start everything at once.
  #note[It is now a network dependency on your read path — it needs its own timeout, its own
  circuit breaker, and a defined behaviour for when it is unreachable.]
]
#v(2mm)

#formula("Capacity check — does this design hold?")[
  #text(size: 8.8pt)[
    100M users, 20% DAU, 10 reads/user/day:
    #linebreak()
    20,000,000 #sym.times 10 = #text(weight: "bold")[200M reads/day]
    #sym.arrow.r 200,000,000 / 86,400 = #text(fill: orange, weight: "bold")[2,315 QPS average].
    #linebreak()
    Peak is typically 3#sym.times average #sym.arrow.r
    #text(fill: orange, weight: "bold")[~7,000 QPS].
    #linebreak() #v(1mm)
    At a 95% combined hit rate, origin sees 0.05 #sym.times 7,000 =
    #text(fill: green, weight: "bold")[350 QPS] — comfortable for one replica.
    #linebreak()
    If the hit rate drops to #text(fill: red)[60%] (bad invalidation), origin sees
    #text(fill: red, weight: "bold")[2,800 QPS] — an 8#sym.times jump that will take the replica down.
    #underline(stroke: 1pt + red)[Cache hit rate is a capacity dependency, not an optimisation.]
  ]
]
#v(2mm)

#compare(
  "HIT PATH (95%):",
  [steps 1–5 only. 15 + 2 + 0.05 = #text(weight: "bold")[~17ms] p50. Never touches storage.],
  "MISS PATH (5%):",
  [adds step 6 plus replication lag. Reader may see data up to
   #text(weight: "bold")[200ms stale].],
)
#v(2mm)

#h2("What breaks, and what you do about it", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Cache stampede.] A hot key expires; 5,000 concurrent requests
  all miss and issue the same query. The replica saturates and every one of them times out ---
  including the request that would have refilled the cache. #text(fill: green)[Fix:] a per-key
  lock so exactly one request refills, or probabilistic early expiry (XFetch) where each reader
  independently rolls a dice that grows likelier as the TTL approaches, spreading refills out.

  #text(fill: red, weight: "bold")[Thundering herd on deploy.] All 12 pods restart with empty L1.
  The entire fleet hits L2, and whatever L2 misses goes to storage simultaneously.
  #text(fill: green)[Fix:] stagger the rollout, pre-warm the top-N keys, and let L2 survive the
  deploy --- which is half the reason it exists.

  #text(fill: red, weight: "bold")[Redis unreachable.] Without a plan, every read now blocks on a
  1ms call that is taking 30 seconds. #text(fill: green)[Fix:] short timeout, circuit breaker,
  and fall through to the replica with a reduced request rate --- degraded, not down.
]
#v(2mm)

#key[
  Cache invalidation is hard not because the code is hard, but because
  #text(fill: red, weight: "bold")[every tier has a different TTL], so one logical object is
  simultaneously fresh at one layer and stale at another. Name the
  #underline(stroke: 1pt + green)[authoritative] copy and make every other copy visibly
  disposable.
]
#v(2mm)

#anti("caching without a staleness budget")[
  Teams add Redis because reads are slow, then discover the product cannot tolerate
  #text(fill: red)[60-second stale] balances. Decide the budget
  #underline(stroke: 1pt + green)[first]: a price ticker tolerates 1s, a wallet balance tolerates
  #text(fill: red)[0ms] and must read the primary. The staleness budget selects the tier --- not
  the other way round.
]
