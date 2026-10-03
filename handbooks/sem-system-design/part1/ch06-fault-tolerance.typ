#import "/shared/lib/template.typ": *
// CHAPTER-HEAD: Part 1 · Core Architectural Foundations | 6 · Fault Tolerance Patterns
#reg(1, "6", "Fault Tolerance Patterns")
#chapterhead("Part 1 · Core Architectural Foundations", "6 · Fault Tolerance Patterns")
#ix("Circuit breaker")
#ix("Exponential backoff")
#ix("Full jitter")
#ix("Bulkhead")
#ix("Graceful degradation")

#h1("6. Fault Tolerance Patterns", c: red)

#text[
  Every pattern here answers one question: #text(fill: red, weight: "bold")[how does this system
  behave when a dependency is broken?] The default answer --- block a thread and wait --- is what
  turns one slow service into a total outage. Fault tolerance is mostly about
  #underline(stroke: 1pt + green)[failing fast and failing small].
]
#v(2.5mm)

// ---------------------------------------------------------------- 6.1 --------
#h2("6.1  Circuit breaker — the three-state machine", c: red)

#pfig("Fig 6.1 · the circuit breaker's three states, and the four transitions between them")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.6, 20.6, 4.6, "every remote call has a timeout shorter than the caller's own deadline — a timeout counts as a FAILURE")

  pstep(3.0, 0, "cl", "CLOSED", "pass through · count failures", st-man,
    n: 1, actor: "normal", w: 5.2)
  pstep(10.4, 0, "op", "OPEN", "reject instantly · no network", st-dec,
    n: 2, actor: "shed load", w: 5.2)
  pstep(17.8, 0, "ho", "HALF-OPEN", "admit 1–2 probes only", st-integ,
    n: 3, actor: "tentative", w: 5.2)

  line("cl.east", "op.west", mark: (end: ">"), stroke: miss)
  plabel(6.7, 0, ">50% of the", c: red, dy: 0.65)
  plabel(6.7, 0, "last 100 failed", c: red, dy: 0.25)
  line("op.east", "ho.west", mark: (end: ">"), stroke: 1.1pt + orange)
  plabel(14.1, 0, "cooldown", c: orange, dy: 0.65)
  plabel(14.1, 0, "30s elapsed", c: orange, dy: 0.25)

  ploop("ho.north", "cl.north", 2.9, "probe succeeds → counter reset, traffic resumes", c: green)
  ploop("ho.south", "op.south", -2.1, "probe fails → trip again, restart the cooldown", c: red)

  content((3.0, -1.4), dlbl("success resets the counter", sz: 6.6pt, c: green))
  content((19.6, -1.4), dlbl("never full traffic", sz: 6.6pt, c: orange))
  content((10.4, -3.2), dlbl("tune on a RATE and a minimum volume — \"20 failures\" trips during a perfectly healthy spike", sz: 7pt, c: purple))
}))
#pcards(
  [A per-dependency failure counter over a rolling window, a minimum request volume, and a timeout on every call.],
  [In: outcomes of calls to one dependency. Out: either the real response, or an instant local rejection that touches no network.],
  [Resilience4j / Polly / Envoy outlier detection · a service mesh · the dependency's own health endpoint.],
)
#v(1.5mm)

#text[
  #text(fill: green, weight: "bold")[CLOSED] --- traffic flows, failures are counted.
  #text(fill: red, weight: "bold")[OPEN] --- every call is rejected
  #underline(stroke: 1pt + red)[immediately], without touching the network. This is the point of
  the pattern: you are not retrying a dead service, you are refusing to queue behind it.
  #text(fill: orange, weight: "bold")[HALF-OPEN] --- after a cooldown, let a small number of
  probes through. Success closes the breaker; failure re-opens it and restarts the clock.
  #note[Tune on a rate and a volume, not a raw count: "50% of the last 100 calls failed" is
  meaningful; "20 failures" trips during a traffic spike that is perfectly healthy. Always
  require a minimum request volume so three failures at 4am cannot open a breaker.]
]
#v(2mm)

#key[
  HALF-OPEN must admit #text(fill: orange, weight: "bold")[1--2 probes], never full traffic.
  Dumping the entire backlog onto a service that just came back is how you re-kill it --- and
  then the breaker opens again, producing an oscillation that looks like flapping infrastructure
  but is entirely self-inflicted.
]
#v(2mm)

