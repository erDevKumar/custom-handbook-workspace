#import "/shared/lib/template.typ": *
#reg(1, "M19", "Distributed Tracing & Observability")
#chapterhead("Part 2 · Modules", "M19 · Tracing & Observability")
#ix("Distributed tracing")
#ix("OpenTelemetry")
#ix("Tail sampling")
#ix("Cardinality")

#h1("M19 · Distributed Tracing & Observability", c: blue)

#text[
  Monitoring answers questions you thought of in advance. Observability lets you ask ones you
  did not --- which is the only kind that matters at 3am. The distinction is practical: if
  diagnosing a novel failure requires shipping new code, you have monitoring.
]
#v(2mm)

#h2("1 · The three signals, and the one that links them", c: blue)

#align(center, cetz.canvas(length: 0.82cm, {
  import cetz.draw: *
  swimlane(-0.4, -2.6, 18.4, 2.4, "ONE TRACE, MANY SPANS — W3C traceparent propagates the id", blue,
    rgb("#f4f8fd"))
  // waterfall
  let bar(x1, x2, y, lbl, c) = {
    rect((x1, y - 0.28), (x2, y + 0.28), stroke: 1pt + c, fill: white)
    content(((x1 + x2) / 2, y), dlbl(lbl, sz: 6.2pt, c: ink))
  }
  bar(1.0, 16.4, 1.6, "mobile app — 980 ms total", purple)
  bar(2.4, 15.2, 0.85, "API gateway — 940 ms", blue)
  bar(3.4, 7.0, 0.1, "auth svc — 45 ms", green)
  bar(7.4, 14.6, 0.1, "order svc — 860 ms", orange)
  bar(8.4, 10.0, -0.65, "inventory — 120 ms", green)
  bar(10.4, 14.2, -0.65, "pricing — 690 ms", red)
  bar(11.0, 13.8, -1.4, "DB query — 640 ms", red)
  content((16.6, -1.4), dlbl("← the culprit", sz: 6.6pt, c: red))
  content((9.0, -2.15), dlbl("without a trace, every team sees only their own green dashboard",
    sz: 6.5pt, c: purple))
}))
#v(1.5mm)

#text(size: 9pt)[
  A #text(fill: blue, weight: "bold")[trace] is one request's journey; a
  #text(fill: green, weight: "bold")[span] is one operation within it, carrying a parent id, a
  duration and attributes. The waterfall above is the entire value proposition: the gateway is
  slow because pricing is slow because one query is slow. Without the linking id, four teams each
  see a service that looks fine.
  #note[W3C `traceparent` is the standard header:
  `00-<32-hex trace-id>-<16-hex span-id>-<flags>`. Propagate it through
  #underline(stroke: 1pt + green)[everything] — gateways, queues, cron jobs, and the mobile
  client. A trace that begins at your load balancer has already lost the DNS, TLS and radio time
  that the user actually felt.]
]
#v(2mm)

#h2("2 · Sampling — you cannot keep it all", c: orange)

#table(
  columns: (auto, 1fr, auto, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#fff3e8") } else { none },
  text(font: headfont, size: 8.5pt, fill: orange)[Strategy],
  text(font: headfont, size: 8.5pt, fill: orange)[Decision],
  text(font: headfont, size: 8.5pt, fill: orange)[Keeps errors?],
  text(font: headfont, size: 8.5pt, fill: orange)[Cost],

  text(size: 8.3pt)[Head-based],
  text(size: 8pt)[At the first span, before the outcome is known],
  text(size: 8.3pt, fill: red)[only by luck],
  text(size: 8.3pt, fill: green)[cheap],

  text(size: 8.3pt, fill: green)[Tail-based],
  text(size: 8pt)[After the trace completes — keep slow and failed ones],
  text(size: 8.3pt, fill: green)[always],
  text(size: 8.3pt, fill: red)[buffer every span],

  text(size: 8.3pt)[Rate-limited],
  text(size: 8pt)[N traces/s per endpoint, so rare routes stay visible],
  text(size: 8.3pt, fill: orange)[partly],
  text(size: 8.3pt, fill: green)[cheap],
)
#v(1.5mm)

#key[
  Head sampling at 1% means you keep #text(fill: red, weight: "bold")[1% of your errors] — and
  the interesting trace is almost never in the sample. Tail sampling inverts it: buffer spans,
  then keep 100% of errors and slow traces plus a small baseline of healthy ones. The cost is a
  collector that holds every trace until it completes, which is real but far cheaper than being
  blind during an incident.
]
#v(2mm)

