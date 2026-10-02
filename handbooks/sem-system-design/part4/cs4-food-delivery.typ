#import "/shared/lib/template.typ": *
#ix("Food delivery platform")
#ix("Three-sided marketplace")
#ix("Dispatch")
#reg(1, "CS4", "Food Delivery Ecosystem (Zomato / Swiggy scale)")
#chapterhead("Part 4 · Case Studies", "CS4 · Food Delivery Ecosystem")

#h1("CS4 · Food Delivery Ecosystem", c: orange)

#text[
  Zomato / Swiggy / DoorDash scale. This is the hardest case study in the book because it is a
  #underline(stroke: 1pt + red)[three-sided marketplace] — customer, restaurant, rider — where all
  three sides are live simultaneously, the inventory is perishable, the supply is human, and a
  decision made at order time constrains a physical outcome forty minutes later.
]
#v(2mm)

#h2("1 · Requirements", c: blue)

#grid(columns: (1fr, 1fr), gutter: 4mm,
  block(inset: 2.5mm, radius: 2pt, fill: rgb("#eef7f1"), stroke: (left: 2pt + green))[
    #text(size: 8.3pt)[#text(fill: green, weight: "bold")[Functional — three apps] \
      #text(weight: "bold")[Customer:] discover, search, cart, pay, track \
      #text(weight: "bold")[Restaurant:] accept/reject, prep time, menu, stock-out \
      #text(weight: "bold")[Rider:] assignment, navigation, batching, proof of delivery \
      Dynamic ETA; surge; promotions; ratings; refunds]
  ],
  block(inset: 2.5mm, radius: 2pt, fill: rgb("#f4f8fd"), stroke: (left: 2pt + blue))[
    #text(size: 8.3pt)[#text(fill: blue, weight: "bold")[Non-functional] \
      #text(weight: "bold")[20M DAU], 2M orders/day, peak 8× at 8pm \
      Search p99 < 200 ms · checkout p99 < 1 s \
      #text(weight: "bold")[Dispatch decision < 3 s] of restaurant accept \
      Payments: exactly-once, RPO = 0 \
      Menu/price correctness: #text(weight: "bold")[absolute]]
  ])
#v(1.5mm)

#text(size: 8.7pt)[
  #text(fill: purple, weight: "bold")[The constraint that shapes everything:] demand is
  #underline(stroke: 1pt + red)[extraordinarily peaked]. 2M orders/day is 23/s averaged, but
  roughly 45% land in the 19:00–21:30 dinner window — so peak is
  #text(fill: red, weight: "bold")[~8× average], every single day, predictably. Unlike a flash
  sale (CS3) this is not an event you prepare for once; it is the
  #text(fill: green)[normal operating condition] twice daily, which argues for scheduled
  pre-scaling rather than reactive autoscaling (M25).
]
#v(2mm)

#h2("2 · Capacity estimation", c: orange)

#formula("Sizing the three sides")[
  #text(size: 8.4pt)[
    #text(weight: "bold")[Orders.] 2,000,000/day ÷ 86,400 = #text(weight: "bold")[23/s] average.
    Dinner peak ≈ 45% of orders in 2.5 h: 900,000 ÷ 9,000 s =
    #text(fill: red, weight: "bold")[100 orders/s sustained], bursting to ~160/s.
    #linebreak() #v(0.8mm)
    #text(weight: "bold")[Search & browse.] Each order follows ~25 catalogue reads
    #sym.arrow.r 100 × 25 = #text(fill: orange, weight: "bold")[2,500 QPS] at peak on the
    discovery path. #underline(stroke: 1pt + green)[Reads outnumber writes ~100:1] — this is a
    caching problem (M5), not a database problem.
    #linebreak() #v(0.8mm)
    #text(weight: "bold")[Live tracking.] ~250,000 in-flight orders at peak, each pushing a
    location update every 4 s #sym.arrow.r 250,000 ÷ 4 =
    #text(fill: red, weight: "bold")[62,500 pushes/s] over WebSocket (M10). This, not order
    placement, is the largest sustained load in the system.
    #linebreak() #v(0.8mm)
    #text(weight: "bold")[Rider telemetry.] 150,000 online riders, adaptive 4 s moving / 30 s idle,
    40% moving: (60,000÷4) + (90,000÷30) =
    #text(fill: orange, weight: "bold")[18,000 writes/s] to the geo index (M15).
    #linebreak() #v(0.8mm)
    #text(weight: "bold")[Storage.] Orders: 2M/day × 4 KB × 365 × 7 yr =
    #text(weight: "bold")[20 TB]. Menu catalogue: 500k restaurants × 200 items × 2 KB =
    #text(fill: green, weight: "bold")[200 GB] — small enough to cache aggressively in full.
    Telemetry: 18,000/s × 100 B × 86,400 = 155 GB/day raw, tiered after 90 days (M30).
  ]
]
#v(2mm)

