#import "/shared/lib/template.typ": *
// CHAPTER-HEAD: Part 1 · Core Architectural Foundations | 4 · Latency Profiling
#reg(1, "4", "Latency Profiling & Tail Mitigation")
#chapterhead("Part 1 · Core Architectural Foundations", "4 · Latency Profiling")
#ix("Percentiles")
#ix("Tail amplification")
#ix("Coordinated omission")
#ix("Hedged request")
#ix("False sharing")

#h1("4. Latency Profiling & Tail Mitigation", c: orange)

#text[
  Averages lie about latency, and they lie in the direction that hurts most. Latency
  distributions are #text(fill: orange, weight: "bold")[right-skewed]: a long thin tail of slow
  requests drags the mean up while the median stays comfortable. Report percentiles or report
  nothing. At scale the tail is not an edge case --- it is
  #underline(stroke: 1pt + red)[most of your users' worst experience], every day.
]
#v(2.5mm)

// ---------------------------------------------------------------- 4.1 --------
#h2("4.1  Percentiles, and why the mean is useless", c: orange)

#align(center, cetz.canvas(length: 0.9cm, {
  import cetz.draw: *
  // axes
  line((0, 0), (16, 0), stroke: 1.1pt + ink)
  line((0, 0), (0, 4.2), stroke: 1.1pt + ink)
  content((8, -0.75), dlbl("latency ->", sz: 7.5pt, c: ink))
  content((-0.9, 2.1), dlbl("count", sz: 7.5pt, c: ink))

  // right-skewed curve, drawn as a polyline
  line((0.3, 0.1), (1.4, 1.6), (2.2, 3.4), (3.0, 3.9), (3.9, 3.1), (5.0, 2.0),
       (6.4, 1.1), (8.2, 0.62), (10.4, 0.38), (12.6, 0.24), (15.4, 0.12),
       stroke: 1.6pt + blue)

  // percentile markers
  line((3.0, 0), (3.0, 3.9), stroke: (paint: green, thickness: 1pt, dash: "dashed"))
  content((3.0, 4.35), dlbl("p50", sz: 7pt, c: green))
  content((3.0, -0.35), dlbl("40ms", sz: 6.5pt, c: green))

  line((6.4, 0), (6.4, 1.1), stroke: (paint: orange, thickness: 1pt, dash: "dashed"))
  content((6.4, 1.55), dlbl("p95", sz: 7pt, c: orange))
  content((6.4, -0.35), dlbl("180ms", sz: 6.5pt, c: orange))

  line((10.4, 0), (10.4, 0.38), stroke: (paint: red, thickness: 1pt, dash: "dashed"))
  content((10.4, 0.85), dlbl("p99", sz: 7pt, c: red))
  content((10.4, -0.35), dlbl("900ms", sz: 6.5pt, c: red))

  line((14.2, 0), (14.2, 0.16), stroke: (paint: red, thickness: 1.2pt))
  content((14.2, 0.7), dlbl("p99.9", sz: 7pt, c: red))
  content((14.2, -0.35), dlbl("4s", sz: 6.5pt, c: red))

  line((4.6, 0), (4.6, 2.4), stroke: (paint: purple, thickness: 1.2pt, dash: "dotted"))
  content((4.75, 2.85), dlbl("mean -- lies", sz: 7pt, c: purple))
}))
#v(1.5mm)

#text[
  The mean sits between p50 and p95 and describes #text(fill: red)[nobody]. Half your users are
  faster than it, and the users who are suffering are far slower than it. Worse, the mean is not
  robust: a single 30-second request can move it while the median does not twitch.
  #note[Percentiles are not averageable. You cannot average the p99 of ten servers to get the
  fleet p99 --- that number is mathematically meaningless and it is the single most common
  monitoring mistake in production dashboards. You must merge the underlying histograms
  (HdrHistogram, t-digest, Prometheus native histograms), then compute the quantile once.]
]
#v(2mm)

