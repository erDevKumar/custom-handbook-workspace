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

#align(center, cetz.canvas(length: 0.88cm, {
  import cetz.draw: *
  rnode(3.0, 0.4, "cl", "CLOSED", "pass through · count failures", green, w: 4.4, h: 1.3)
  rnode(9.4, 0.4, "op", "OPEN", "reject instantly · no network", red, w: 4.4, h: 1.3)
  rnode(15.8, 0.4, "ho", "HALF-OPEN", "admit 1-2 probes only", orange, w: 4.4, h: 1.3)

  line("cl.east", "op.west", mark: (end: ">"), stroke: miss)
  badge(6.2, 1.15, "1", red)
  content((6.2, 1.75), dlbl(">50% of last 100 failed", sz: 6.3pt, c: red))
  line("op.east", "ho.west", mark: (end: ">"), stroke: 1.1pt + orange)
  badge(12.6, 1.15, "2", orange)
  content((12.6, 1.75), dlbl("cooldown 30s elapsed", sz: 6.3pt, c: orange))

  line("ho.north", (15.8, 3.3), (3.0, 3.3), "cl.north", mark: (end: ">"), stroke: 1.1pt + green)
  badge(9.4, 3.3, "3", green)
  content((9.4, 3.75), dlbl("probe succeeds -> reset counter", sz: 6.5pt, c: green))

  line("ho.south", (15.8, -1.5), (9.4, -1.5), "op.south", mark: (end: ">"), stroke: miss)
  badge(12.6, -1.5, "4", red)
  content((12.6, -1.95), dlbl("probe fails -> trip, restart cooldown", sz: 6.5pt, c: red))

  content((3.0, -1.5), dlbl("success resets the counter", sz: 6.5pt, c: green))
  bracket(0.8, 18.0, -2.6, "timeout counts as a FAILURE — or a hanging dep never trips the breaker", purple)
}))
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

#align(center, cetz.canvas(length: 0.9cm, {
  import cetz.draw: *
  content((3.8, 2.3), dlbl("NO JITTER -- synchronised waves", sz: 7.5pt, c: red))
  line((0.4, 1.4), (7.6, 1.4), stroke: 1.1pt + ink)
  for x in (1.2, 1.25, 1.3, 2.6, 2.65, 2.7, 4.8, 4.85, 4.9) {
    line((x, 1.4), (x, 2.0), stroke: 1.4pt + red)
  }
  content((3.8, 0.75), dlbl("every client retries at the same instant", sz: 6.8pt, c: red))

  content((13.2, 2.3), dlbl("FULL JITTER -- spread out", sz: 7.5pt, c: green))
  line((9.6, 1.4), (16.8, 1.4), stroke: 1.1pt + ink)
  for x in (10.1, 10.6, 11.0, 11.7, 12.2, 12.9, 13.4, 14.1, 14.8, 15.3, 16.0, 16.5) {
    line((x, 1.4), (x, 1.85), stroke: 1.2pt + green)
  }
  content((13.2, 0.75), dlbl("load spread evenly -> service recovers", sz: 6.8pt, c: green))
}))
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

#align(center, cetz.canvas(length: 0.9cm, {
  import cetz.draw: *
  content((3.9, 2.5), dlbl("SHARED POOL", sz: 8pt, c: red))
  rect((0.6, -0.9), (7.4, 1.9), stroke: 1.3pt + red, radius: 0.08)
  content((4.0, 1.45), dlbl("one thread pool (200)", sz: 7pt, c: ink))
  node(2.2, 0.5, "sa", "svc A", green, w: 1.7, h: 0.8)
  node(5.6, 0.5, "sb", "svc B\nSLOW", red, w: 1.9, h: 0.8)
  content((4.0, -0.5), dlbl("B hangs -> all 200 threads blocked -> A dies too", sz: 6.6pt, c: red))

  content((13.2, 2.5), dlbl("BULKHEADED", sz: 8pt, c: green))
  rect((9.6, -0.9), (13.0, 1.9), stroke: 1.3pt + green, radius: 0.08)
  content((11.3, 1.45), dlbl("pool A (150)", sz: 7pt, c: ink))
  node(11.3, 0.5, "ba", "svc A", green, w: 1.7, h: 0.8)
  rect((13.4, -0.9), (16.8, 1.9), stroke: 1.3pt + red, radius: 0.08)
  content((15.1, 1.45), dlbl("pool B (50)", sz: 7pt, c: ink))
  node(15.1, 0.5, "bb", "svc B\nSLOW", red, w: 1.9, h: 0.8)
  content((13.2, -0.5), dlbl("B exhausts only its own 50 -> A keeps serving", sz: 6.6pt, c: green))
}))
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
