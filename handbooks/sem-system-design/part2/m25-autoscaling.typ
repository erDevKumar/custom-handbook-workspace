#import "/shared/lib/template.typ": *
#reg(1, "M25", "Auto-Scaling & Capacity Engineering")
#chapterhead("Part 2 · Modules", "M25 · Auto-Scaling")
#ix("HPA")
#ix("KEDA")
#ix("Spot instance")

#h1("M25 · Auto-Scaling & Capacity Engineering", c: blue)

#text[
  Autoscaling is a control loop, and like every control loop it can oscillate, lag, or chase the
  wrong signal. The common failure is not that it fails to scale --- it is that it scales
  #underline(stroke: 1pt + red)[minutes after] the traffic that needed it has already timed out.
]
#v(2mm)

#h2("1 · The three dimensions", c: blue)

#table(
  columns: (auto, auto, 1fr, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#eef4fb") } else { none },
  text(font: headfont, size: 8.5pt, fill: blue)[Mechanism],
  text(font: headfont, size: 8.5pt, fill: blue)[Scales],
  text(font: headfont, size: 8.5pt, fill: blue)[Signal],
  text(font: headfont, size: 8.5pt, fill: blue)[Caveat],

  text(size: 8.3pt)[HPA],
  text(size: 8.3pt)[pod count],
  text(size: 8pt)[CPU, memory, or a custom metric],
  text(size: 8pt, fill: orange)[CPU is a poor proxy for I/O-bound work],

  text(size: 8.3pt)[VPA],
  text(size: 8.3pt)[pod size],
  text(size: 8pt)[Observed usage over time],
  text(size: 8pt, fill: red)[Evicts pods to resize; conflicts with HPA],

  text(size: 8.3pt)[Cluster autoscaler],
  text(size: 8.3pt)[node count],
  text(size: 8pt)[Unschedulable pods],
  text(size: 8pt, fill: red)[Node boot is #text(weight: "bold")[minutes], not seconds],

  text(size: 8.3pt, fill: green)[KEDA],
  text(size: 8.3pt)[pod count],
  text(size: 8pt)[#underline(stroke: 1pt + green)[Queue depth], lag, external metrics],
  text(size: 8pt, fill: green)[Scales on the thing that actually backs up],
)
#v(1.5mm)

#key[
  Scale on the #underline(stroke: 1pt + green)[queue], not on CPU. A worker blocked on a slow
  database shows #text(fill: red)[low CPU] while the backlog grows without bound, so a CPU-based
  HPA scales #emph[down] exactly when it should scale up. Kafka consumer lag, SQS depth or
  in-flight request count are leading indicators; CPU is a lagging one, and sometimes an
  inverted one.
]
#v(2mm)

#h2("2 · Why scaling is always late", c: red)

#pfig("Fig M25.1 · the autoscaling control loop, and the 2–6 minute gap it cannot close")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.4, 20.6, 3.1, "KEDA scaler on Kafka lag · PgBouncer capping DB connections · on-demand baseline + diversified spot pool")

  ppill(1.7, 0, "in", "traffic rises", w: 3.0)
  pstep(6.3, 0, "a", "metric window", "KEDA · 30–60s", st-auto, n: 1, actor: "scaler", w: 4.0)
  pdec(11.2, 0, "d", "lag > target?", w: 2.1)
  pstep(16.9, 0, "b", "schedule pod", "HPA poll 15s + 5s", st-auto, n: 2, actor: "control plane", w: 4.2)
  pstep(16.9, -3.6, "c", "node boot", "cluster AS · 60–180s", st-integ, n: 3, actor: "cloud api", w: 4.2)
  pstep(10.6, -3.6, "e", "image pull + ready", "10–60s + 10–30s", st-man, n: 4, actor: "", w: 5.0)
  ppill(3.6, -3.6, "out", "pod serves traffic", c: green, w: 4.2)

  line("in.east", "a.west", mark: (end: ">"), stroke: hot)
  line("a.east", "d.west", mark: (end: ">"), stroke: hot)
  line("d.east", "b.west", mark: (end: ">"), stroke: hot)
  plabel(13.7, 0, "yes", c: green)
  line("d.south", (11.2, -1.9), (6.3, -1.9), "a.south", mark: (end: ">"), stroke: loopbk)
  plabel(8.8, -1.9, "no — hold, 5 min stabilisation window", c: blue, dy: -0.38)
  line("b.east", (20.4, 0), (20.4, -3.6), "c.east", mark: (end: ">"), stroke: miss)
  plabel(20.4, -1.8, "no free node", c: red, dy: 0.0)
  line("c.west", "e.east", mark: (end: ">"), stroke: hot)
  line("e.west", "out.east", mark: (end: ">"), stroke: hot)
  plabel(13.7, -3.6, "cold start", c: red)
  plabel(7.1, -3.6, "ready", c: green)
  content((3.6, -5.1), dlbl("TOTAL 2–6 min — a 90 s spike is over before this pill is reached", sz: 6.6pt, c: red))
}))
#pcards(
  [Scale on queue depth, not CPU — a blocked worker sits at 15% CPU. Hard replica cap derived from Postgres `max_connections`, not from traffic.],
  [In: Kafka consumer lag, in-flight concurrency. Out: desired replica count, then pods that actually serve.],
  [KEDA · HPA · cluster autoscaler · PgBouncer · spot + on-demand node groups],
)
#v(1.5mm)