#h2("3 · Complete system topology", c: blue)

#align(center, cetz.canvas(length: 0.62cm, {
  import cetz.draw: *

  // ---------------- CLIENTS ----------------
  swimlane(-0.4, 7.4, 25.6, 9.8, "CLIENT TIER — three apps, three very different needs", purple,
    rgb("#f5eefa"))
  rnode(3.2, 8.6, "cust", "Customer app", "iOS/Android/web", purple, w: 4.6, h: 1.0)
  rnode(9.6, 8.6, "rest", "Restaurant tablet", "always-on, POS link", purple, w: 5.2, h: 1.0)
  rnode(16.4, 8.6, "ridr", "Rider app", "offline-first (M12)", purple, w: 5.0, h: 1.0)
  rnode(22.4, 8.6, "ops", "Ops console", "internal", luma(120), w: 3.6, h: 1.0)

  // ---------------- EDGE ----------------
  swimlane(-0.4, 4.6, 25.6, 7.0, "EDGE", blue, rgb("#f4f8fd"))
  rnode(3.2, 5.8, "cdn", "CDN", "menu images, static", blue, w: 4.6, h: 0.95)
  rnode(9.0, 5.8, "gw", "API Gateway", "Envoy · authn · rate limit", blue, w: 5.4, h: 0.95)
  rnode(15.4, 5.8, "ws", "WS gateway fleet", "250k conns · 15 nodes", blue, w: 5.6, h: 0.95)
  rnode(21.8, 5.8, "bff", "BFF per client", "payload shaping (M6)", blue, w: 4.8, h: 0.95)
  edge("cust.south", "cdn.north", "", green)
  edge("cust.south", "gw.north", "", green)
  edge("rest.south", "gw.north", "", green)
  edge("ridr.south", "ws.north", "", green)
  edge("cust.south", "ws.north", "", green, kind: "dash")
  edge("ops.south", "bff.north", "", blue)

  // ---------------- CORE SERVICES ----------------
  swimlane(-0.4, 0.4, 25.6, 4.2, "CORE SERVICES", green, rgb("#f6fbf7"))
  rnode(2.6, 3.1, "disc", "Discovery", "search + ranking", green, w: 4.2, h: 0.9)
  rnode(7.6, 3.1, "cat", "Catalogue", "menu, price, stock", green, w: 4.2, h: 0.9)
  rnode(12.6, 3.1, "cart", "Cart & Pricing", "promo, tax, fees", green, w: 4.4, h: 0.9)
  rnode(17.8, 3.1, "ordr", "Order svc", "state machine", red, w: 4.0, h: 0.9)
  rnode(22.6, 3.1, "pay", "Payments", "idempotent (S4)", red, w: 4.0, h: 0.9)
  rnode(2.6, 1.3, "disp", "Dispatch", "rider matching", orange, w: 4.2, h: 0.9)
  rnode(7.6, 1.3, "geo", "Geo / ETA", "H3 + routing (M15)", orange, w: 4.6, h: 0.9)
  rnode(12.8, 1.3, "trk", "Tracking", "live position fan-out", orange, w: 4.6, h: 0.9)
  rnode(18.0, 1.3, "notif", "Notifications", "push/SMS (M11)", purple, w: 4.2, h: 0.9)
  rnode(22.8, 1.3, "supp", "Support & refunds", "saga (M4)", purple, w: 4.4, h: 0.9)

  edge("gw.south", "disc.north", "", green)
  edge("gw.south", "cat.north", "", green)
  edge("gw.south", "cart.north", "", green)
  edge("gw.south", "ordr.north", "", green)
  edge("ws.south", "trk.north", "", green)
  edge("bff.south", "supp.north", "", blue)
  edge("cart.east", "ordr.west", "", green)
  edge("ordr.east", "pay.west", "", red)
  edge("ordr.south", "disp.north", "", orange, kind: "dash")
  edge("disp.east", "geo.west", "", orange)
  edge("geo.east", "trk.west", "", orange)
  edge("ordr.south", "notif.north", "", purple, kind: "dash")

  // ---------------- DATA ----------------
  swimlane(-0.4, -4.4, 25.6, -0.2, "DATA & STREAMING", orange, rgb("#fdf7f2"))
  cylinder(2.6, -1.4, "pgo", "Orders PG", orange, w: 4.0, h: 1.0)
  cylinder(7.4, -1.4, "pgc", "Catalogue PG", orange, w: 4.2, h: 1.0)
  cylinder(12.4, -1.4, "led", "Ledger PG", red, w: 4.0, h: 1.0)
  rnode(17.2, -1.4, "rds", "Redis", "geo · cart · cache", green, w: 4.2, h: 0.9)
  rnode(22.4, -1.4, "es", "Elasticsearch", "discovery index", green, w: 4.4, h: 0.9)
  queue(6.0, -3.4, "kfk", "Kafka — order events, telemetry, outbox (M9)", purple, w: 11.0, h: 0.9)
  cylinder(16.4, -3.4, "ch", "ClickHouse", purple, w: 4.2, h: 1.0)
  cylinder(21.6, -3.4, "s3", "S3 — images, invoices", purple, w: 5.2, h: 1.0)

  edge("ordr.south", "pgo.north", "", green)
  edge("cat.south", "pgc.north", "", green)
  edge("pay.south", "led.north", "", red)
  edge("geo.south", "rds.north", "", green)
  edge("disc.south", "es.north", "", green)
  edge("pgo.south", "kfk.north", "", purple, kind: "dash")
  edge("kfk.east", "ch.west", "", purple, kind: "dash")
  edge("pgc.south", "kfk.north", "", purple, kind: "dot")

  bracket(0.2, 24.8, -4.8,
    "checkout budget 1,000 ms  ·  dispatch decision 3,000 ms  ·  tracking push 250 ms", purple)
}))
#v(2mm)

