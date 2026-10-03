#import "/shared/lib/template.typ": *
#reg(1, "CS1", "Global Ride-Hailing & Logistics Platform")
#chapterhead("Part 4 · Case Studies", "CS1 · Ride-Hailing Platform")

#h1("CS1 · Global Ride-Hailing Platform", c: green)

#text[
  Uber/Lyft/Ola scale. The defining property is that this is a
  #underline(stroke: 1pt + green)[physical-world system]: supply moves, GPS lies, networks drop
  mid-trip, and a dispatch decision that is three seconds late is worthless because the driver has
  moved on.
]
#v(2mm)

#h2("1 · Requirements", c: blue)

#grid(columns: (1fr, 1fr), gutter: 4mm,
  block(inset: 2.5mm, radius: 2pt, fill: rgb("#eef7f1"), stroke: (left: 2pt + green))[
    #text(size: 8.4pt)[#text(fill: green, weight: "bold")[Functional] \
      Rider requests a ride; system matches a nearby driver \
      Live driver location on the rider's map \
      Dynamic pricing under supply/demand imbalance \
      Trip lifecycle: accept → arrive → start → complete \
      Payment on completion; receipt; ratings]
  ],
  block(inset: 2.5mm, radius: 2pt, fill: rgb("#f4f8fd"), stroke: (left: 2pt + blue))[
    #text(size: 8.4pt)[#text(fill: blue, weight: "bold")[Non-functional] \
      #text(weight: "bold")[Dispatch p99 < 2 s] from request to driver offer \
      #text(weight: "bold")[Location ingest: 1M concurrent drivers] \
      Availability #text(weight: "bold")[99.99%] for dispatch and trips \
      Payments: #text(weight: "bold")[exactly-once effect], RPO = 0 \
      Trip history retained 7 years (regulatory)]
  ])
#v(1.5mm)

#text(size: 8.8pt)[
  #text(fill: purple, weight: "bold")[The consistency split that shapes everything:] driver
  location is #text(fill: green)[eventually consistent and disposable] (a 3-second-old position is
  useless anyway), while trip state and payments are
  #text(fill: red)[linearizable and durable]. Two subsystems, two different guarantees, two
  different stores. Conflating them is the primary design error here.
]
#v(2mm)

#h2("2 · Capacity estimation", c: orange)

#formula("Sizing from first principles")[
  #text(size: 8.5pt)[
    #text(weight: "bold")[Location ingest.] 1M concurrent drivers. Naive 1 Hz =
    #text(fill: red, weight: "bold")[1M writes/s].
    Adaptive (M15): 4 s moving / 30 s idle, 30% moving #sym.arrow.r
    (300,000/4) + (700,000/30) = #text(fill: green, weight: "bold")[98,000 writes/s].
    #linebreak()
    State: 1M × 100 B = #text(weight: "bold")[100 MB] in Redis — trivially replicated.
    History to Kafka: 98,000 × 100 B = 9.8 MB/s =
    #text(weight: "bold")[846 GB/day] raw, ~85 GB/day compressed columnar.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Dispatch.] 2M trips/day peak-concentrated: 2,000,000 / 86,400 × 3
    (peak factor) = #text(fill: orange, weight: "bold")[~70 dispatches/s].
    Each scans ~9 H3 cells × ~50 candidate drivers =
    #text(weight: "bold")[3,500 candidate evaluations/s] — small, because the
    #underline(stroke: 1pt + green)[spatial index does the filtering].
    #linebreak() #v(1mm)
    #text(weight: "bold")[Rider map updates.] 200k concurrent riders watching a driver, 1 update/s
    = #text(fill: orange, weight: "bold")[200k WebSocket pushes/s] at ~80 B =
    16 MB/s. This, not dispatch, is the connection-fleet load (M10).
    #linebreak() #v(1mm)
    #text(weight: "bold")[Storage, 7-year retention.] 2M trips/day × 365 × 7 =
    #text(weight: "bold")[5.1B trip records] × 2 KB = #text(fill: orange, weight: "bold")[10 TB]
    — modest. Telemetry at 85 GB/day × 2,555 days =
    #text(fill: red, weight: "bold")[217 TB], tiered to cold storage after 90 days (M30).
  ]
]
#v(2mm)

