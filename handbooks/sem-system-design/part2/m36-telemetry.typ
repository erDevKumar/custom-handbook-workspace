#import "/shared/lib/template.typ": *
#reg(1, "M36", "High-Throughput Telemetry & Analytics")
#chapterhead("Part 2 · Modules", "M36 · Telemetry & Analytics Ingestion")
#ix("Columnar store")
#ix("ClickHouse")
#ix("Adaptive sampling")

#h1("M36 · Telemetry & Analytics Ingestion", c: orange)

#text[
  Analytics ingestion inverts every assumption from the operational modules. Writes vastly
  outnumber reads, individual events are worthless while aggregates are valuable, and losing
  0.01% of events is #underline(stroke: 1pt + green)[acceptable] --- a tolerance that unlocks
  design choices no transactional system may use.
]
#v(2mm)

#h2("1 · The ingestion path", c: blue)

#pfig("Fig M36.1 · 500M events a day — collect, buffer, aggregate, and the queue that must drop")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.4, 20.6, 2.9, "a schema registry checked in CI (M7) · client-generated event ids for dedup · sample rate remotely controlled (M24)")

  ppill(2.2, 0, "in", "app event", w: 3.4)
  pstep(7.2, 0, "a", "batch on device", "flush on timer · radio, not payload", st-man, n: 1, actor: "client", w: 5.8)
  pdec(12.6, 0, "d", "queue full?", w: 2.1)
  pstep(17.8, 0, "b", "collector", "validate only, no DB", st-integ, n: 2, actor: "stateless", w: 4.8)
  pstep(17.0, -3.4, "c", "Kafka buffer", "7 d × 250 GB × 3 = 5.25 TB", st-auto, n: 3, actor: "", w: 6.0)
  pstep(9.0, -3.4, "e", "ClickHouse", "50k-row batches, one insert / 3 s", st-auto, n: 4, actor: "columnar", w: 6.2)
  ppill(2.2, -3.4, "out", "sub-second aggregates", c: green, w: 5.0)
  pstep(8.4, -6.6, "x", "drop the event", "bounded queue · never block checkout", st-dec, n: 0, actor: "", w: 7.0)

  line("in.east", "a.west", mark: (end: ">"), stroke: hot)
  line("a.east", "d.west", mark: (end: ">"), stroke: hot)
  line("d.east", "b.west", mark: (end: ">"), stroke: hot)
  plabel(15.3, 0, "no — ~17,400/s peak", c: green, dy: 0.85)
  line("b.east", (20.6, 0), (20.6, -3.4), "c.east", mark: (end: ">"), stroke: hot)
  content((19.0, -1.7), dlbl("replay a week\nafter a bug", sz: 6.3pt, c: purple))
  line("c.west", "e.east", mark: (end: ">"), stroke: hot)
  plabel(14.3, -3.4, "aggregate on ingest_time", c: green, dy: 0.85)
  line("e.west", "out.east", mark: (end: ">"), stroke: hot)
  plabel(5.3, -3.4, "10× compression", c: green, dy: 0.85)
  line("d.south", (12.6, -6.6), "x.east", mark: (end: ">"), stroke: except)
  plabel(12.3, -6.6, "yes", c: red, dy: 0.3)
  content((2.6, -6.6), dlbl("dropping telemetry always\nbeats dropping traffic", sz: 6.5pt, c: red))
}))
#pcards(
  [The telemetry path is non-blocking and droppable end to end. Aggregate on server `ingest_time`; client clocks are wrong by years, sometimes.],
  [In: batched, sampled client events. Out: columnar rows a week of which can be replayed after a transformation bug — and a quarantine table for what fails validation.],
  [Stateless collectors · Kafka, 7-day retention · ClickHouse, 25 GB/day stored from 250 GB raw · a 1% sample estimates a rate to ±0.1 pp and cuts volume 100×],
)
#v(1.5mm)

#text(size: 9pt)[
  #text(fill: purple, weight: "bold")[Why columnar.] A query like "average session length by
  country last week" touches three columns out of fifty. A row store reads every byte of every
  matching row; a column store reads only the three columns, compressed
  #text(fill: green, weight: "bold")[5–20×] because values within a column are similar. The
  difference on a billion-row table is minutes versus
  #underline(stroke: 1pt + green)[sub-second].
  #note[The trade is the mirror image of OLTP: columnar stores are poor at single-row lookups and
  at updates. ClickHouse `ALTER UPDATE` rewrites whole parts. Analytics data should be
  #text(fill: green)[append-only] — correct it with a later event, never an in-place edit.]
]
#v(2mm)

#h2("2 · Capacity arithmetic", c: orange)