#text(size: 8.7pt)[
  #text(fill: purple, weight: "bold")[Reading the topology.] Three client types enter through
  different edges because their needs differ fundamentally: the customer app is read-heavy and
  cacheable, the restaurant tablet is a #underline(stroke: 1pt + green)[long-lived
  low-volume connection] that must never miss an order, and the rider app is offline-first on a
  phone in a pocket on a motorbike. A single shared gateway path would force the worst-case
  requirements of all three onto each.
  #note[Catalogue and Orders are separate databases with separate scaling profiles — catalogue is
  200 GB read-mostly and belongs behind an aggressive cache; orders is write-heavy, sharded by
  city, and never cached. Merging them, which teams do for convenience, couples a read spike on
  menus to write latency on checkout.]
]
#v(2mm)

#h2("4 · The order lifecycle, as a flow", c: green)

#align(center, cetz.canvas(length: 0.62cm, {
  import cetz.draw: *
  terminal(2.4, 7.2, "t0", "customer taps PAY", green, w: 5.0, h: 0.9)
  io(8.6, 7.2, "in", "cart + address + payment token", blue, w: 7.0, h: 0.9)
  rnode(16.4, 7.2, "val", "validate cart", "re-price server-side", green, w: 4.6, h: 0.9)
  edge("t0.east", "in.west", "", green)
  edge("in.east", "val.west", "", green)

  decision(3.0, 4.8, "d1", "menu still\nvalid?", orange, w: 3.6, h: 1.7)
  edge("val.south", "d1.north", "", green)
  rnode(8.4, 4.8, "auth", "authorise payment", "hold, not capture", red, w: 4.8, h: 0.9)
  terminal(3.0, 2.4, "x1", "reject: item unavailable", red, w: 5.6, h: 0.85)
  edge("d1.south", "x1.north", "", red)
  edge("d1.east", "auth.west", "", green)
  content((5.6, 5.2), dlbl("yes", sz: 6pt, c: green))
  content((1.5, 3.6), dlbl("no", sz: 6pt, c: red))

  rnode(14.6, 4.8, "place", "persist order", "+ outbox event (M9)", green, w: 5.0, h: 0.9)
  edge("auth.east", "place.west", "", green)
  queue(21.0, 4.8, "q1", "order.placed", purple, w: 4.4, h: 0.85)
  edge("place.east", "q1.west", "", purple)

  rnode(3.4, 0.6, "rpush", "notify restaurant", "push + tablet chime", purple, w: 5.0, h: 0.9)
  route(("q1.south", (21.0, 2.0), (3.4, 2.0), "rpush.north"), purple, kind: "dash")
  decision(10.2, 0.6, "d2", "accepted\nin 90 s?", orange, w: 3.8, h: 1.7)
  edge("rpush.east", "d2.west", "", green)
  terminal(10.2, -1.9, "x2", "auto-cancel + full refund", red, w: 6.0, h: 0.85)
  edge("d2.south", "x2.north", "", red)
  content((8.0, -0.9), dlbl("no", sz: 6pt, c: red))

  rnode(16.6, 0.6, "disp", "dispatch rider", "score by ETA + batching", orange, w: 5.4, h: 0.9)
  edge("d2.east", "disp.west", "", green)
  content((13.6, 1.0), dlbl("yes", sz: 6pt, c: green))
  rnode(22.6, 0.6, "cook", "prep + pickup", "status pushed live", green, w: 4.4, h: 0.9)
  edge("disp.east", "cook.west", "", green)

  rnode(4.0, -3.6, "deliv", "deliver + PoD", "OTP or photo", green, w: 4.8, h: 0.9)
  route(("cook.south", (22.6, -2.4), (4.0, -2.4), "deliv.north"), green)
  rnode(10.8, -3.6, "cap", "capture payment", "idempotency key", red, w: 4.8, h: 0.9)
  edge("deliv.east", "cap.west", "", red)
  rnode(16.8, -3.6, "settle", "ledger postings", "double-entry (CS3)", red, w: 5.0, h: 0.9)
  edge("cap.east", "settle.west", "", red)
  terminal(22.4, -3.6, "end", "DONE", green, w: 3.2, h: 0.85)
  edge("settle.east", "end.west", "", green)

  bracket(0.2, 24.8, -4.6, "payment is AUTHORISED at placement, CAPTURED at delivery — never before", purple)
}))
#v(2mm)

