#import "/shared/lib/template.typ": *
#reg(1, "S8", "P99 spikes from GC and deep call chains")
#chapterhead("Part 3 · Interview Scenarios", "S8 · Tail Latency Diagnosis")

#h1("S8 · Eradicating P99 Spikes", c: orange)

#text[
  #text(fill: purple, weight: "bold")[The prompt.] p50 is a healthy 40 ms. p99 is 2.8 seconds and
  getting worse. Dashboards are green, every team insists their service is fine, and customers are
  complaining. Find it and fix it.
]
#v(2mm)

#h2("1 · The dilemma and its root cause", c: red)

#text(size: 9pt)[
  Every team is telling the truth. Each service has a good p99 in isolation; the
  #underline(stroke: 1pt + red)[composition] is what fails. With a 20-service call chain, the
  user's request is slow if #emph[any] service is slow, so individual excellence does not
  compose (Part 1 §4.1).

  #text(fill: purple, weight: "bold")[Root cause, usually one of four:] garbage-collection pauses
  on a managed runtime, a call chain deep enough that tail amplification dominates, a shared
  resource (connection pool, lock) with queueing, or a slow dependency with a timeout longer than
  anyone's patience. The diagnosis must distinguish them, because the fixes are unrelated.
]
#v(2mm)

#formula("Tail amplification — why nobody is at fault")[
  #text(size: 8.6pt)[
    Each service: p99 = 50 ms, and the request touches #text(weight: "bold")[20] of them.
    #linebreak()
    P(no slow call) = 0.99²⁰ = 0.818 #sym.arrow.r
    #text(fill: red, weight: "bold")[18.2%] of user requests hit at least one p99 call.
    #linebreak()
    So the user-visible p99 is not 50 ms — it approaches the
    #underline(stroke: 1pt + red)[sum of the worst cases] along the critical path.
    #linebreak() #v(1mm)
    #text(weight: "bold")[GC contribution:] a 200 ms stop-the-world pause every 30 s per JVM.
    With 20 services, P(a request meets a pause) ≈ 20 × (0.2/30) =
    #text(fill: red, weight: "bold")[13%]. Each adds up to 200 ms.
    #linebreak() #v(1mm)
    #text(fill: green, weight: "bold")[Therefore: 2.8 s is consistent with ~4–6 unlucky hops],
    not one broken service. Hunting for "the slow service" fails because there isn't one — which
    is why this scenario defeats teams for months.
  ]
]
#v(2mm)

#h2("2 · The diagnosis, in order", c: green)

#pfig("Fig S8.1 · a 2.8s p99 nobody owns — read the waterfall gap before touching a GC flag")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.3, 20.7, 3.0, "tail-based sampling deployed first (M19); histograms merged before any quantile is computed — never average per-host p99s")

  ppill(1.8, 0, "sym", "user p99 = 2.8s", c: red, w: 3.4)
  pstep(6.35, 0, "tbs", "tail sampling", "head at 1% loses them", st-start, n: 1, actor: "collector", w: 4.8)
  pstep(11.61, 0, "cmp", "slow vs fast", "which span inflated?", st-man, n: 2, actor: "engineer", w: 4.8)
  pdec(16.46, 0, "sig", "what is the\nsignature?")

  pstep(17.0, -3.8, "gc", "GC pause", "gap, no work · ZGC + heap", st-auto, n: 3, actor: "jvm", w: 4.8)
  pstep(11.4, -3.8, "pool", "pool queueing", "slow, no work · raise cap", st-auto, n: 4, actor: "runtime", w: 4.8)
  pstep(5.6, -3.8, "dep", "20 hops deep", "parallelise · BFF (M6)", st-integ, n: 5, actor: "architecture", w: 4.8)
  ppill(2.55, -7.2, "hedge", "hedged reads · +2% load", w: 4.9)

  line("sym.east", "tbs.west", mark: (end: ">"), stroke: miss)
  line("tbs.east", "cmp.west", mark: (end: ">"), stroke: hot)
  line("cmp.east", "sig.west", mark: (end: ">"), stroke: lookup)
  line("sig.south", (16.46, -2.0), (17.0, -2.0), "gc.north", mark: (end: ">"), stroke: except)
  plabel(18.4, -2.0, "gap between spans", c: purple, dy: 0.34)
  line("gc.west", "pool.east", mark: (end: ">"), stroke: except)
  line("pool.west", "dep.east", mark: (end: ">"), stroke: except)
  line("dep.south", (5.6, -7.2), "hedge.east", mark: (end: ">"), stroke: hot)
  plabel(3.9, -5.6, "mitigate meanwhile", c: green, dy: 0.0)

  ploop("hedge.west", "cmp.south", -8.9, "re-measure the merged histogram after every change", c: blue)
}))
#pcards(
  [Traces that actually contain the slow requests; GC logs enabled and timestamp-correlated; the fleet p99 computed from merged histograms, not averaged],
  [In: 20 services each at a healthy 50ms p99, so 18.2% of requests meet at least one · Out: the cause named per signature — GC pause, pool queueing, or depth — and the matching fix, not a tuned flag],
  [Tail-based sampling collector (M19) · trace waterfall comparison · JVM GC logs, ZGC/Shenandoah · connection-pool metrics · BFF aggregation (M6) · hedged requests],
)
#v(1.5mm)

