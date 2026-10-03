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

#pfig("Fig M6.1 · one mobile call through the gateway and the BFF that collapses six round trips")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.3, 20.9, 2.6, "JWKS cached at the edge; a per-tenant rate budget configured; the BFF owned by the client team")

  ppill(1.6, 0, "in", "iOS request", w: 2.9)
  pstep(5.9, 0, "gw", "gateway", "Envoy TLS + authn · 2ms", st-start, n: 1, actor: "edge", w: 4.2)
  pdec(10.6, 0, "tok", "token\nvalid?", w: 1.5)
  pstep(15.0, 0, "bff", "Mobile BFF", "slim payload · 3ms", st-man, n: 2, actor: "client team", w: 4.0)
  ppill(19.3, 0, "out", "one response", w: 2.9)

  pstep(15.0, -4.0, "svc", "fan out 6 gRPC calls", "in-DC 0.5ms each, parallel", st-auto, n: 3, actor: "services", w: 4.8)
  pstep(5.7, -4.0, "rej", "401 at the edge", "no business logic reached", st-dec, n: 4, actor: "edge", w: 4.6)

  line("in.east", "gw.west", mark: (end: ">"), stroke: hot)
  line("gw.east", "tok.west", mark: (end: ">"), stroke: hot)
  line("tok.east", "bff.west", mark: (end: ">"), stroke: hot)
  plabel(12.65, 0, "yes", c: green, dy: 0.62)
  line("bff.east", "out.west", mark: (end: ">"), stroke: hot)
  line("bff.south", "svc.north", mark: (end: ">"), stroke: lookup)
  plabel(17.2, -2.1, "users, orders, catalog", c: green, dy: 0)
  line("tok.south", (10.6, -4.0), "rej.east", mark: (end: ">"), stroke: except)
  plabel(9.3, -4.0, "no", c: red, dy: 0.34)
  content((10.3, -6.4), dlbl("six direct calls from the phone cost 140ms of pure network; one call plus in-datacentre fan-out costs 73ms", sz: 6.5pt, c: purple))
}))
#pcards(
  [TLS, authn and the global rate budget live at the gateway; fine-grained authorisation lives in the service],
  [In: 1 mobile request (70ms RTT) · Out: 1 shaped response. 6 fan-out calls at 0.5ms, in parallel, inside the DC],
  [Envoy gateway · Mobile BFF and Web BFF · users / orders / catalog / pricing over gRPC · cached JWKS],
)
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