#h2("3 · Capacity arithmetic", c: orange)

#formula("Telemetry volume and what sampling saves")[
  #text(size: 8.6pt)[
    10,000 RPS × 20 spans per request = #text(fill: orange, weight: "bold")[200,000 spans/s].
    At 500 B per span that is 100 MB/s = #text(fill: red, weight: "bold")[8.6 TB/day] of trace
    data alone.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Head sampling at 1%:] 86 GB/day — affordable, but you keep ~1% of the
    errors you needed.
    #linebreak()
    #text(weight: "bold")[Tail sampling, 100% of errors + 1% baseline:] at a 0.5% error rate that
    is 0.005 + 0.01 ≈ #text(fill: green, weight: "bold")[1.5% retained] = 129 GB/day — the same
    order of cost, with #underline(stroke: 1pt + green)[every failing trace kept].
    #linebreak() #v(1mm)
    #text(weight: "bold")[Collector buffering:] traces must be held until complete. At a p99
    duration of 2 s, the buffer holds 200,000 × 2 = #text(fill: orange, weight: "bold")[400,000
    spans] ≈ 200 MB in flight. Size collectors for the #emph[slowest] traces, not the average.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Cardinality warning:] adding `user_id` as a metric label on 10M users
    creates #text(fill: red, weight: "bold")[10M time series] per metric. This is how
    observability bills reach six figures and how Prometheus falls over. High-cardinality
    identifiers belong on #underline(stroke: 1pt + green)[spans and logs], never on metric labels.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[The broken trace chain.] One service forgets to forward
  `traceparent` — commonly across a queue or a thread-pool handoff — and every downstream span
  starts a new trace. The waterfall ends exactly where the problem begins.
  #text(fill: green)[Fix:] instrument propagation in shared middleware, and
  #underline(stroke: 1pt + green)[assert in CI] that a test request produces one trace, not four.

  #text(fill: red, weight: "bold")[Cardinality explosion.] A label like `request_id` or a raw URL
  with ids in the path multiplies series until the metrics backend dies, taking your
  #underline(stroke: 1pt + red)[visibility] with it during the incident it caused.
  #text(fill: green)[Fix:] enforce a label allowlist; template URLs to `/orders/{id}`.

  #text(fill: red, weight: "bold")[Observability outage during an outage.] Telemetry shares
  infrastructure with the system it observes, so both fail together.
  #text(fill: green)[Fix:] separate failure domain for the telemetry path, and never let a
  blocked exporter stall application threads — drop telemetry before dropping requests.

  #text(fill: red, weight: "bold")[Logs without trace ids.] Terabytes of logs that cannot be
  correlated to a request. #text(fill: green)[Fix:] inject `trace_id` into every log line; it
  turns grep into a join.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: p99 doubled after a deploy. How do you find out why?]
  #linebreak()
  Compare trace waterfalls before and after for the affected endpoint, find the span whose
  duration grew, and read its attributes --- the query, the dependency, the retry count.
  #note[Testing: do you reach for traces or for guesses? "Check the logs" is the weak answer;
  logs tell you what happened, traces tell you #emph[where the time went].]

  #text(fill: green, weight: "bold")[Q: Head or tail sampling?]
  #linebreak()
  Tail, so errors and slow traces are always retained; head only when collector cost or
  simplicity forces it. #note[Testing: understanding that the trace you need is by definition the
  unusual one, which head sampling discards.]

  #text(fill: green, weight: "bold")[Q: Why not label metrics with `user_id`?]
  #linebreak()
  Cardinality — one series per user per metric. It belongs on spans and logs.
  #note[Testing: operational cost awareness. This single mistake has taken down more metrics
  backends than any other.]
]
#v(2mm)

#anti("instrumenting only the backend")[
  Traces begin at the load balancer, so the dashboard shows a healthy p99 of 120 ms while users
  report an app that takes #text(fill: red, weight: "bold")[four seconds]. Everything the user
  actually experienced — DNS, TLS handshake on a cellular radio, connection setup, app cold
  start, deserialisation, rendering — is #underline(stroke: 1pt + red)[outside the measurement
  window]. The team optimises a backend that was never the problem.
  #text(fill: green)[Fix:] start the trace on the #text(fill: green)[client], propagate
  `traceparent` from the app, and measure the span the user sees. The gap between client-observed
  and server-observed latency is often the largest number in the system.
]
