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

#align(center, cetz.canvas(length: 0.82cm, {
  import cetz.draw: *
  swimlane(-0.4, -1.5, 18.4, 1.9, "SCALE-UP LATENCY — the gap you must absorb", red, rgb("#fdf0ee"))
  let step(x, w, lbl, t, c) = {
    rect((x, 0.2), (x + w, 1.0), stroke: 1pt + c, fill: white)
    content((x + w / 2, 0.72), dlbl(lbl, sz: 6.2pt, c: ink))
    content((x + w / 2, 0.4), dlbl(t, sz: 6pt, c: c))
  }
  step(0.8, 2.6, "metric window", "30–60 s", orange)
  step(3.6, 2.2, "HPA poll", "15 s", orange)
  step(6.0, 2.4, "schedule pod", "5 s", green)
  step(8.6, 2.8, "node boot?", "60–180 s", red)
  step(11.6, 2.6, "image pull", "10–60 s", red)
  step(14.4, 3.0, "readiness probe", "10–30 s", orange)
  content((9.0, -0.5), dlbl("TOTAL: 2–6 minutes before the new pod serves traffic", sz: 7.5pt, c: red))
  content((9.0, -1.15), dlbl("a traffic spike lasting 90 s is over before scaling helps", sz: 6.6pt, c: purple))
}))
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