#anti("a breaker that only counts errors")[
  A breaker wired to count #text(fill: red)[exceptions] never opens for a dependency that
  #underline(stroke: 1pt + red)[hangs] --- the calls have not failed yet, they are still waiting.
  Threads pile up, the pool drains, and the caller dies of thread starvation while its breaker
  sits happily CLOSED. #text(fill: red, weight: "bold")[Slow is worse than down.]
  #text(fill: green)[Fix:] every remote call gets a timeout shorter than the caller's own
  deadline, and a timeout counts as a failure for breaker purposes.
]
#v(2.5mm)

// ---------------------------------------------------------------- 6.2 --------
#h2("6.2  Retry with exponential backoff and full jitter", c: orange)

#text[
  Naive retries convert a brief blip into a sustained attack. If 10,000 clients all fail at
  #text(fill: red)[t=0] and all retry at 1s, 2s, 4s, the retries arrive in
  #underline(stroke: 1pt + red)[synchronised waves] --- the recovering service is hit by 10,000
  simultaneous requests at each step. Jitter breaks the synchronisation.
]
#v(2mm)

#formula("Backoff variants (AWS Architecture Blog, Brooker 2015)")[
  #text(size: 8.8pt)[
    #text(fill: red, weight: "bold")[No jitter:] `sleep = min(cap, base * 2^attempt)`
    #sym.arrow.r every client retries at the same instant. #text(fill: red)[Thundering herd.]
    #linebreak() #v(0.8mm)
    #text(fill: orange, weight: "bold")[Equal jitter:] `temp = min(cap, base * 2^attempt)`;
    `sleep = temp/2 + random(0, temp/2)` #sym.arrow.r better, still clustered.
    #linebreak() #v(0.8mm)
    #text(fill: green, weight: "bold")[Full jitter:] `sleep = random(0, min(cap, base * 2^attempt))`
    #sym.arrow.r #underline(stroke: 1pt + green)[use this one]. Fewest total calls and lowest
    completion time in AWS's simulations.
    #linebreak() #v(1mm)
    Worked: base=100ms, cap=20s, attempt 4 #sym.arrow.r window = min(20000, 100 #sym.times 16) =
    1600ms #sym.arrow.r sleep = #text(fill: green, weight: "bold")[random(0, 1600)ms].
  ]
]
#v(2mm)

#pfig("Fig 6.2 · why jitter matters — the same backoff formula, with and without randomisation")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  swimlane(-0.6, -2.0, 10.0, 2.2, "NO JITTER", red, rgb("#fdf0ee"))
  content((3.3, 1.85), dlbl("— synchronised waves", sz: 6.6pt, c: red))
  ppill(2.2, 0.9, "f1", "10k clients fail at t=0", c: red, w: 4.4)
  pstep(7.4, 0.9, "d1", "sleep = base·2^n", "every client, same instant", st-dec,
    n: 1, actor: "deterministic", w: 4.8)
  line("f1.east", "d1.west", mark: (end: ">"), stroke: miss)
  line((0.8, -1.0), (9.0, -1.0), stroke: 1.1pt + ink)
  for x in (1.6, 1.66, 1.72, 4.0, 4.06, 4.12, 7.0, 7.06, 7.12) {
    line((x, -1.0), (x, -0.4), stroke: 1.4pt + red)
  }
  content((4.9, -1.6), dlbl("1s · 2s · 4s — the recovering service is hit by 10,000 at once", sz: 6.5pt, c: red))

  swimlane(10.8, -2.0, 20.6, 2.2, "FULL JITTER", green, rgb("#f6fbf7"))
  content((14.0, 1.85), dlbl("— spread out", sz: 6.6pt, c: green))
  ppill(13.6, 0.9, "f2", "10k clients fail at t=0", c: green, w: 4.4)
  pstep(18.2, 0.9, "d2", "sleep = rand(0, cap)", "n=4 → rand(0, 1600)ms", st-man,
    n: 1, actor: "randomised", w: 4.8)
  line("f2.east", "d2.west", mark: (end: ">"), stroke: hot)
  line((11.4, -1.0), (19.8, -1.0), stroke: 1.1pt + ink)
  for x in (11.8, 12.3, 12.7, 13.4, 13.9, 14.6, 15.1, 15.8, 16.5, 17.0, 17.7, 18.4, 19.1, 19.5) {
    line((x, -1.0), (x, -0.5), stroke: 1.2pt + green)
  }
  content((15.6, -1.6), dlbl("load spread evenly → the service actually recovers", sz: 6.5pt, c: green))
  bracket(0.8, 19.8, -2.6, "cap the attempts · never retry a non-idempotent write without a key · retry at ONE layer (3 layers × 3 tries = 27 calls)", purple)
}))
#pcards(
  [A capped attempt count, an idempotency key for any write, and agreement on which single layer owns the retry.],
  [In: 10,000 simultaneous failures. Out: either three synchronised 10k-request waves, or a smooth arrival curve.],
  [Client SDK retry policy (AWS SDK, gRPC) · gateway retry budget · load shedding that drops retries before fresh requests.],
)
#v(1.5mm)