#text(size: 9pt)[
  This is the number that decides your architecture. If scale-up takes four minutes, you cannot
  autoscale your way through a flash sale, a push-notification campaign (M11) or a cache flush.
  You need #underline(stroke: 1pt + green)[headroom provisioned in advance], load shedding to
  survive the gap (M20), or pre-warming driven by a schedule.
]
#v(2mm)

#h2("3 · Capacity arithmetic", c: orange)

#formula("Headroom, cost, and the spot discount")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[Steady state:] 10,000 RPS, one pod handles 500 RPS at 70% utilisation
    #sym.arrow.r 10,000/500 = #text(fill: orange, weight: "bold")[20 pods] minimum.
    #linebreak()
    Add scale-up headroom for a 4-minute lag at a plausible 2× burst
    #sym.arrow.r run #text(fill: green, weight: "bold")[28–30 pods], not 20. The extra 50% is not
    waste; it is the only thing standing between a burst and an outage.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Cost of the headroom:] 10 extra pods × 2 vCPU × \$0.04/vCPU-hr × 730 hr
    = #text(fill: orange, weight: "bold")[\$584/month]. Weigh that against the revenue lost in one
    30-minute outage — the comparison usually ends the discussion.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Spot instances:] 60–90% cheaper with a 2-minute termination warning.
    Correct for #text(fill: green)[stateless, interruptible, restartable] work — transcoding
    (M16), batch jobs, CI. Wrong for anything holding state or long-lived connections (M10).
    #linebreak()
    Rule of thumb: on-demand for the baseline, spot for the burst. A
    #text(fill: red)[100% spot] fleet can be reclaimed simultaneously across a whole instance
    type — that is a correlated failure, not a cost optimisation.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Flapping.] Scale up, load per pod drops, scale down, load
  returns, scale up — pods churn continuously and every cycle pays cold-start cost.
  #text(fill: green)[Fix:] asymmetric behaviour — scale up fast, scale down slowly, with a
  stabilisation window of several minutes and a hysteresis gap between the thresholds.

  #text(fill: red, weight: "bold")[Scaling into a bottleneck.] More pods open more database
  connections; the database hits `max_connections` and
  #underline(stroke: 1pt + red)[everything] fails, including the pods that were healthy.
  #text(fill: green)[Fix:] a connection pooler (PgBouncer) in front, a hard cap on replicas
  derived from the shared resource's limit, not from your traffic.

  #text(fill: red, weight: "bold")[No `terminationGracePeriod` handling.] Scale-down kills pods
  mid-request. #text(fill: green)[Fix:] `SIGTERM` handling, a `preStop` hook, and draining —
  covered in M29.

  #text(fill: red, weight: "bold")[Spot reclamation cascade.] A whole instance type is reclaimed
  in one region and 60% of the fleet disappears in two minutes.
  #text(fill: green)[Fix:] diversify across instance types and AZs; keep the baseline on-demand.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Traffic 10×s in 30 seconds. Does autoscaling save you?]
  #linebreak()
  No. Scale-up takes minutes. Survive with pre-provisioned headroom, load shedding and
  degradation; autoscaling catches up afterwards.
  #note[Testing: do you know the control loop's latency? "We'll autoscale" is the answer that
  fails the follow-up.]

  #text(fill: green, weight: "bold")[Q: What metric should drive scaling?]
  #linebreak()
  The one that saturates first — usually queue depth or in-flight concurrency, rarely CPU.
  #note[Testing: whether you understand that a blocked worker has low CPU, so CPU-based scaling
  moves the wrong way for I/O-bound services.]

  #text(fill: green, weight: "bold")[Q: When are spot instances appropriate?]
  #linebreak()
  Stateless, interruptible, restartable work with a diversified fleet and an on-demand baseline.
  #note[Testing: cost awareness paired with failure awareness — both, not either.]
]
#v(2mm)

#anti("autoscaling on CPU for an I/O-bound service")[
  An API service spends most of its time waiting on a database, so it sits at
  #text(fill: red, weight: "bold")[15% CPU] while every worker thread is blocked and the request
  queue grows. The HPA, watching CPU, concludes the service is idle and
  #underline(stroke: 1pt + red)[scales down] — reducing capacity precisely when the backlog is
  growing. Latency explodes; CPU stays low; the dashboard shows an underutilised service during
  what users experience as an outage. #text(fill: green)[Fix:] scale on in-flight request count,
  queue depth, or p99 latency — a signal that rises when the system is struggling, rather than
  one that falls.
]
