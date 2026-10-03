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

#pfig("Fig 4.1 · the right-skewed distribution, and the only correct way to get a fleet percentile from it")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  // --- the distribution itself: the skew is the lesson, so it stays drawn ---
  line((0.6, -1.2), (19.8, -1.2), stroke: 1.1pt + ink)
  line((0.6, -1.2), (0.6, 2.2), stroke: 1.1pt + ink)
  content((10.2, -1.85), dlbl("latency →", sz: 7pt, c: ink))
  content((-0.2, 0.5), dlbl("count", sz: 7pt, c: ink))
  line((0.9, -1.1), (2.3, -0.1), (3.3, 1.3), (4.3, 1.7), (5.4, 1.1), (6.8, 0.3),
       (8.6, -0.35), (11.0, -0.68), (13.8, -0.85), (16.5, -0.96), (19.4, -1.06),
       stroke: 1.6pt + blue)
  line((4.3, -1.2), (4.3, 1.7), stroke: (paint: green, thickness: 1pt, dash: "dashed"))
  content((4.3, 2.05), dlbl("p50 · 40ms", sz: 6.6pt, c: green))
  line((5.9, -1.2), (5.9, 0.75), stroke: (paint: purple, thickness: 1.1pt, dash: "dotted"))
  content((6.9, 1.15), dlbl("mean — lies", sz: 6.6pt, c: purple))
  line((8.6, -1.2), (8.6, -0.35), stroke: (paint: orange, thickness: 1pt, dash: "dashed"))
  content((9.2, 0.15), dlbl("p95 · 180ms", sz: 6.6pt, c: orange))
  line((13.8, -1.2), (13.8, -0.85), stroke: (paint: red, thickness: 1pt, dash: "dashed"))
  content((14.4, -0.45), dlbl("p99 · 900ms", sz: 6.6pt, c: red))
  line((18.4, -1.2), (18.4, -1.0), stroke: 1.2pt + red)
  content((18.4, -0.6), dlbl("p99.9 · 4s", sz: 6.6pt, c: red))
  bracket(0.8, 19.6, -2.6, "the mean sits between p50 and p95 and describes NOBODY", purple)

  // --- the pipeline that turns those samples into a trustworthy number ---
  pstep(2.6, 5.0, "raw", "raw samples", "per host, per route", st-man, n: 1, actor: "each host", w: 4.0)
  pstep(7.6, 5.0, "hist", "histogram", "HdrHistogram · t-digest", st-auto, n: 2, actor: "exporter", w: 4.2)
  pdec(12.2, 5.0, "d", "merge first?", w: 2.0)
  pstep(18.0, 6.5, "good", "merge buckets", "quantile computed ONCE", st-man, n: 3, actor: "correct", w: 4.2)
  pstep(18.0, 3.5, "bad", "mean of p99s", "a number that does not exist", st-dec, n: 4, actor: "the default", w: 4.2)
  line("raw.east", "hist.west", mark: (end: ">"), stroke: hot)
  line("hist.east", "d.west", mark: (end: ">"), stroke: hot)
  line("d.east", "good.west", mark: (end: ">"), stroke: hot)
  plabel(14.9, 5.9, "yes", c: green)
  line("d.east", "bad.west", mark: (end: ">"), stroke: miss)
  plabel(14.9, 4.1, "no", c: red, dy: -0.5)
}))
#pcards(
  [Latency recorded as a distribution, not a pre-aggregated average, and exported per host rather than summarised at the host.],
  [In: raw per-request durations from every host. Out: one fleet quantile — trustworthy only if the histograms were merged first.],
  [HdrHistogram / t-digest / Prometheus native histograms · a metrics backend that merges buckets server-side.],
)
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

