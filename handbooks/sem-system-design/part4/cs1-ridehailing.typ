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

#align(center, cetz.canvas(length: 0.78cm, {
  import cetz.draw: *
  swimlane(-0.4, -0.9, 19.0, 2.0, "EDGE", blue, rgb("#f4f8fd"))
  rnode(2.6, 0.7, "dr", "driver app", "batched pings", purple, w: 3.4, h: 0.85)
  rnode(7.4, 0.7, "ri", "rider app", "WebSocket", purple, w: 3.0, h: 0.85)
  rnode(13.0, 0.7, "gw", "gateway / conn fleet", "Envoy + WS gateways", blue, w: 5.6, h: 0.85)
  line("dr.east", "gw.west", mark: (end: ">"), stroke: hot)
  line("ri.east", "gw.west", mark: (end: ">"), stroke: hot)

  swimlane(-0.4, -4.6, 19.0, -1.3, "SERVICE", green, rgb("#f6fbf7"))
  rnode(2.8, -2.3, "loc", "location svc", "H3 index · Redis", green, w: 4.0, h: 0.85)
  rnode(7.8, -2.3, "dis", "dispatch svc", "scoring + offer", green, w: 3.8, h: 0.85)
  rnode(12.6, -2.3, "trip", "trip svc", "state machine", green, w: 3.6, h: 0.85)
  rnode(17.0, -2.3, "pay", "payment svc", "idempotent (S4)", red, w: 3.2, h: 0.85)
  line("gw.south", (13.0, -1.6), (2.8, -1.6), "loc.north", mark: (end: ">"), stroke: hot)
  line("loc.east", "dis.west", mark: (end: ">"), stroke: lookup)
  line("dis.east", "trip.west", mark: (end: ">"), stroke: hot)
  line("trip.east", "pay.west", mark: (end: ">"), stroke: hot)
  rnode(5.2, -3.9, "surge", "surge pricing", "streaming agg", orange, w: 4.0, h: 0.8)
  line("loc.south", "surge.north", mark: (end: ">"), stroke: async)

  swimlane(-0.4, -7.4, 19.0, -5.0, "STORAGE", orange, rgb("#fdf7f2"))
  rnode(2.8, -6.2, "rd", "Redis", "live positions", green, w: 3.2, h: 0.8)
  cylinder(7.6, -6.2, "pg", "Postgres — trips", orange, w: 4.2, h: 0.95)
  rnode(12.6, -6.2, "kf", "Kafka", "telemetry + outbox", purple, w: 3.6, h: 0.8)
  cylinder(17.0, -6.2, "ch", "ClickHouse", purple, w: 3.2, h: 0.95)
  line("loc.south", (2.8, -5.2), "rd.north", mark: (end: ">"), stroke: hot)
  line("trip.south", (12.6, -5.2), (7.6, -5.2), "pg.north", mark: (end: ">"), stroke: hot)
  line("kf.east", "ch.west", mark: (end: ">"), stroke: async)
  bracket(0.6, 18.0, -7.8, "dispatch path budget: 2,000 ms — of which scoring is ~200 ms", purple)
}))
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
