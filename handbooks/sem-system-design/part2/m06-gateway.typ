#import "/shared/lib/template.typ": *
#reg(1, "M6", "BFF & API Gateway Topology")
#chapterhead("Part 2 · Modules", "M6 · BFF & API Gateway")
#ix("Backend for Frontend")
#ix("API gateway")

#h1("M6 · BFF & API Gateway Topology", c: blue)

#text[
  A gateway is where cross-cutting concerns stop being every service's problem: TLS, authn,
  rate limiting, routing, observability. A #text(fill: purple, weight: "bold")[BFF] is a
  different thing wearing similar clothes --- one backend per client type, existing because a
  phone on a slow network and a desktop browser want
  #underline(stroke: 1pt + green)[genuinely different payloads].
]
#v(2mm)

#h2("1 · Gateway vs. BFF — not the same layer", c: blue)

#align(center, cetz.canvas(length: 0.82cm, {
  import cetz.draw: *
  swimlane(-0.4, -1.1, 18.4, 2.3, "CLIENTS", purple, rgb("#f5eefa"))
  rnode(2.8, 1.2, "ios", "iOS app", "v3.1 … v7.0", purple, w: 3.2, h: 0.95)
  rnode(8.0, 1.2, "web", "Web SPA", "always latest", purple, w: 3.2, h: 0.95)
  rnode(13.6, 1.2, "ptnr", "Partner API", "3rd party", purple, w: 3.4, h: 0.95)

  rnode(8.0, -2.6, "gw", "API Gateway (Envoy)", "TLS · authn · rate limit · routing", blue,
    w: 9.0, h: 1.2)
  line("ios.south", "gw.north", mark: (end: ">"), stroke: hot)
  line("web.south", "gw.north", mark: (end: ">"), stroke: hot)
  line("ptnr.south", "gw.north", mark: (end: ">"), stroke: hot)
  content((15.2, -2.6), dlbl("one edge, shared concerns", sz: 6.4pt, c: blue))

  rnode(3.0, -5.0, "bffm", "Mobile BFF", "slim payload · batched", green, w: 4.2, h: 1.05)
  rnode(9.4, -5.0, "bffw", "Web BFF", "rich payload", green, w: 3.6, h: 1.05)
  line("gw.south", (8.0, -4.0), (3.0, -4.0), "bffm.north", mark: (end: ">"), stroke: hot)
  line("gw.south", (8.0, -4.0), (9.4, -4.0), "bffw.north", mark: (end: ">"), stroke: hot)

  rnode(2.4, -7.6, "s1", "users", "gRPC", orange, w: 2.8, h: 0.9)
  rnode(6.4, -7.6, "s2", "orders", "gRPC", orange, w: 2.8, h: 0.9)
  rnode(10.4, -7.6, "s3", "catalog", "gRPC", orange, w: 2.8, h: 0.9)
  rnode(14.4, -7.6, "s4", "pricing", "gRPC", orange, w: 2.8, h: 0.9)
  line("bffm.south", "s1.north", mark: (end: ">"), stroke: lookup)
  line("bffm.south", "s2.north", mark: (end: ">"), stroke: lookup)
  line("bffw.south", "s3.north", mark: (end: ">"), stroke: lookup)
  line("bffw.south", "s4.north", mark: (end: ">"), stroke: lookup)
  content((9.0, -8.6), dlbl("BFF fans out and aggregates — client makes ONE call", sz: 6.5pt, c: green))
}))
#v(2mm)

#h2("2 · What belongs where", c: purple)

#table(
  columns: (auto, auto, auto, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#eef4fb") } else { none },
  text(font: headfont, size: 8.5pt, fill: blue)[Concern],
  text(font: headfont, size: 8.5pt, fill: blue)[Gateway],
  text(font: headfont, size: 8.5pt, fill: blue)[BFF],
  text(font: headfont, size: 8.5pt, fill: blue)[Why],

  text(size: 8.3pt)[TLS termination], text(size: 8.3pt, fill: green)[yes], text(size: 8.3pt)[no],
  text(size: 8pt)[One certificate boundary],
  text(size: 8.3pt)[Authentication], text(size: 8.3pt, fill: green)[yes], text(size: 8.3pt)[no],
  text(size: 8pt)[Reject unauthenticated before any business logic],
  text(size: 8.3pt)[Authorisation], text(size: 8.3pt, fill: orange)[coarse], text(size: 8.3pt, fill: green)[fine],
  text(size: 8pt)[Gateway: is this a valid token. BFF/service: may THIS user do THIS],
  text(size: 8.3pt)[Rate limiting], text(size: 8.3pt, fill: green)[yes], text(size: 8.3pt)[no],
  text(size: 8pt)[Global budget per tenant, enforced once],
  text(size: 8.3pt)[Response shaping], text(size: 8.3pt)[no], text(size: 8.3pt, fill: green)[yes],
  text(size: 8pt)[Client-specific; does not belong in shared infrastructure],
  text(size: 8.3pt)[Aggregation], text(size: 8.3pt)[no], text(size: 8.3pt, fill: green)[yes],
  text(size: 8pt)[Collapses N round trips into 1 for a slow client],
  text(size: 8.3pt)[Protocol bridging], text(size: 8.3pt, fill: green)[yes], text(size: 8.3pt, fill: orange)[maybe],
  text(size: 8pt)[gRPC-JSON transcoding at the edge],
  text(size: 8.3pt)[Business logic], text(size: 8.3pt, fill: red)[never], text(size: 8.3pt, fill: red)[never],
  text(size: 8pt)[Both are plumbing. Logic lives in services],
)
#v(2mm)