#formula("Tail amplification: why p99 is everyone's problem")[
  #text(size: 8.8pt)[
    If one user request fans out to #text(weight: "bold")[N] backend calls and waits for all of
    them, the chance of escaping the slow tail entirely is #text(weight: "bold")[(1 #sym.minus p)#super[N]].
    #linebreak() #v(1mm)
    N = 1, p99 #sym.arrow.r 1% of requests are slow.
    #linebreak()
    N = 100 #sym.arrow.r 1 #sym.minus (0.99)#super[100] =
    #text(fill: red, weight: "bold")[63.4%] of user requests hit at least one p99 backend call.
    #linebreak()
    N = 500 #sym.arrow.r 1 #sym.minus (0.99)#super[500] =
    #text(fill: red, weight: "bold")[99.3%]. Your p99 is now the median experience.
  ]
]
#v(2mm)

#key[
  Dean & Barroso, #text(style: "italic")[The Tail at Scale] (2013): in a fan-out architecture,
  #text(fill: red, weight: "bold")[the service's p99 becomes the user's p50]. This is why a
  microservice migration can halve every individual service's latency and still make the product
  feel slower --- you multiplied the number of chances to be unlucky.
]
#v(2.5mm)

// ---------------------------------------------------------------- 4.2 --------
#h2("4.2  Coordinated omission — the bug in your load test", c: red)

#align(center, cetz.canvas(length: 0.9cm, {
  import cetz.draw: *
  content((4.2, 2.4), dlbl("WRONG: wait for response, then send next", sz: 8pt, c: red))
  line((0.4, 1.3), (8.4, 1.3), stroke: 1.1pt + ink)
  for (i, x) in ((0.8, 0), (2.0, 1), (3.2, 2)).enumerate() {
    line((x.at(0), 1.3), (x.at(0), 1.75), stroke: 1pt + green)
  }
  rect((4.2, 1.05), (7.4, 1.55), stroke: 1pt + red, fill: rgb("#fadbd8"))
  content((5.8, 1.3), dlbl("one 3s stall", sz: 7pt, c: red))
  content((5.8, 0.55), dlbl("requests that SHOULD have", sz: 6.5pt, c: red))
  content((5.8, 0.1), dlbl("been sent here are never sent", sz: 6.5pt, c: red))
  content((4.2, -0.6), dlbl("-> load generator reports p99 = 50ms. Reality: 3s.", sz: 7pt, c: red))

  content((13.0, 2.4), dlbl("RIGHT: send on a fixed schedule", sz: 8pt, c: green))
  line((9.6, 1.3), (17.2, 1.3), stroke: 1.1pt + ink)
  for x in (10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 16.8) {
    line((x, 1.3), (x, 1.75), stroke: 1pt + green)
  }
  rect((13.0, 1.05), (16.2, 1.55), stroke: 1pt + red, fill: rgb("#fadbd8"))
  content((14.6, 0.55), dlbl("queued requests keep accruing", sz: 6.5pt, c: green))
  content((14.6, 0.1), dlbl("latency -- measured honestly", sz: 6.5pt, c: green))
  content((13.0, -0.6), dlbl("-> p99 reflects what users actually felt.", sz: 7pt, c: green))
}))
#v(1.5mm)

#text[
  Gil Tene's term for a measurement artefact that makes nearly every naive load test optimistic.
  A closed-loop generator sends the next request only after the previous one returns. When the
  server stalls for 3 seconds, the generator #text(fill: red, weight: "bold")[stops sending] ---
  so the requests that would have experienced the stall are never issued, and never recorded.
  The tool reports one slow sample instead of three thousand.
  #note[Fix: use an open-loop generator that sends at a fixed arrival rate regardless of
  responses (wrk2, Gatling's constant-rate injection, JMeter throughput shaping), or
  post-correct by back-filling the omitted samples. If your load test says p99 is 50ms and
  production says 2s, coordinated omission is the first thing to suspect --- not the network.]
]
#v(2.5mm)

// ---------------------------------------------------------------- 4.3 --------
#h2("4.3  Mitigations that actually move the tail", c: green)