#key[
  #text(fill: green, weight: "bold")[Authorise early, capture late.] The hold is placed before the
  restaurant is told, so a customer with a failing card never reaches the kitchen; capture happens
  only on delivery, so a cancelled or undelivered order needs a
  #underline(stroke: 1pt + green)[void, not a refund]. Voids are instant and free; refunds take
  days and generate support tickets. This single sequencing decision removes a large fraction of
  the operational load from a food-delivery business.
]
#v(2mm)

#h2("5 · Dispatch — the algorithmic core", c: orange)

#align(center, cetz.canvas(length: 0.62cm, {
  import cetz.draw: *
  swimlane(-0.4, 1.4, 25.6, 4.0, "DISPATCH PIPELINE — runs every 2 s per city", orange, rgb("#fdf7f2"))
  io(3.0, 2.7, "pend", "pending orders (city)", blue, w: 5.4, h: 0.9)
  rnode(9.2, 2.7, "cand", "candidate riders", "H3 ring, 2 km radius", green, w: 5.4, h: 0.9)
  rnode(15.4, 2.7, "score", "score each pair", "ETA · load · fairness", green, w: 5.2, h: 0.9)
  rnode(21.6, 2.7, "assign", "assignment", "greedy or Hungarian", orange, w: 4.8, h: 0.9)
  edge("pend.east", "cand.west", "", green)
  edge("cand.east", "score.west", "", green)
  edge("score.east", "assign.west", "", green)

  decision(3.6, -1.4, "db1", "batchable?\n(same pickup,\nnearby drop)", purple, w: 5.0, h: 2.1)
  route(("assign.south", (21.6, 0.2), (3.6, 0.2), "db1.north"), orange)
  rnode(10.6, -1.4, "batch", "batch 2–3 orders", "one rider, one trip", green, w: 5.0, h: 0.9)
  rnode(10.6, -3.4, "single", "single assignment", "", green, w: 5.0, h: 0.85)
  edge("db1.east", "batch.west", "", green)
  edge("db1.south", "single.west", "", blue)
  content((7.6, -0.9), dlbl("yes", sz: 6pt, c: green))
  content((5.2, -3.2), dlbl("no", sz: 6pt, c: blue))

  rnode(17.6, -2.4, "offer", "offer to rider", "20 s to accept", orange, w: 4.8, h: 0.9)
  edge("batch.east", "offer.west", "", green)
  edge("single.east", "offer.west", "", green)
  decision(23.0, -2.4, "db2", "accepted?", orange, w: 3.6, h: 1.6)
  edge("offer.east", "db2.west", "", green)
  content((23.0, -4.4), dlbl("no → next candidate", sz: 6.3pt, c: red))
  route(("db2.south", (23.0, -3.6), (17.6, -3.6), "offer.south"), red)
}))
#v(1.5mm)