#h2("3 · Topology", c: blue)

#pfig("Fig CS1.1 · topology — two subsystems, two consistency guarantees, two stores")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  swimlane(-0.4, -1.1, 20.4, 2.1, "EDGE", blue, rgb("#f4f8fd"))
  rnode(2.6, 0.5, "dr", "driver app", "batched pings", purple, w: 3.6, h: 0.9)
  rnode(9.6, 0.5, "ri", "rider app", "WebSocket", purple, w: 3.2, h: 0.9)
  rnode(16.8, 0.5, "gw", "gateway / conn fleet", "Envoy + WS gateways", blue, w: 5.8, h: 0.9)
  line("dr.east", (5.2, 0.5), (5.2, 1.5), (16.8, 1.5), "gw.north",
    mark: (end: ">"), stroke: hot)
  line("ri.east", "gw.west", mark: (end: ">"), stroke: hot)
  badge(6.8, 1.5, "1", green)
  plabel(10.4, 1.5, "10 fixes · 1 KB · HTTP/3", c: green, dy: 0.28)
  badge(13.1, 0.5, "2", green)
  plabel(13.1, 0.5, "ride request", c: green, dy: 0.48)

  swimlane(-0.4, -5.1, 20.4, -1.6, "SERVICE", green, rgb("#f6fbf7"))
  rnode(2.9, -2.6, "loc", "location svc", "H3 index · Redis", green, w: 4.2, h: 0.9)
  rnode(8.5, -2.6, "dis", "dispatch svc", "scoring + offer", green, w: 4.0, h: 0.9)
  rnode(13.9, -2.6, "trip", "trip svc", "state machine", green, w: 3.8, h: 0.9)
  rnode(18.7, -2.6, "pay", "payment svc", "idempotent (S4)", red, w: 3.2, h: 0.9)
  line("gw.south", (16.8, -1.9), (2.9, -1.9), "loc.north", mark: (end: ">"), stroke: hot)
  line("loc.east", "dis.west", mark: (end: ">"), stroke: lookup)
  line("dis.east", "trip.west", mark: (end: ">"), stroke: hot)
  line("trip.east", "pay.west", mark: (end: ">"), stroke: hot)
  badge(5.7, -2.6, "3", green)
  plabel(5.7, -2.6, "~9 cells · 50 drivers", c: green, dy: -0.72)
  badge(11.2, -2.6, "4", green)
  plabel(11.2, -2.6, "offer accepted", c: green, dy: -0.72)
  badge(16.5, -2.6, "5", red)
  plabel(16.5, -2.6, "on complete", c: red, dy: -0.72)
  rnode(14.6, -4.4, "surge", "surge pricing", "streaming agg", orange, w: 4.2, h: 0.85)
  line((2.9, -3.05), (2.9, -4.4), "surge.west", mark: (end: ">"), stroke: async)
  plabel(7.6, -4.4, "demand / supply signal", c: purple, dy: 0.32)

  swimlane(-0.4, -8.2, 20.4, -5.6, "STORAGE", orange, rgb("#fdf7f2"))
  rnode(2.9, -7.0, "rd", "Redis", "live positions · TTL 60 s", green, w: 4.4, h: 0.85)
  cylinder(9.0, -7.0, "pg", "Postgres — trips", orange, w: 4.4, h: 1.0)
  rnode(14.2, -7.0, "kf", "Kafka", "telemetry + outbox", purple, w: 3.8, h: 0.85)
  cylinder(19.0, -7.0, "ch", "ClickHouse", purple, w: 3.2, h: 1.0)
  line((2.9, -4.83), (2.9, -5.9), "rd.north", mark: (end: ">"), stroke: hot)
  line("trip.south", (13.9, -5.9), (9.0, -5.9), "pg.north", mark: (end: ">"), stroke: hot)
  line("kf.east", "ch.west", mark: (end: ">"), stroke: async)
  plabel(11.4, -5.9, "shard by city_id", c: green, dy: 0.26)
  plabel(17.3, -7.0, "columnar", c: purple, dy: 0.62)
  bracket(0.4, 20.0, -8.6, "dispatch path budget: 2,000 ms — of which scoring is ~200 ms", purple)
}))
#pcards(
  [Driver positions in Redis with a 60 s TTL; trips sharded by `city_id`; outbox on the trip table.],
  [In: batched GPS fixes, ride requests. Out: driver offers, 1 Hz rider map pushes, ledger entries.],
  [Envoy + WS gateways · Redis (H3 ZSETs) · Postgres · Kafka · ClickHouse],
)
#v(2mm)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[The one path that defines the system] is the dispatch path —
  rider request to driver offer, inside 2 seconds. It is the only path where a
  #underline(stroke: 1pt + green)[late answer is a wrong answer], because the candidate driver has
  physically moved on. Everything else in the design exists to keep this path short.
]
#v(1.5mm)