#key[
  A BFF is owned by the #underline(stroke: 1pt + green)[client team], not the platform team.
  That is the whole point: the people who need the payload changed can change it without
  negotiating with a shared-infrastructure roadmap. A BFF owned centrally is just another
  gateway with extra hops.
]
#v(2mm)

#h2("3 · Capacity arithmetic", c: orange)

#formula("What aggregation actually saves a mobile client")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[Without BFF:] 6 calls, 4G RTT ≈ 70ms, max 4 concurrent
    #sym.arrow.r 2 serial rounds = #text(fill: red, weight: "bold")[140ms] of pure network,
    plus 6 TLS resumptions and 6× header overhead.
    #linebreak()
    #text(weight: "bold")[With BFF:] 1 call = 70ms client#sym.arrow.r BFF, then 6 fan-out calls
    inside the datacentre at 0.5ms each, parallel #sym.arrow.r
    #text(fill: green, weight: "bold")[~72ms total]. A #text(weight: "bold")[2×] latency win
    and far less radio wake-time, which is battery.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Gateway sizing:] 7,000 QPS peak, Envoy handles ~10k RPS/core at
    p99 < 5ms #sym.arrow.r 1 core of actual work, but provision
    #text(fill: orange, weight: "bold")[4 pods × 2 cores] across AZs — gateway capacity is about
    #underline(stroke: 1pt + red)[failure domains], not throughput.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[The gateway becomes a monolith.] Teams add "just one more"
  transformation, then auth quirks, then per-client response rewriting. The gateway grows
  business logic, every change needs platform-team review, and it becomes the
  #underline(stroke: 1pt + red)[slowest-moving component] in a fast-moving system.
  #text(fill: green)[Fix:] a hard rule — if it needs a product decision, it is not gateway
  config.

  #text(fill: red, weight: "bold")[BFF fan-out amplifies the tail.] A BFF waiting on 6 services
  returns only when the slowest does. At p99 per service, 1 − 0.99⁶ =
  #text(fill: red, weight: "bold")[5.9%] of requests hit at least one slow call.
  #text(fill: green)[Fix:] per-dependency timeouts shorter than the client deadline, partial
  responses with explicit `"pricing": null` rather than a failed page, and hedging on idempotent
  reads.

  #text(fill: red, weight: "bold")[Gateway outage is total outage.] Everything routes through it.
  #text(fill: green)[Fix:] multiple pods across AZs, health-checked, with DNS or Anycast
  failover --- and a config rollout path that cannot deploy a bad route to all pods at once.

  #text(fill: red, weight: "bold")[Config drift.] Routes accumulate for services deleted a year
  ago. #text(fill: green)[Fix:] routes declared in version control beside the service that owns
  them, never edited through a console.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Gateway or BFF — which do you need?]
  #linebreak()
  Both, for different reasons. Gateway for cross-cutting concerns you want enforced once; BFF
  when client types genuinely need different payloads. #note[Testing: do you add a BFF
  reflexively? With one web client, a BFF is a hop that buys nothing. The honest answer starts
  "how many client types, and how different are their needs?"]

  #text(fill: green, weight: "bold")[Q: Where does authorisation belong?]
  #linebreak()
  Authentication at the gateway (is this token valid); authorisation at the service (may this
  user do this to this object). #note[Testing: a classic security slip. A gateway cannot answer
  "is this user allowed to read #emph[order 12345]" without becoming the order service.]

  #text(fill: green, weight: "bold")[Q: How do you evolve a BFF without breaking old apps?]
  #linebreak()
  Additive changes only, tolerant readers, and versioned endpoints when a break is unavoidable
  --- see M7. #note[Testing: awareness that mobile clients never fully upgrade. Some user is
  still on a two-year-old build.]
]
#v(2mm)

#anti("the gateway that grew business logic")[
  It starts as one small transformation in gateway config --- "just map this field". Two years
  on, the gateway holds pricing rules, feature flags and per-partner response rewriting written
  in Lua that #text(fill: red)[nobody owns]. It cannot be tested like application code, cannot be
  deployed independently, and a mistake takes down #underline(stroke: 1pt + red)[every] service
  at once. #text(fill: green)[Fix:] gateway config is routing, auth and limits. Anything that
  encodes a product decision belongs in a service with tests and an owner.
]