#text[
  Three rules that matter more than the formula.
  #text(fill: red, weight: "bold")[Cap the attempts] --- infinite retry is a denial-of-service
  tool you built yourself. #text(fill: red, weight: "bold")[Never retry a non-idempotent write]
  without an idempotency key; a retried payment is a double charge.
  #text(fill: red, weight: "bold")[Never retry at every layer] --- if the client, the gateway and
  the service each retry 3 times, one user action becomes
  #text(fill: red, weight: "bold")[27] backend calls. Retry at
  #underline(stroke: 1pt + green)[one] layer, and budget it.
]
#v(2.5mm)

// ---------------------------------------------------------------- 6.3 --------
#h2("6.3  Bulkheads — isolating the blast radius", c: blue)

#pfig("Fig 6.3 · bulkheads — one shared pool fails together, partitioned pools fail alone")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  swimlane(-0.6, -2.7, 9.8, 2.6, "SHARED POOL", red, rgb("#fdf0ee"))
  content((4.7, -2.95), dlbl("one slow dep takes the caller down", sz: 6.4pt, c: red))
  ppill(2.2, 1.2, "in1", "inbound requests", c: red, w: 3.8)
  pstep(6.8, 1.2, "p1", "one pool · 200", "threads, shared", st-dec, n: 1, actor: "caller", w: 4.0)
  line("in1.east", "p1.west", mark: (end: ">"), stroke: hot)
  pstep(2.6, -1.3, "a1", "svc A", "critical — but starved", st-dec, n: 2, actor: "", w: 3.8, h: 1.1)
  pstep(7.2, -1.3, "b1", "svc B", "optional · HANGS 30s", st-dec, n: 3, actor: "", w: 3.8, h: 1.1)
  line("p1.south", (6.8, -0.35), (2.6, -0.35), "a1.north", mark: (end: ">"), stroke: except)
  line("p1.south", "b1.north", mark: (end: ">"), stroke: miss)
  content((4.9, -2.3), dlbl("B hangs → all 200 threads blocked → A dies too", sz: 6.6pt, c: red))

  swimlane(10.6, -2.7, 20.6, 2.6, "BULKHEADED", green, rgb("#f6fbf7"))
  content((15.8, -2.95), dlbl("blast radius stops at the partition", sz: 6.4pt, c: green))
  ppill(13.4, 1.2, "in2", "inbound requests", c: green, w: 3.8)
  pstep(18.0, 1.2, "split", "two pools", "150 + 50, per dependency", st-man, n: 1, actor: "caller", w: 4.2)
  line("in2.east", "split.west", mark: (end: ">"), stroke: hot)
  pstep(13.6, -1.3, "a2", "svc A · pool 150", "critical, keeps serving", st-man, n: 2, actor: "", w: 4.4, h: 1.1)
  pstep(18.4, -1.3, "b2", "svc B · pool 50", "optional, exhausts its 50", st-dec, n: 3, actor: "", w: 4.4, h: 1.1)
  line("split.south", (18.0, -0.35), (13.6, -0.35), "a2.north", mark: (end: ">"), stroke: hot)
  line("split.south", "b2.north", mark: (end: ">"), stroke: miss)
  content((16.0, -2.3), dlbl("B exhausts only its own 50 → A keeps serving", sz: 6.6pt, c: green))
  bracket(0.8, 19.8, -3.9, "the cost is utilisation: partitioned pools idle more, so you provision more total capacity for the same throughput", purple)
}))
#pcards(
  [Dependencies classified critical vs. optional, and a pool implementation that can be sized per dependency.],
  [In: concurrent calls to a healthy and a hanging dependency. Out: either total thread starvation, or a confined failure.],
  [Per-dependency thread pools or semaphores (Resilience4j, Hystrix) · separate connection pools · per-route queues.],
)
#v(1.5mm)

