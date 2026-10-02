#import "/shared/lib/template.typ": *
#reg(1, "M29", "Container Orchestration & Lifecycle")
#chapterhead("Part 2 · Modules", "M29 · Pod Lifecycle & Robustness")
#ix("Liveness probe")
#ix("Readiness probe")
#ix("preStop hook")
#ix("SIGTERM")

#h1("M29 · Container Lifecycle Robustness", c: green)

#text[
  Most "Kubernetes problems" are really lifecycle problems: a pod that does not know how to stop,
  or a probe that lies about whether it can start. Every rolling deploy, autoscale event and node
  drain exercises this path, so it runs #underline(stroke: 1pt + green)[far more often] than any
  disaster you have planned for.
]
#v(2mm)

#h2("1 · Shutdown is a race you must win", c: red)

#align(center, cetz.canvas(length: 0.82cm, {
  import cetz.draw: *
  swimlane(-0.4, -2.0, 18.4, 2.0, "POD TERMINATION — two things happen CONCURRENTLY", red,
    rgb("#fdf0ee"))
  line((1.0, 1.0), (17.4, 1.0), stroke: 1.2pt + ink)
  content((1.0, 1.5), dlbl("t=0 delete", sz: 6.3pt, c: red))

  rect((1.2, 1.2), (7.0, 1.75), stroke: 1pt + orange, fill: rgb("#fdebd9"))
  content((4.1, 1.47), dlbl("endpoint removal propagates to every kube-proxy", sz: 6.2pt, c: orange))
  rect((1.2, 0.25), (5.0, 0.8), stroke: 1pt + red, fill: rgb("#fadbd8"))
  content((3.1, 0.52), dlbl("SIGTERM sent immediately", sz: 6.2pt, c: red))

  content((9.0, 0.0), dlbl("GAP: pod is already SIGTERM'd but STILL RECEIVING traffic", sz: 7pt, c: red))
  content((9.0, -0.65), dlbl("-> connection refused errors during every normal deploy", sz: 6.5pt, c: red))

  rect((7.2, 0.25), (13.0, 0.8), stroke: 1pt + green, fill: rgb("#d9f0e2"))
  content((10.1, 0.52), dlbl("preStop sleep 15s — bridges the gap", sz: 6.2pt, c: green))
  rect((13.2, 0.25), (16.8, 0.8), stroke: 1pt + green)
  content((15.0, 0.52), dlbl("drain in-flight, exit 0", sz: 6.2pt, c: green))
  content((9.0, -1.45), dlbl("terminationGracePeriodSeconds must exceed preStop + drain time",
    sz: 6.5pt, c: purple))
}))
#v(1.5mm)

#text(size: 9pt)[
  The subtlety that catches everyone: endpoint removal and `SIGTERM` are
  #underline(stroke: 1pt + red)[not ordered]. The kubelet signals the container immediately,
  while removal from Service endpoints propagates asynchronously through the API server to every
  node's kube-proxy and every ingress. For a second or more, a shutting-down pod still receives
  new connections.
  #note[The fix is deliberately crude and entirely standard: a `preStop` hook that sleeps 10–15 s.
  The pod keeps serving during the sleep while endpoint removal propagates, and only then begins
  draining. Without it, every deploy produces a burst of 502s that teams often misattribute to
  the load balancer.]
]
#v(2mm)

#h2("2 · The three probes do different jobs", c: blue)

#table(
  columns: (auto, 1fr, auto, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#eef4fb") } else { none },
  text(font: headfont, size: 8.5pt, fill: blue)[Probe],
  text(font: headfont, size: 8.5pt, fill: blue)[Question],
  text(font: headfont, size: 8.5pt, fill: blue)[On failure],
  text(font: headfont, size: 8.5pt, fill: blue)[Must NOT check],

  text(size: 8.3pt, fill: red)[liveness],
  text(size: 8pt)[Is this process wedged beyond recovery?],
  text(size: 8.3pt, fill: red)[kill + restart],
  text(size: 8pt, fill: red)[Dependencies. A DB blip would restart your whole fleet],

  text(size: 8.3pt, fill: orange)[readiness],
  text(size: 8pt)[Can it serve traffic #emph[right now]?],
  text(size: 8.3pt, fill: orange)[remove from endpoints],
  text(size: 8pt)[Nothing — here dependency checks are appropriate],

  text(size: 8.3pt, fill: green)[startup],
  text(size: 8pt)[Has slow initialisation finished?],
  text(size: 8.3pt, fill: green)[keep waiting],
  text(size: 8pt)[Use for JVM/legacy apps to avoid a liveness restart loop],
)
#v(1.5mm)

#key[
  #text(fill: red, weight: "bold")[Liveness must never check a dependency.] If liveness pings the
  database, a brief database outage makes every pod fail its probe, so Kubernetes restarts the
  entire fleet simultaneously --- turning a recoverable dependency blip into a
  #underline(stroke: 1pt + red)[full outage with cold caches]. Liveness answers "is this process
  broken"; readiness answers "can it serve".
]
#v(2mm)