#pfig("Fig 4.2 · coordinated omission — the closed loop stops sending exactly when it should be measuring")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.4, 20.0, 2.9, "the generator's arrival model is known — closed-loop vs. open-loop is not a detail, it is the result")

  swimlane(-0.4, -2.1, 20.0, 1.6, "WRONG — closed loop", red, rgb("#fdf0ee"))
  content((8.6, 1.25), dlbl("send the next request only after the last one returns", sz: 6.6pt, c: red))
  ppill(2.2, 0.1, "g1", "generator", c: red)
  pstep(7.0, 0.1, "s1", "server stalls", "one 3s GC pause", st-dec, n: 1, actor: "SUT", w: 3.8)
  pdec(11.8, 0.1, "w1", "reply yet?", w: 2.0)
  pstep(17.2, 0.1, "r1", "records 1 sample", "reports p99 = 50ms", st-dec, n: 2, actor: "result", w: 4.4)
  line("g1.east", "s1.west", mark: (end: ">"), stroke: hot)
  line("s1.east", "w1.west", mark: (end: ">"), stroke: hot)
  line("w1.east", "r1.west", mark: (end: ">"), stroke: miss)
  plabel(14.2, 0.1, "after 3s", c: red)
  ploop("w1.south", "g1.south", -1.4, "no → generator WAITS; the ~3,000 requests due here are never sent", c: red)

  swimlane(-0.4, -7.9, 20.0, -3.3, "RIGHT — open loop", green, rgb("#f6fbf7"))
  content((8.6, -3.65), dlbl("send at a fixed arrival rate regardless of responses", sz: 6.6pt, c: green))
  ppill(2.2, -5.0, "g2", "generator", c: green)
  pstep(7.0, -5.0, "s2", "server stalls", "the same 3s pause", st-dec, n: 1, actor: "SUT", w: 3.8)
  pstep(12.2, -5.0, "q2", "queue grows", "arrivals keep accruing", st-auto, n: 2, actor: "in flight", w: 4.0)
  pstep(17.2, -5.0, "r2", "records ~3,000", "p99 reflects reality: 3s", st-man, n: 3, actor: "result", w: 4.6)
  line("g2.east", "s2.west", mark: (end: ">"), stroke: hot)
  line("s2.east", "q2.west", mark: (end: ">"), stroke: miss)
  line("q2.east", "r2.west", mark: (end: ">"), stroke: hot)
  ploop("r2.south", "g2.south", -6.4, "fires on a clock, not on a response — nothing is omitted", c: green)
  content((10.0, -8.6), dlbl("if the load test says p99 = 50ms and production says 2s, suspect THIS before the network", sz: 7pt, c: purple))
}))
#pcards(
  [A stated target arrival rate, and a generator that can hold it when the system under test stops responding.],
  [In: a fixed request rate against a stalling service. Out: a p99 that is either a measurement artefact (top) or the truth (bottom).],
  [wrk2 · Gatling constant-rate injection · JMeter throughput shaping · HdrHistogram with omission back-fill.],
)
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

#pfig("Fig 4.3 · false sharing — two counters on one cache line, and the padding that separates them")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  swimlane(-0.6, -2.3, 10.0, 2.6, "FALSE SHARING", red, rgb("#fdf0ee"))
  pstep(2.4, 1.2, "c1a", "core 1", "writes counter A", st-dec, n: 1, actor: "", w: 3.2, h: 1.1)
  pstep(7.0, 1.2, "c2a", "core 2", "reads counter B", st-dec, n: 2, actor: "", w: 3.2, h: 1.1)
  rect((0.8, -1.1), (8.6, -0.1), stroke: 1.3pt + red, radius: 0.08, name: "cl", fill: white)
  line((4.7, -1.1), (4.7, -0.1), stroke: (paint: luma(150), dash: "dashed", thickness: 0.7pt))
  content((2.75, -0.6), dlbl("counter A", sz: 7pt, c: ink))
  content((6.65, -0.6), dlbl("counter B", sz: 7pt, c: ink))
  content((4.7, -1.75), dlbl("ONE 64-byte cache line", sz: 7pt, c: red))
  line("c1a.south", (2.4, -0.1), mark: (end: ">"), stroke: miss)
  line((7.0, -0.1), "c2a.south", mark: (end: ">"), stroke: except)
  plabel(8.9, 0.25, "invalidated", c: red, dy: 0)

  swimlane(10.8, -2.3, 20.6, 2.6, "PADDED", green, rgb("#f6fbf7"))
  pstep(13.6, 1.2, "c1b", "core 1", "writes counter A", st-man, n: 1, actor: "", w: 3.2, h: 1.1)
  pstep(18.2, 1.2, "c2b", "core 2", "reads counter B", st-man, n: 2, actor: "", w: 3.2, h: 1.1)
  rect((12.0, -1.1), (15.2, -0.1), stroke: 1.3pt + green, radius: 0.08, fill: white)
  content((13.6, -0.6), dlbl("counter A + pad", sz: 6.8pt, c: ink))
  rect((16.6, -1.1), (19.8, -0.1), stroke: 1.3pt + green, radius: 0.08, fill: white)
  content((18.2, -0.6), dlbl("counter B + pad", sz: 6.8pt, c: ink))
  line("c1b.south", (13.6, -0.1), mark: (end: ">"), stroke: hot)
  line("c2b.south", (18.2, -0.1), mark: (end: ">"), stroke: hot)
  content((15.7, -1.75), dlbl("separate cache lines — cores stop fighting", sz: 7pt, c: green))
  bracket(0.8, 19.8, -2.9, "@Contended (Java) · _ [64]byte padding (Go) · alignas(64) (C++) — or one counter per thread, summed on read", purple)
}))
#pcards(
  [A genuinely hot, multi-core write path — metrics counters, ring-buffer head/tail indices, per-shard statistics.],
  [In: two threads incrementing adjacent variables. Out: either coherence traffic on every write, or independent lines and 10x+ throughput.],
  [x86-64 / arm64 cache-coherence protocol · `perf c2c` or VTune to find the sharing · language-level padding annotations.],
)
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