#text[
  Named after ship compartments: a hull breach floods one section, not the vessel. Partition the
  scarce resource --- threads, connections, memory --- per dependency, so one misbehaving
  downstream cannot consume all of it.
  #note[The cost is utilisation. Partitioned pools are idle more often than one shared pool, so
  you provision more total capacity for the same throughput. That is the premium you pay for the
  guarantee that a non-critical dependency cannot take down a critical path. Size the critical
  pool generously and the optional one deliberately small.]
]
#v(2.5mm)

// ---------------------------------------------------------------- 6.4 --------
#h2("6.4  Graceful degradation — decide the fallback in advance", c: green)

#table(
  columns: (auto, auto, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#eef7f1") } else { none },
  text(font: headfont, size: 9pt, fill: green)[If this fails],
  text(font: headfont, size: 9pt, fill: green)[Criticality],
  text(font: headfont, size: 9pt, fill: green)[Degrade to],

  text(size: 8.5pt)[Recommendations],
  text(size: 8.5pt, fill: green)[optional],
  text(size: 8.3pt)[Static "popular items" list. Page still renders.],

  text(size: 8.5pt)[Product reviews],
  text(size: 8.5pt, fill: green)[optional],
  text(size: 8.3pt)[Hide the section entirely. Never block checkout on it.],

  text(size: 8.5pt)[Inventory count],
  text(size: 8.5pt, fill: orange)[degraded],
  text(size: 8.3pt)[Show "in stock" without a number; reconcile at order time.],

  text(size: 8.5pt)[Search],
  text(size: 8.5pt, fill: orange)[degraded],
  text(size: 8.3pt)[Fall back to category browse + cached popular queries.],

  text(size: 8.5pt)[Payment authorisation],
  text(size: 8.5pt, fill: red)[critical],
  text(size: 8.3pt)[#text(fill: red)[No fallback.] Fail the order honestly and say so.],
)
#v(2mm)

#text[
  Degradation is a #underline(stroke: 1pt + green)[product decision made at design time], not an
  engineering improvisation at 3am. Classify every dependency on the critical path as
  #text(fill: green)[optional], #text(fill: orange)[degraded] or #text(fill: red)[critical], and
  write the fallback into the code behind a flag you can flip. #note[The anti-goal is a page that
  returns 500 because the recommendation carousel timed out. Users forgive a missing carousel;
  they do not forgive a checkout that will not load.]
]
#v(2mm)

#key[
  Combine the patterns --- they are layers, not alternatives.
  #text(fill: blue)[Timeout] bounds the wait. #text(fill: orange)[Retry with jitter] handles the
  transient blip. #text(fill: red)[Circuit breaker] stops hammering a dependency that is properly
  down. #text(fill: purple)[Bulkhead] confines the damage. #text(fill: green)[Fallback] keeps the
  product usable. Missing any one of the five turns a dependency failure into
  #text(fill: red, weight: "bold")[your] outage.
]
#v(2mm)

#anti("retry storms amplifying a recovery")[
  A database has a 30-second hiccup. Every service retries 3 times with no jitter; every gateway
  retries those; every mobile client retries on failure. When the database comes back it is met
  with #text(fill: red, weight: "bold")[an order of magnitude more traffic than normal] --- not
  from users, but from accumulated retries --- and immediately falls over again. The outage now
  lasts hours instead of 30 seconds. #text(fill: green)[Fix:] full jitter, a retry budget
  (e.g. retries capped at 10% of total requests), breakers that stay open through the recovery,
  and load shedding that drops retried requests before fresh ones.
]
