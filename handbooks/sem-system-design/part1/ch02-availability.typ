#import "/shared/lib/template.typ": *
// CHAPTER-HEAD: Part 1 · Core Architectural Foundations | 2 · Availability vs. Reliability
#reg(1, "2", "Availability vs. Reliability")
#chapterhead("Part 1 · Core Architectural Foundations", "2 · Availability vs. Reliability")
#ix("Nines (availability)")
#ix("MTBF")
#ix("MTTR")
#ix("RPO")
#ix("RTO")

#h1("2. Availability vs. Reliability", c: blue)

#text[
  These two words get used interchangeably in standups and they mean different things.
  #text(fill: blue, weight: "bold")[Availability] asks: did it answer? #text(fill: purple,
  weight: "bold")[Reliability] asks: was the answer #underline(stroke: 1pt + green)[correct],
  and will it keep being correct? A system that returns a cached balance of #sym.dollar 0 for
  every request is #text(fill: green)[100% available] and #text(fill: red)[0% reliable]. Most
  serious outages are reliability failures that monitoring scored as "up".
]
#v(2.5mm)

// ---------------------------------------------------------------- 2.1 --------
#h2("2.1  The Nines — and the one number to memorise", c: blue)

#formula("The only arithmetic you need")[
  #align(center, text(size: 11pt)[1 year = 365.25 #sym.times 24 #sym.times 60 =
    #text(fill: orange, weight: "bold")[525,960 minutes]])
  #v(1.5mm)
  #text(size: 8.8pt)[Downtime/year = (1 #sym.minus availability) #sym.times 525,960.
    Everything below is that one multiplication.]
]
#v(2mm)

#table(
  columns: (auto, auto, auto, 1fr, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#eef4fb") } else { none },
  text(font: headfont, size: 9pt, fill: blue)[Nines],
  text(font: headfont, size: 9pt, fill: blue)[Per year],
  text(font: headfont, size: 9pt, fill: blue)[Per month],
  text(font: headfont, size: 9pt, fill: blue)[The arithmetic],
  text(font: headfont, size: 9pt, fill: blue)[Feels like],

  text(size: 9pt)[99%],
  text(size: 9pt, fill: red)[3d 15h 36m], text(size: 8.5pt, fill: red)[7h 18m],
  text(size: 8.2pt)[0.01 #sym.times 525960 = 5,259.6 min],
  text(size: 8.2pt)[a hobby project],

  text(size: 9pt)[99.9%],
  text(size: 9pt, fill: orange)[8h 45m 57s], text(size: 8.5pt, fill: orange)[43m 50s],
  text(size: 8.2pt)[0.001 #sym.times 525960 = 525.96 min],
  text(size: 8.2pt)[one bad night],

  text(size: 9pt)[99.95%],
  text(size: 9pt, fill: orange)[4h 22m 58s], text(size: 8.5pt, fill: orange)[21m 55s],
  text(size: 8.2pt)[0.0005 #sym.times 525960 = 262.98 min],
  text(size: 8.2pt)[typical SaaS SLA],

  text(size: 9pt)[99.99%],
  text(size: 9pt, fill: green)[52m 36s], text(size: 8.5pt, fill: green)[4m 23s],
  text(size: 8.2pt)[0.0001 #sym.times 525960 = 52.60 min],
  text(size: 8.2pt)[one bad deploy],

  text(size: 9pt, weight: "bold")[99.999%],
  text(size: 9pt, fill: green, weight: "bold")[5m 15.6s],
  text(size: 8.5pt, fill: green, weight: "bold")[26.3s],
  text(size: 8.2pt)[0.00001 #sym.times 525960 = 5.26 min],
  text(size: 8.2pt)[no human in the loop],
)
#v(2mm)

#key[
  Each extra nine divides downtime by #text(fill: orange, weight: "bold")[10] and roughly
  #text(fill: red, weight: "bold")[multiplies cost by 10]. Past four nines the budget is smaller
  than human reaction time --- #text(fill: red)[5 minutes a year] means no one can read a page,
  open a laptop, and fix anything. Five nines is not a monitoring goal, it is an
  #underline(stroke: 1pt + green)[automation] goal: failover must happen without you.
]
#v(2mm)

#text[
  #text(fill: purple, weight: "bold")[Serial dependencies multiply.] A request crossing 5
  services that are each 99.9% available is not 99.9% available. It is
  #text(fill: red)[0.999#super[5] = 99.5%] --- which is 43 hours of downtime a year, not 8.
  #note[This is why deep microservice call chains quietly destroy an SLO that every individual
  team is meeting. Each team's dashboard is green. The user's experience is the product of all
  of them. Count the hops on your critical path, then multiply.]
]
#v(2mm)

#anti("promising nines you do not control")[
  A team commits to #text(fill: red)[99.99%] while synchronously calling a third-party payment
  API whose own SLA is #text(fill: red)[99.9%]. The ceiling is now 99.9% no matter how perfect
  your code is --- you have promised an SLO your dependency cannot support.
  #text(fill: green)[Fix:] either make the dependency non-blocking (queue the call, degrade
  gracefully), or publish an SLO that is #underline(stroke: 1pt + green)[strictly weaker] than
  the weakest thing on your critical path.
]
#v(2.5mm)