#text(size: 8.7pt)[
  #text(fill: orange, weight: "bold")[Batching is where the unit economics live.] Two orders
  delivered on one trip nearly halves the per-order rider cost. The constraint is
  #underline(stroke: 1pt + red)[food quality]: a batched order waits while the second is
  collected, so batching is permitted only when the added delay is under a few minutes and the
  drop points are genuinely close. This is a business rule encoded in the scorer, and it is tuned
  continuously by a data science team — not a static threshold.
  #note[An offer, never an assignment (as in CS1). A rider who does not accept within 20 s loses
  it to the next candidate; forcing assignment produces rejected pickups and cold food.]
]
#v(2mm)

#h2("6 · Data model & partition keys", c: purple)

#table(
  columns: (auto, auto, 1fr, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#f5eefa") } else { none },
  text(font: headfont, size: 8.3pt, fill: purple)[Entity],
  text(font: headfont, size: 8.3pt, fill: purple)[Store],
  text(font: headfont, size: 8.3pt, fill: purple)[Key / partition],
  text(font: headfont, size: 8.3pt, fill: purple)[Why],

  text(size: 8.1pt)[Order],
  text(size: 8.1pt)[Postgres],
  text(size: 7.9pt)[PK `order_id` UUIDv7; shard by `city_id`],
  text(size: 7.9pt)[Orders never cross cities — single-shard lifecycle],

  text(size: 8.1pt)[Menu item],
  text(size: 8.1pt)[Postgres + Redis],
  text(size: 7.9pt)[PK `(restaurant_id, item_id)`],
  text(size: 7.9pt)[Whole restaurant menu fetched as one cached blob],

  text(size: 8.1pt)[Stock-out],
  text(size: 8.1pt)[Redis],
  text(size: 7.9pt)[`soldout:{rest}:{item}` TTL to midnight],
  text(size: 7.9pt)[Ephemeral by nature; auto-expires daily],

  text(size: 8.1pt)[Cart],
  text(size: 8.1pt)[Redis],
  text(size: 7.9pt)[`cart:{user}` TTL 24 h],
  text(size: 7.9pt)[Abandoned carts should disappear, not accumulate],

  text(size: 8.1pt)[Rider position],
  text(size: 8.1pt)[Redis],
  text(size: 7.9pt)[`geo:{h3_r8}` ZSET, TTL 60 s],
  text(size: 7.9pt)[TTL expiry = offline detection, no reaper (S7)],

  text(size: 8.1pt)[Ledger entry],
  text(size: 8.1pt)[Postgres],
  text(size: 7.9pt)[Append-only `(account_id, seq)`],
  text(size: 7.9pt)[Double-entry; restaurant, rider, platform, customer],

  text(size: 8.1pt)[Search doc],
  text(size: 8.1pt)[Elasticsearch],
  text(size: 7.9pt)[Routed by `city_id`],
  text(size: 7.9pt)[Query never fans out beyond one city (M17)],
)
#v(1.5mm)

#text(size: 8.7pt)[
  #text(fill: purple, weight: "bold")[`city_id` is the shard key throughout], for the same reason
  as ride-hailing: a food order's customer, restaurant, rider, pricing and settlement all live in
  one city. It gives single-shard transactions, per-city scaling for the dinner peak, clean data
  residency, and a natural canary boundary — #underline(stroke: 1pt + green)[new features roll out
  city by city]. The known cost is skew: Bangalore may carry 50× a tier-3 town (M28), so large
  cities get dedicated shards and the long tail is pooled.
]
#v(2mm)

#h2("7 · Failure modes", c: red)