#pfig("Fig CS1.2 · the dispatch critical path — request to accepted offer, p99 budget 2,000 ms")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.2, 20.2, 2.5,
    "driver positions fresh in Redis (TTL 60 s) · driver status = available · surge multiplier published")

  // ---- row 1: request → candidate selection
  ppill(2.0, 0, "in", "rider taps REQUEST", w: 3.6)
  pstep(7.4, 0, "a", "authenticate", "Envoy · ~20 ms", st-integ, n: 1, actor: "gateway", w: 3.8)
  pstep(13.4, 0, "b", "H3 ring lookup", "~9 cells · Redis 1 ms", st-auto, n: 2, actor: "location svc", w: 4.4)
  pstep(18.6, 0, "c", "score", "~200 ms", st-auto, n: 3, actor: "dispatch svc", w: 2.8)

  line("in.east", "a.west", mark: (end: ">"), stroke: hot)
  line("a.east", "b.west", mark: (end: ">"), stroke: hot)
  plabel(10.3, 0, "pickup H3 cell", c: green, dy: 0.72)
  line("b.east", "c.west", mark: (end: ">"), stroke: lookup)

  // ---- wrap to row 2
  line("c.south", (18.6, -2.0), (2.2, -2.0), (2.2, -3.1),
    mark: (end: ">"), stroke: wrap)
  plabel(10.4, -2.0, "~50 candidates, best-scored first", c: luma(110), dy: 0.28)

  // ---- row 2: decision → offer → trip
  pdec(2.2, -4.5, "d1", "any candidate\nin range?", w: 2.2)
  pstep(7.2, -4.5, "e", "send offer", "push · 15 s timer", st-integ, n: 4, actor: "driver app", w: 3.8)
  pdec(12.4, -4.5, "d2", "accepted\nin 15 s?", w: 2.0)
  pstep(17.6, -4.5, "f", "atomic accept", "WHERE status='offered'", st-auto, n: 5, actor: "trip svc", w: 4.6)

  line("d1.east", "e.west", mark: (end: ">"), stroke: hot)
  plabel(4.6, -4.5, "yes", c: green, dy: 0.34)
  line("e.east", "d2.west", mark: (end: ">"), stroke: hot)
  line("d2.east", "f.west", mark: (end: ">"), stroke: hot)
  plabel(14.0, -4.5, "yes", c: green, dy: 0.34)

  // ---- re-dispatch rail: a timeout returns the offer to the next candidate
  ploop("d2.south", "e.south", -6.3, "timeout or decline → next candidate (an offer, never an assignment)")

  // ---- wrap to row 3
  line("f.south", (17.6, -7.6), (3.2, -7.6), (3.2, -8.5),
    mark: (end: ">"), stroke: wrap)
  plabel(11.0, -7.6, "trip_id issued — now, and only now, the ride is assigned", c: luma(110), dy: 0.28)

  // ---- row 3: rider gets the map; the exception sinks beside it
  pstep(3.2, -9.8, "g", "push to rider", "WebSocket · 1 Hz", st-man, n: 6, actor: "rider app", w: 4.0)
  ppill(9.0, -9.8, "out", "driver en route", c: green, w: 3.4)
  line("g.east", "out.west", mark: (end: ">"), stroke: hot)

  pstep(17.0, -9.8, "x", "no cars available", "show surge + retry", st-dec, n: 0, actor: "rider app", w: 4.4)
  line("d1.west", (0.3, -4.5), (0.3, -11.6), (17.0, -11.6), "x.south",
    mark: (end: ">"), stroke: except)
  plabel(8.6, -11.6, "no candidate in range — fail fast and honestly", c: red, dy: 0.28)
}))
#pcards(
  [Fresh positions in Redis, driver marked available, surge multiplier already computed from the
   streaming aggregate.],
  [In: rider pickup location. Out: a 15-second *offer* to one driver, then a `trip_id` and live
   tracking. Nothing is assigned until the atomic accept succeeds.],
  [Envoy · H3 + Redis ZSET · dispatch scorer · Postgres conditional update · WS push],
)
#v(2mm)