#text(size: 9pt)[
  #text(fill: blue, weight: "bold")[1 · You cannot fix what you cannot see.] If sampling is
  head-based at 1%, you are keeping 1% of the slow traces — almost certainly none of the ones you
  need. Switch to #underline(stroke: 1pt + green)[tail-based sampling] retaining every trace over
  a latency threshold (M19). This step alone often takes a week and is non-negotiable.

  #text(fill: green, weight: "bold")[2 · Compare a slow trace to a fast one.] The waterfall shows
  exactly which span inflated. Three signatures distinguish the causes:
  #text(fill: purple)[a gap between spans with no work attributed] is a GC pause or scheduler
  starvation; #text(fill: orange)[a span that is slow but doing nothing] is queueing on a pool or
  lock; #text(fill: red)[a slow leaf span] is a genuinely slow dependency.

  #text(fill: green, weight: "bold")[3 · For GC, read the logs, do not guess.] Enable GC logging
  and correlate pause timestamps with the slow traces. The usual fixes, in order of effort:
  raise the heap so collections are rarer, switch to a low-pause collector (ZGC, Shenandoah,
  G1 tuned for pause targets), or #underline(stroke: 1pt + green)[reduce allocation rate] — which
  is the only one that addresses the cause rather than deferring it.

  #text(fill: green, weight: "bold")[4 · For depth, remove hops.] Twenty sequential services is
  an architectural problem no tuning survives. Parallelise independent calls, aggregate at a BFF
  (M6), and cache intermediate results. #text(fill: orange)[Hedged requests] (Part 1 §4.3) buy a
  large tail improvement for ~2% extra load on idempotent reads — the highest-leverage mitigation
  available while the structural fix is in progress.
]
#v(2mm)

#key[
  #text(fill: red, weight: "bold")[Never average percentiles across hosts] while diagnosing this.
  A fleet "p99" computed as the mean of per-host p99s is mathematically meaningless and will hide
  the one host at 5 s serving 2% of traffic. Merge the histograms, compute the quantile once
  (Part 1 §4.3) — otherwise you are debugging a number that does not exist.
]
#v(2mm)

#h2("3 · SEM execution strategy", c: purple)

#text(size: 8.9pt)[
  #text(fill: purple, weight: "bold")[Name an owner for the user-visible number.] The structural
  reason this persists is that p99 belongs to #underline(stroke: 1pt + red)[no single team] —
  everyone's dashboard is green and nobody is accountable for the composition. Create an
  end-to-end latency SLO owned by one person, measured at the client (M19), reviewed weekly. That
  organisational change does more than any tuning.

  #text(fill: purple, weight: "bold")[Sequence the work honestly.] Week 1–2: tail sampling and
  client-side tracing. Week 3: diagnosis. Week 4+: fixes, which may be architectural and span
  quarters. Resist the pressure to tune GC flags on day one —
  #underline(stroke: 1pt + green)[without traces you are guessing], and a wrong guess costs a
  month and some credibility.

  #text(fill: purple, weight: "bold")[Blast radius.] Latency work carries real risk: heap
  increases can trigger OOM kills, collector changes alter throughput characteristics, and
  hedging multiplies load on a dependency that may be the bottleneck. Canary every change (M26)
  and watch the dependency's saturation, not just your own latency.

  #text(fill: purple, weight: "bold")[Stakeholder framing.] Translate to the thing that is
  actually being lost: #text(fill: green)["18% of requests are affected; at our conversion
  elasticity that is roughly £X per month."] "p99 is 2.8 seconds" does not fund a quarter of
  engineering work; the revenue sentence does.

  #text(fill: purple, weight: "bold")[Prevent the recurrence.] p99 regression becomes a release
  gate in canary analysis (M26). Tail latency degrades by accumulation — one 20 ms addition per
  release, invisible individually, catastrophic over a year.
]
#v(2mm)

#anti("tuning GC flags without evidence")[
  The team reads a blog post, switches collectors and doubles the heap across the fleet. p99
  improves slightly, then worsens a week later. Nobody knows which change helped because three
  were deployed together, and the larger heap now causes
  #text(fill: red, weight: "bold")[longer, rarer pauses] — a worse tail than before. Months pass
  in flag archaeology while the real cause, an unindexed query in one downstream service that
  degrades under a specific input, goes #underline(stroke: 1pt + red)[untouched the entire time].
  #text(fill: green)[Fix:] trace first, identify the span, change one thing, measure. Tail latency
  is a measurement problem long before it is a tuning problem.
]