#text(size: 8.7pt)[
  #text(fill: red, weight: "bold")[Restaurant never responds.] The tablet is off, the staff are
  busy, the Wi-Fi dropped. #text(fill: green)[Fix:] 90-second accept timer, auto-cancel, void the
  authorisation (not a refund), notify the customer with alternatives, and
  #underline(stroke: 1pt + green)[down-rank the restaurant's availability score] so it stops being
  shown as open.

  #text(fill: red, weight: "bold")[Menu/price drift.] The catalogue cache serves a price the
  restaurant changed an hour ago. The customer is charged the old price and someone absorbs the
  difference. #text(fill: green)[Fix:] re-price #text(weight: "bold")[server-side at checkout]
  against the authoritative store — never trust the cart's cached price. The cache is for browsing
  only (M5).

  #text(fill: red, weight: "bold")[Rider goes offline mid-delivery.] Tunnel, dead battery, crash.
  #text(fill: green)[Fix:] the app journals state locally and syncs on reconnect (M12); the
  tracking UI degrades honestly to "last known position, 4 minutes ago" rather than freezing on a
  stale dot; support can reassign after a threshold.

  #text(fill: red, weight: "bold")[Dinner-peak dispatch starvation.] Demand exceeds riders; some
  orders wait indefinitely while newer ones get assigned.
  #text(fill: green)[Fix:] age-weighted scoring so waiting orders rise in priority, plus demand
  shaping — raise delivery fees or hide distant restaurants when supply is short. Honest ETAs beat
  optimistic ones (an ETA you miss is worse than a long one you meet).

  #text(fill: red, weight: "bold")[Payment captured, delivery failed.]
  #text(fill: green)[Fix:] capture only on proof of delivery; failure before that is a void. If
  capture has happened, the refund is a #underline(stroke: 1pt + green)[compensating ledger
  entry], never an edit (M4, CS3).

  #text(fill: red, weight: "bold")[Elasticsearch cluster down.] Discovery is dead and nobody can
  order. #text(fill: green)[Fix:] fall back to a cached "popular near you" list served from Redis
  — degraded discovery beats no discovery (Part 1 §6.4).
]
#v(2mm)

#h2("8 · Delivery roadmap", c: purple)

#text(size: 8.7pt)[
  #text(fill: purple, weight: "bold")[Team topology.] Six stream-aligned teams, drawn to match the
  consistency boundaries: #text(weight: "bold")[Discovery] (search, ranking, catalogue),
  #text(weight: "bold")[Ordering] (cart, pricing, order state),
  #text(weight: "bold")[Marketplace] (dispatch, ETA, batching — the algorithmic core, paired with
  data science), #text(weight: "bold")[Money] (payments, ledger, payouts to restaurants and
  riders), #text(weight: "bold")[Logistics Client] (rider app, offline, telemetry),
  #text(weight: "bold")[Merchant] (restaurant tablet, POS integrations) — over a
  #text(weight: "bold")[Platform] team owning the gateway, connection fleet, event bus and
  observability.
  #note[The restaurant tablet is routinely under-staffed because it is unglamorous. It is also the
  single point at which the entire marketplace stalls: an order the restaurant never sees is an
  order that never happens. Staff it properly.]

  #text(fill: purple, weight: "bold")[Phasing.]
  #text(weight: "bold")[M0–M3:] one city, manual dispatch, no batching — prove the order lifecycle
  and the money path end to end.
  #text(weight: "bold")[M4–M6:] automated dispatch, live tracking, rider app offline support.
  #text(weight: "bold")[M7–M9:] batching, dynamic ETA, surge; scale to 20 cities.
  #text(weight: "bold")[M10–M12:] multi-region, search relevance, FinOps pass.
  #underline(stroke: 1pt + green)[City-by-city rollout is the blast-radius strategy] — every new
  city is a canary with a real population.

  #text(fill: purple, weight: "bold")[SLO targets.] Search p99 < 200 ms · checkout p99 < 1 s ·
  dispatch decision p99 < 3 s · tracking push p99 < 250 ms ·
  #text(weight: "bold")[order-to-kitchen notification < 5 s] · payment exactly-once effect
  #text(weight: "bold")[100%] · ledger imbalance #text(weight: "bold")[0].

  #text(fill: purple, weight: "bold")[The conversation that defines the product.] Leadership will
  ask for faster delivery. The lever is not engineering latency — it is
  #underline(stroke: 1pt + green)[supply density and batching policy], which are marketplace
  decisions. Engineering owns the 3-second dispatch decision; it does not own the 32-minute
  delivery. Being precise about that boundary is what keeps an engineering team from being held to
  a number it cannot move.
]
#v(2mm)

#anti("trusting the client's cart price at checkout")[
  The cart is built client-side from cached menu data, and checkout charges the total the client
  submits. A stale cache, a restaurant price change, or a trivially modified client all produce a
  charge that does not match reality — and because the order
  #underline(stroke: 1pt + red)[succeeds], nothing alerts. The discrepancy surfaces weeks later in
  restaurant settlement disputes, by which point thousands of orders are affected and the money
  has moved. #text(fill: green)[Fix:] the client's cart is a #emph[proposal]. The server re-prices
  every line against the authoritative catalogue at checkout, and any difference is shown to the
  customer for confirmation before payment is authorised.
]