#text[
  #text(fill: green, weight: "bold")[Hedged requests.] Send the request; if no answer by p95,
  send a duplicate to another replica and take whichever returns first. Because only ~5% of
  requests get hedged, the extra load is small while the tail improvement is large --- Dean &
  Barroso measured p99.9 dropping from 1800ms to 74ms at a 2% cost.
  #note[Only safe for idempotent reads. Hedging a payment authorisation charges the customer
  twice. Pair hedging with an idempotency key, or restrict it to GETs.]

  #text(fill: green, weight: "bold")[Request reissue with cancellation.] Same idea, but the
  client cancels the loser as soon as a winner returns, which reclaims most of the duplicate
  work. Requires the backend to honour cancellation --- gRPC does; many HTTP handlers quietly
  do not and keep computing a response nobody will read.

  #text(fill: green, weight: "bold")[Tied requests.] Send to two replicas with each told about
  the other; the first to #underline(stroke: 1pt + green)[start] work tells the second to drop
  it. Cheaper than hedging, needs cooperating servers.

  #text(fill: orange, weight: "bold")[Fix the cause, not just the symptom.] Most p99 spikes in a
  managed runtime come from a small set of repeat offenders: garbage-collection pauses, a lock
  convoy, an unbounded queue, a cold cache after deploy, a noisy neighbour on shared hardware,
  or TCP head-of-line blocking. Hedging hides these. Profiling removes them.
]
#v(2mm)

#h3("CPU cache lines — where microsecond tails are born", c: purple)

#align(center, cetz.canvas(length: 0.9cm, {
  import cetz.draw: *
  content((3.6, 2.0), dlbl("FALSE SHARING", sz: 8pt, c: red))
  rect((0.6, 0.4), (7.0, 1.5), stroke: 1.3pt + red, radius: 0.08)
  line((3.8, 0.4), (3.8, 1.5), stroke: (paint: luma(150), dash: "dashed", thickness: 0.7pt))
  content((2.2, 0.95), dlbl("counter A", sz: 7pt, c: ink))
  content((5.4, 0.95), dlbl("counter B", sz: 7pt, c: ink))
  content((3.8, 1.95), dlbl("", sz: 7pt))
  content((3.8, -0.15), dlbl("ONE 64-byte cache line", sz: 7pt, c: red))
  content((3.8, -0.75), dlbl("core 1 writes A -> invalidates core 2's copy of B", sz: 6.8pt, c: red))

  content((13.2, 2.0), dlbl("PADDED", sz: 8pt, c: green))
  rect((10.2, 0.4), (13.2, 1.5), stroke: 1.3pt + green, radius: 0.08)
  content((11.7, 0.95), dlbl("counter A", sz: 7pt, c: ink))
  rect((13.6, 0.4), (16.6, 1.5), stroke: 1.3pt + green, radius: 0.08)
  content((15.1, 0.95), dlbl("counter B", sz: 7pt, c: ink))
  content((13.4, -0.15), dlbl("separate cache lines", sz: 7pt, c: green))
  content((13.4, -0.75), dlbl("cores no longer fight -- 10x+ on hot counters", sz: 6.8pt, c: green))
}))
#v(1.5mm)

#text[
  A cache line is #text(fill: purple, weight: "bold")[64 bytes] on x86-64 and arm64. Two
  variables that land on the same line are owned by the cache-coherence protocol as one unit:
  when core 1 writes A, core 2's cached copy of #text(fill: red)[B] is invalidated even though
  nothing touched B. Two threads incrementing adjacent counters can run
  #underline(stroke: 1pt + red)[slower than one thread] doing both.
  #note[This matters for metrics counters, ring-buffer head/tail indices, and per-shard
  statistics --- exactly the hot paths you added to measure performance. Pad to 64 bytes
  (Java `@Contended`, Go `_ [64]byte` padding, C++ `alignas(64)`) or give each thread its own
  counter and sum on read.]
]
#v(2mm)

#anti("averaging percentiles across servers")[
  A dashboard shows "fleet p99 = 120ms", computed as the mean of each host's p99. That number
  does not exist in any mathematical sense --- percentiles are
  #text(fill: red, weight: "bold")[not linearly combinable]. One host serving 2% of traffic with
  a 5s p99 is invisible; the averaged figure stays green while a slice of users is on fire.
  #text(fill: green)[Fix:] export histograms, merge the buckets, compute the quantile once over
  the merged distribution. Every modern metrics stack supports this --- the broken version is
  just the default people reach for.
]