#formula("Sizing an event pipeline, and what sampling buys")[
  #text(size: 8.6pt)[
    10M DAU × 50 events/user/day = #text(fill: orange, weight: "bold")[500M events/day]
    #sym.arrow.r 500,000,000 / 86,400 = #text(weight: "bold")[5,787 events/s] average, ×3 peak =
    #text(fill: orange, weight: "bold")[~17,400/s].
    #linebreak()
    At 500 B/event: #text(weight: "bold")[250 GB/day] raw. Columnar compression at ~10×
    #sym.arrow.r #text(fill: green, weight: "bold")[25 GB/day] stored = 9 TB/year.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Kafka buffer:] 7-day retention × 250 GB/day × 3 replicas =
    #text(fill: orange, weight: "bold")[5.25 TB] of broker disk — the price of being able to
    replay a week after fixing a transformation bug (M8).
    #linebreak() #v(1mm)
    #text(weight: "bold")[Batch size is the whole game for ClickHouse:] inserting one row at a
    time creates one part per row and the merge process collapses. Batch
    #text(fill: green, weight: "bold")[10,000–100,000 rows] or flush every few seconds, whichever
    comes first. 17,400/s at 50,000-row batches = one insert every
    #text(weight: "bold")[~3 seconds].
    #linebreak() #v(1mm)
    #text(weight: "bold")[Sampling:] for a metric measured across millions of events, a
    #text(weight: "bold")[1%] sample estimates a rate to within roughly ±0.1 percentage points —
    ample for product analytics, and it cuts volume
    #text(fill: green, weight: "bold")[100×]. Never sample events tied to money or legal
    obligations; sample behavioural telemetry freely.
  ]
]
#v(2mm)

#h2("3 · The client side", c: green)

#text(size: 9pt)[
  Mobile telemetry has the same constraint as geospatial pings (M15): the
  #underline(stroke: 1pt + green)[radio dominates the battery budget], not the payload. Batch
  events on device, flush on a timer or at a size threshold, prefer flushing when the app is
  already transmitting, and never wake the radio for a single event.
  #note[Adaptive sampling closes the loop: raise the sample rate for users in a new experiment or
  on a build with a suspected crash, lower it to near zero for well-understood paths. The rate is
  a remotely-controlled value (M24), so it is tunable without an app release.]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Analytics backpressure reaching production.] The warehouse is
  slow, the collector blocks, and the application thread waiting to log an event stalls a user
  request. #text(fill: green)[Fix:] the telemetry path must be
  #underline(stroke: 1pt + red)[non-blocking and droppable] — bounded in-memory queue, drop when
  full, and never let an analytics failure affect a user-facing request. Dropping telemetry is
  always better than dropping traffic.

  #text(fill: red, weight: "bold")[Clock skew on client timestamps.] Devices have wrong clocks,
  sometimes by years, so events arrive dated in the future or the distant past and corrupt
  time-series aggregates. #text(fill: green)[Fix:] record both `client_time` and server
  `ingest_time`; aggregate on server time, and use the delta to detect and quarantine skewed
  devices.

  #text(fill: red, weight: "bold")[Schema drift.] A client adds a field with a different type and
  ingestion rejects or silently coerces it. #text(fill: green)[Fix:] a schema registry with
  compatibility checks in CI (M7), and a quarantine table for events that fail validation so they
  can be reprocessed rather than lost.

  #text(fill: red, weight: "bold")[Duplicate events on retry.] Offline clients resend batches
  after a timeout and counts inflate. #text(fill: green)[Fix:] a client-generated event id (M14)
  and deduplication at ingest within a bounded window.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Design analytics ingestion for 500M events/day.]
  #linebreak()
  Client batching with adaptive sampling, a stateless collector that only validates, Kafka as the
  durable buffer, batched inserts into a columnar store, and pre-aggregated rollups for the common
  queries. #note[Testing: do you put a buffer between ingest and storage? Without it, a warehouse
  problem becomes an ingest outage and the events are gone.]

  #text(fill: green, weight: "bold")[Q: Why not Postgres for analytics?]
  #linebreak()
  Row storage reads every column of every matching row, and there is no equivalent compression
  for wide-scan aggregate queries. #note[Testing: the row-vs-column distinction, with the access
  pattern as the reason — not "Postgres is slow".]

  #text(fill: green, weight: "bold")[Q: Is losing events acceptable?]
  #linebreak()
  For behavioural telemetry, yes — and that tolerance is what permits sampling, dropping under
  backpressure, and at-least-once delivery. For billing or audit events, no, and those belong on
  a transactional path. #note[Testing: whether you classify data by its guarantee requirement
  rather than applying one standard everywhere.]
]
#v(2mm)

#anti("writing analytics events synchronously in the request path")[
  `await analytics.track(event)` sits inside the checkout handler so the event is "guaranteed".
  When the analytics service degrades to 2-second responses, checkout latency rises by two
  seconds; when it returns errors, the handler's `try/catch` is missing one path and
  #text(fill: red, weight: "bold")[checkout starts failing] — because of a telemetry outage.
  Revenue is lost to a system whose entire purpose is to observe revenue.
  #text(fill: green)[Fix:] fire-and-forget into a bounded local queue flushed by a background
  worker; drop on overflow. Analytics must never be in the critical path of anything a user is
  waiting for.
]