// ---------------------------------------------------------------- 2.2 --------
#h2("2.2  MTBF and MTTR — the two levers", c: orange)

#pfig("Fig 2.1 · one failure cycle — MTBF is the gap, MTTR is the recovery you actually control")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.6, 20.6, 2.9, "failures are detected automatically — an outage nobody notices has an unbounded MTTR")

  ppill(1.9, 0, "up1", "UP · 30 days", w: 3.0)
  pstep(7.2, 0, "det", "detect", "alert fires · 4 min", st-auto, n: 1, actor: "monitoring", w: 3.4)
  pstep(11.0, 0, "tri", "triage", "page on-call · 8 min", st-man, n: 2, actor: "on-call", w: 3.4)
  pstep(14.8, 0, "mit", "mitigate", "rollback / flag · 14 min", st-man, n: 3, actor: "on-call", w: 3.4)
  pstep(18.6, 0, "ver", "verify", "SLI back green · 4 min", st-man, n: 4, actor: "on-call", w: 3.4)

  line("up1.east", "det.west", mark: (end: ">"), stroke: miss)
  plabel(4.7, 0, "it breaks", c: red)
  line("det.east", "tri.west", mark: (end: ">"), stroke: hot)
  line("tri.east", "mit.west", mark: (end: ">"), stroke: hot)
  line("mit.east", "ver.west", mark: (end: ">"), stroke: hot)

  ploop("ver.east", "up1.east", 1.9, "service restored — the next 30 days of uptime begin", c: green)

  bracket(0.4, 3.4, -1.3, "MTBF = 43,200 min", blue)
  bracket(5.5, 20.3, -1.3, "MTTR = 30 min — detect + triage + mitigate + verify. Halving THIS is the cheap lever.", red)
  content((12.8, -2.9), dlbl("A = MTBF / (MTBF + MTTR) = 43200 / 43230 = 99.93%", sz: 7pt, c: green))
}))
#pcards(
  [Alerting that fires on user-visible symptoms, a tested rollback, and a runbook the on-call has actually run.],
  [In: a failure at minute 43,200. Out: 30 minutes of downtime, and an availability figure of 99.93%.],
  [Metrics + alerting stack · pager rotation · one-click rollback or feature-flag kill-switch · the runbook.],
)
#v(1.5mm)

#formula("Availability from MTBF and MTTR")[
  #align(center, text(size: 11pt)[A = MTBF / (MTBF + MTTR)])
  #v(1.5mm)
  #text(size: 8.8pt)[
    Example: MTBF = 30 days (43,200 min), MTTR = 30 min
    #sym.arrow.r A = 43200 / 43230 = #text(fill: green, weight: "bold")[99.93%].
    #linebreak()
    Halve MTTR to 15 min #sym.arrow.r A = 43200 / 43215 =
    #text(fill: green, weight: "bold")[99.965%] --- the same gain as doubling MTBF to 60 days,
    and far cheaper to achieve.
  ]
]
#v(2mm)

#anti("chasing MTBF instead of MTTR")[
  Engineering instinct is to prevent failure: better hardware, more testing, more review gates.
  That stretches MTBF, and it is #text(fill: red)[expensive and slow] --- you are buying
  reliability one nine at a time. Cutting MTTR is usually #text(fill: green)[cheaper and
  compounds]: a one-click rollback, a tested runbook, a feature flag kill-switch, and good
  alerting halve recovery time in a sprint. #text(fill: purple)[The arithmetic above shows both
  levers move availability identically --- pick the one you can actually move.]
]
#v(2.5mm)

// ---------------------------------------------------------------- 2.3 --------
#h2("2.3  RTO and RPO — the two questions a business actually asks", c: purple)