#h2("4 · Data model & partition keys", c: purple)

#table(
  columns: (auto, auto, 1fr, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#f5eefa") } else { none },
  text(font: headfont, size: 8.4pt, fill: purple)[Entity],
  text(font: headfont, size: 8.4pt, fill: purple)[Store],
  text(font: headfont, size: 8.4pt, fill: purple)[Key / index],
  text(font: headfont, size: 8.4pt, fill: purple)[Why],

  text(size: 8.2pt)[Driver position],
  text(size: 8.2pt)[Redis],
  text(size: 8pt)[`geo:{h3_r8}` → ZSET of driver ids; TTL 60 s],
  text(size: 8pt)[Cell lookup + auto-expiry on disconnect],

  text(size: 8.2pt)[Driver state],
  text(size: 8.2pt)[Redis],
  text(size: 8pt)[`driver:{id}` → hash (status, trip, rating)],
  text(size: 8pt)[Single-key read in dispatch],

  text(size: 8.2pt)[Trip],
  text(size: 8.2pt)[Postgres],
  text(size: 8pt)[PK `trip_id` (UUIDv7); shard by `city_id`],
  text(size: 8pt)[Trips never cross cities — natural partition],

  text(size: 8.2pt)[Ledger entry],
  text(size: 8.2pt)[Postgres],
  text(size: 8pt)[Append-only; `(account_id, created_at)`],
  text(size: 8pt)[Double-entry, immutable (CS3)],

  text(size: 8.2pt)[Telemetry],
  text(size: 8.2pt)[ClickHouse],
  text(size: 8pt)[Partition by day, order by `(city, driver, ts)`],
  text(size: 8pt)[Columnar scans for analytics (M36)],
)
#v(1.5mm)

#text(size: 8.8pt)[
  #text(fill: purple, weight: "bold")[`city_id` is the shard key, and it is the most important
  decision in the design.] Rides are geographically bounded — a trip's rider, driver, pricing and
  settlement all live in one city. Sharding by city gives
  #underline(stroke: 1pt + green)[single-shard transactions for the entire trip lifecycle], makes
  regional data sovereignty straightforward (M31), and allows per-city scaling.
  #note[The known weakness: cities are wildly unequal, so one shard may carry fifty times another
  (M28). Large cities get dedicated shards; the long tail is pooled.]
]
#v(2mm)