#h2("3 · Capacity arithmetic", c: orange)

#formula("Rolling update timing and surge capacity")[
  #text(size: 8.6pt)[
    20 pods, `maxUnavailable: 1`, `maxSurge: 1`, 30 s per pod to become ready
    #sym.arrow.r 20 × 30 = #text(fill: orange, weight: "bold")[10 minutes] for a full rollout —
    and the same again to roll back.
    #linebreak()
    `maxSurge: 25%` (5 at a time) #sym.arrow.r 4 batches × 30 s =
    #text(fill: green, weight: "bold")[2 minutes], at the cost of 25% extra capacity during the
    rollout.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Grace period budget:] `terminationGracePeriodSeconds` must exceed
    preStop sleep (15 s) + longest in-flight request (say 30 s) =
    #text(fill: orange, weight: "bold")[45 s minimum]. The default of 30 s
    #underline(stroke: 1pt + red)[SIGKILLs mid-request] for any endpoint slower than 15 s.
    #linebreak() #v(1mm)
    #text(weight: "bold")[PodDisruptionBudget:] with 20 pods and `minAvailable: 18`, a node drain
    can only evict 2 at a time. Too strict and cluster upgrades stall indefinitely; too loose and
    a drain removes most of your capacity at once. Set it from the
    #underline(stroke: 1pt + green)[capacity you need], not from a round number.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[SIGTERM ignored.] The app has no handler, so it runs until
  `SIGKILL` at the end of the grace period, dropping every in-flight request.
  #text(fill: green)[Fix:] trap `SIGTERM`, stop accepting new work, finish in-flight work, close
  pools, exit 0. In a container, also ensure the app is PID 1 or that your init forwards signals
  — a shell-wrapped entrypoint commonly swallows them.

  #text(fill: red, weight: "bold")[Liveness restart loop.] A slow-starting app exceeds its
  liveness threshold during startup, gets killed, starts again, and never reaches readiness.
  #text(fill: green)[Fix:] a `startupProbe` with a generous failure budget; liveness only begins
  after it passes.

  #text(fill: red, weight: "bold")[Readiness that lies.] `GET /health` returns 200 from a static
  handler while the connection pool is exhausted, so traffic keeps arriving at a pod that cannot
  serve it. #text(fill: green)[Fix:] readiness reflects real capacity — pool availability,
  queue depth, warm caches.

  #text(fill: red, weight: "bold")[No resource requests.] Without requests the scheduler packs
  pods arbitrarily and the kernel OOM-kills under memory pressure; without limits one pod starves
  its neighbours. #text(fill: green)[Fix:] set requests from observed p95 usage and limits with
  headroom — and know that CPU limits cause throttling that looks like unexplained latency.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Why do deploys produce 502s even with readiness probes?]
  #linebreak()
  Because endpoint removal is asynchronous while `SIGTERM` is immediate — the pod stops while
  still being routed to. A `preStop` sleep bridges the gap.
  #note[Testing: deep operational experience. This is the single most common unexplained
  Kubernetes symptom, and knowing the race is the whole answer.]

  #text(fill: green, weight: "bold")[Q: Liveness vs readiness?]
  #linebreak()
  Liveness restarts a wedged process and must never check dependencies; readiness gates traffic
  and should. #note[Testing: the dependency distinction. Getting it backwards is how a database
  blip becomes a fleet-wide restart.]

  #text(fill: green, weight: "bold")[Q: How do you drain a pod gracefully?]
  #linebreak()
  preStop sleep → stop accepting → finish in-flight → close pools → exit 0, with a grace period
  longer than the sum. #note[Testing: whether you have debugged a deploy that dropped requests.]
]
#v(2mm)

#anti("the liveness probe that checks the database")[
  `livenessProbe: GET /health` where `/health` queries the database "so we know the pod really
  works". The database has a 20-second failover. Every pod's liveness probe fails at once,
  Kubernetes kills #text(fill: red, weight: "bold")[the entire fleet simultaneously], and all of
  them restart with empty caches and cold connection pools against a database that was already
  recovering. A 20-second blip becomes a #underline(stroke: 1pt + red)[ten-minute outage], and
  the restarts themselves slow the recovery. #text(fill: green)[Fix:] liveness checks only
  in-process health (is the event loop responsive, is the thread pool alive). Dependency health
  belongs in readiness, where failure removes traffic without destroying the process.
]