#pfig("Fig 2.2 · a disaster, split into the data you lose (RPO) and the time you are down (RTO)")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.6, 20.6, 3.3, "the restore has been rehearsed with a stopwatch — a backup never restored is a hope, not a backup")

  pstep(2.1, 0, "bkp", "snapshot", "last good copy · 00:00", st-auto, n: 1, actor: "scheduler", w: 3.6)
  pstep(6.4, 0, "writes", "live writes", "accruing, not yet copied", st-man, n: 2, actor: "users", w: 3.6)
  pdec(10.4, 0, "boom", "DISASTER", w: 1.9)
  pstep(15.6, 0, "rest", "restore", "detect + decide + restore", st-man, n: 3, actor: "on-call", w: 3.8)
  ppill(19.4, 0, "ok", "service restored", c: green, w: 3.2)

  line("bkp.east", "writes.west", mark: (end: ">"), stroke: hot)
  line("writes.east", "boom.west", mark: (end: ">"), stroke: miss)
  line("boom.east", "rest.west", mark: (end: ">"), stroke: except)
  plabel(12.6, 0, "region gone", c: red, dy: 0.42)
  line("rest.east", "ok.west", mark: (end: ">"), stroke: hot)

  ploop("rest.east", "writes.west", 2.1, "reconcile + backfill the writes that were lost", c: orange)

  bracket(2.1, 10.4, -1.4, "RPO = data you LOSE (every write since the last durable copy)", purple)
  bracket(10.4, 21.0, -2.9, "RTO = time you are DOWN (detect + decide + restore, at 3am)", green)
}))
#pcards(
  [Durable copies in a different failure domain, valid restore credentials, and a measured — not aspirational — restore time.],
  [In: a region-level disaster at a known instant. Out: a restored service, minus every write since the last snapshot.],
  [Snapshot / WAL-archive scheduler · cross-region object store · DR runbook · reconciliation job for the backfill.],
)
#v(1.5mm)

#text[
  #text(fill: purple, weight: "bold")[RPO (Recovery Point Objective)] --- how much data may we
  lose? It is measured backwards from the disaster to the last durable copy. RPO = 0 demands
  synchronous replication, which charges you cross-region latency on
  #underline(stroke: 1pt + red)[every single write], forever, to pay for an event that may never
  happen.

  #text(fill: green, weight: "bold")[RTO (Recovery Time Objective)] --- how long may we be down?
  Measured forward from the disaster to restored service. RTO near zero demands warm standby
  capacity running and paid for while idle.
  #note[These are business decisions priced in engineering. Ask the product owner directly:
  "if we lose the last 5 minutes of orders, what happens?" The answer for a payment ledger and
  for a recommendation cache are not remotely the same, and they should not get the same
  architecture or the same bill.]
]
#v(2mm)

#table(
  columns: (auto, auto, auto, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#f5eefa") } else { none },
  text(font: headfont, size: 9pt, fill: purple)[Strategy],
  text(font: headfont, size: 9pt, fill: purple)[RPO],
  text(font: headfont, size: 9pt, fill: purple)[RTO],
  text(font: headfont, size: 9pt, fill: purple)[Cost / trade-off],

  text(size: 8.5pt)[Backup + restore],
  text(size: 8.5pt, fill: red)[hours], text(size: 8.5pt, fill: red)[hours--days],
  text(size: 8.2pt)[cheapest; you will lose a day of work],

  text(size: 8.5pt)[Pilot light],
  text(size: 8.5pt, fill: orange)[minutes], text(size: 8.5pt, fill: orange)[tens of min],
  text(size: 8.2pt)[core data replicated, compute scaled up on demand],

  text(size: 8.5pt)[Warm standby],
  text(size: 8.5pt, fill: orange)[seconds], text(size: 8.5pt, fill: green)[minutes],
  text(size: 8.2pt)[a smaller copy always running; you pay for idle capacity],

  text(size: 8.5pt)[Active--active],
  text(size: 8.5pt, fill: green)[#sym.tilde 0], text(size: 8.5pt, fill: green)[seconds],
  text(size: 8.2pt)[2x infra + conflict resolution; see PACELC in topic 3],
)
#v(2mm)

#key[
  #text(fill: red, weight: "bold")[A backup you have never restored is not a backup --- it is a
  hope.] RTO is not the time your restore script takes on paper; it is the time it takes at 3am,
  run by whoever is on call, on a day the dashboard is also down. Rehearse it, time the
  rehearsal, and publish #underline(stroke: 1pt + green)[that] number as your RTO.
]
#v(2mm)

#anti("the untested disaster recovery plan")[
  The DR document says RTO is 4 hours. Nobody has executed it in 18 months. The real failure
  modes are never in the document: the restore credentials expired, the backup bucket is in the
  region that just failed, the runbook references a service that was renamed, and restoring
  #text(fill: red)[80 TB] over the available pipe takes 14 hours regardless of what the plan
  claims. #text(fill: green)[Fix:] schedule a real game-day restore, measure it with a
  stopwatch, and treat the measured number --- not the aspirational one --- as the SLO you
  publish.
]