#h2("5 · Client & edge contracts", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Driver → server (location).] HTTP/3 (M21), batched: 10 fixes
  per transmission, ~1 KB, every 10–40 s depending on movement. Fire-and-forget — a lost batch is
  irrelevant because the next supersedes it. #underline(stroke: 1pt + green)[Never retry location
  data]; retrying stale positions is worse than dropping them.

  #text(fill: green, weight: "bold")[Server → rider (tracking).] WebSocket, server-pushed at
  1 Hz while a trip is active, ~80 B per update. Falls back to 3-second polling if the socket
  cannot establish. Connection migration (QUIC) matters here: a rider walking from Wi-Fi to
  cellular must not lose the map.

  #text(fill: red, weight: "bold")[Trip state transitions.] Request/response with an
  #text(weight: "bold")[idempotency key per transition] (S4), retried with full jitter up to 30 s.
  "Accept ride" must be exactly-once in effect — two drivers accepting the same ride is the
  failure that cannot happen.

  #text(fill: orange, weight: "bold")[Offline resilience (the driver app).] Trip state is
  journaled locally. A driver who completes a trip in a tunnel queues the completion and syncs on
  reconnect (M12), with the server reconciling by idempotency key. The app must function for the
  whole trip with #underline(stroke: 1pt + green)[zero connectivity] and settle afterwards.
]
#v(2mm)

#h2("6 · Failure modes", c: red)

#text(size: 8.8pt)[
  #text(fill: red, weight: "bold")[Double-accept.] Two drivers accept the same ride.
  #text(fill: green)[Fix:] atomic conditional update on trip state (`WHERE status = 'offered'`)
  — the second accept affects zero rows and that driver is told immediately (M22).
]
#v(1.5mm)

#pfig("Fig CS1.3 · failure response — two drivers accept the same ride")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.2, 20.2, 2.5,
    "trip row holds status='offered' · every accept carries an idempotency key per transition (S4)")

  // ---- row 1: both accepts hit one row; the lock picks a winner
  ppill(2.2, 0, "in", "two accepts arrive", c: red, w: 4.0)
  pstep(8.2, 0, "a", "conditional UPDATE", "WHERE status='offered'", st-auto, n: 1,
    actor: "trip svc", w: 4.8)
  pdec(13.6, 0, "d", "rows\naffected = 1?", w: 2.2)
  pstep(18.4, 0, "b", "trip assigned", "status → 'accepted'", st-auto, n: 2,
    actor: "trip svc", w: 4.2)

  line("in.east", "a.west", mark: (end: ">"), stroke: miss)
  line("a.east", "d.west", mark: (end: ">"), stroke: hot)
  plabel(11.9, 0, "serialised by the row lock", c: green, dy: 1.42)
  line("d.east", "b.west", mark: (end: ">"), stroke: hot)
  plabel(15.4, 0, "winner", c: green, dy: 0.74)

  // ---- the loser: detection → mitigation → recovery, one row down
  line("d.south", (13.6, -2.2), (2.6, -2.2), (2.6, -3.1), mark: (end: ">"), stroke: except)
  plabel(8.6, -2.2, "0 rows affected — this driver lost, and nothing threw", c: red, dy: 0.28)

  pstep(2.6, -4.4, "c", "detect: 0 rows", "the return value is the signal", st-dec, n: 3,
    actor: "trip svc", w: 4.4)
  pstep(8.6, -4.4, "e", "tell driver now", "\"ride taken\" · no penalty", st-man, n: 4,
    actor: "driver app", w: 4.6)
  pstep(14.6, -4.4, "f", "return to pool", "status → available", st-auto, n: 5,
    actor: "location svc", w: 4.4)
  pstep(19.0, -4.4, "g", "re-eligible", "next cycle", st-auto, n: 6, actor: "dispatch", w: 3.6)

  line("c.east", "e.west", mark: (end: ">"), stroke: except)
  line("e.east", "f.west", mark: (end: ">"), stroke: hot)
  plabel(11.9, -4.4, "released", c: green, dy: 0.34)
  line("f.east", "g.west", mark: (end: ">"), stroke: hot)

  // ---- recovery rail back to the start: the loser re-enters dispatch unaided
  ploop("g.south", "a.south", -6.6, "recovered automatically — no on-call, no rider impact")

  ppill(9.0, -8.6, "out", "one ride, exactly one driver", c: green, w: 7.0)
  line("b.east", (21.2, 0), (21.2, -8.6), "out.east", mark: (end: ">"), stroke: hot)
}))
#pcards(
  [`status='offered'` is the only state an accept may transition from; the row lock does the
   serialising, so no distributed lock is needed.],
  [In: two concurrent accept calls. Out: exactly one `trip_id`, and an immediate honest
   "ride taken" for the loser — never a silent timeout.],
  [Postgres conditional UPDATE (M22) · idempotency keys (S4) · Redis driver-status hash],
)
#v(2mm)

#text(size: 8.8pt)[
  #text(fill: red, weight: "bold")[Dispatch to a driver who just went offline.] Location TTL has
  not yet expired. #text(fill: green)[Fix:] the offer has a 15-second acceptance timeout; on
  expiry, re-dispatch to the next candidate. Treat dispatch as
  #underline(stroke: 1pt + green)[an offer, never an assignment].

  #text(fill: red, weight: "bold")[Surge feedback loop.] Surge raises prices, which attracts
  drivers, which lowers surge, which sends them away — oscillation.
  #text(fill: green)[Fix:] damping and hysteresis on the pricing signal; rate-limit how fast
  multipliers move.

  #text(fill: red, weight: "bold")[GPS drift in urban canyons.] A driver appears to jump
  200 metres. #text(fill: green)[Fix:] client-side smoothing plus server-side plausibility checks
  (speed limits), and dead-reckoning through gaps (M15).

  #text(fill: red, weight: "bold")[Payment at trip end fails.] #text(fill: green)[Fix:] the trip
  completes regardless; payment is a saga with retries and compensations (M4). Never block trip
  completion on the payment processor — the rider has already left the car.
]
#v(2mm)

#h2("7 · Delivery roadmap", c: purple)

#text(size: 8.8pt)[
  #text(fill: purple, weight: "bold")[Team topology.] Four stream-aligned teams —
  #text(weight: "bold")[Marketplace] (location, dispatch, surge),
  #text(weight: "bold")[Trips] (lifecycle, state machine),
  #text(weight: "bold")[Money] (payments, ledger, payouts),
  #text(weight: "bold")[Client Platform] (driver/rider apps, offline, connectivity) — on a
  #text(weight: "bold")[Platform] team owning the connection fleet, event bus and observability.
  Conway's law applies: these boundaries become your service boundaries, so draw them to match the
  consistency boundaries above.

  #text(fill: purple, weight: "bold")[Phasing.]
  #text(weight: "bold")[M0–M3:] one city, synchronous dispatch, no surge — prove the trip
  lifecycle end to end.
  #text(weight: "bold")[M4–M6:] H3 indexing, telemetry pipeline, surge; scale to ten cities.
  #text(weight: "bold")[M7–M9:] multi-region, offline-first driver app, payments hardening.
  #text(weight: "bold")[M10–M12:] global rollout, per-city sharding, cost optimisation.
  #underline(stroke: 1pt + green)[City-by-city rollout is itself the blast-radius strategy] — each
  new city is a canary.

  #text(fill: purple, weight: "bold")[SLO targets.] Dispatch p99 < 2 s · dispatch availability
  99.99% · location freshness p99 < 10 s · trip-state write success 99.995% ·
  payment exactly-once effect #text(weight: "bold")[100%] (any violation is a P1).

  #text(fill: purple, weight: "bold")[The hardest conversation.] Marketplace quality (match rate,
  ETA accuracy) is a #underline(stroke: 1pt + green)[data science problem], not an infrastructure
  one. Engineering owns the latency and reliability budget; the matching algorithm belongs to a
  separate team with its own experimentation cadence. Confusing the two produces a platform that
  is fast and matches badly, with nobody accountable for the second.
]
