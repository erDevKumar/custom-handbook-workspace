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

#align(center, cetz.canvas(length: 0.9cm, {
  import cetz.draw: *
  line((0, 0), (17.6, 0), stroke: 1.3pt + ink)
  rect((0.4, -0.4), (5.6, 0.4), stroke: 0.9pt + green, fill: rgb("#d9f0e2"), name: "u1")
  content("u1.center", dlbl("UP — 30 days", sz: 7.5pt, c: green))
  rect((5.9, -0.4), (7.0, 0.4), stroke: 0.9pt + red, fill: rgb("#fadbd8"), name: "d1")
  content("d1.center", dlbl("30m", sz: 6.5pt, c: red))
  rect((7.3, -0.4), (13.4, 0.4), stroke: 0.9pt + green, fill: rgb("#d9f0e2"), name: "u2")
  content("u2.center", dlbl("UP — 30 days", sz: 7.5pt, c: green))
  rect((13.7, -0.4), (14.6, 0.4), stroke: 0.9pt + red, fill: rgb("#fadbd8"), name: "d2")
  content("d2.center", dlbl("20m", sz: 6pt, c: red))
  rect((14.9, -0.4), (17.4, 0.4), stroke: 0.9pt + green, fill: rgb("#d9f0e2"))

  bracket(0.4, 5.6, -1.0, "MTBF = mean time BETWEEN failures (43,200 min)", blue)
  line((5.9, -1.9), (7.0, -1.9), stroke: 1.2pt + red)
  content((8.9, -2.35), dlbl("MTTR = mean time TO RECOVER (30 min)", sz: 7pt, c: red))
  content((13.4, -1.5), dlbl("halving THIS is the cheap lever", sz: 7pt, c: green))
  content((2.6, 0.95), dlbl("detect -> triage -> mitigate -> verify", sz: 6.5pt, c: purple))
}))
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

#align(center, cetz.canvas(length: 0.9cm, {
  import cetz.draw: *
  line((0, 0), (17.4, 0), stroke: 1.3pt + ink)
  // backups along the timeline
  for x in (1.6, 3.1, 4.6) {
    line((x, 0.35), (x, -0.35), stroke: 1.1pt + purple)
    content((x, 0.75), dlbl("bkp", sz: 5.8pt, c: purple))
  }
  line((7.8, 1.0), (7.8, -1.0), stroke: 2.2pt + red)
  content((7.8, 1.45), dlbl("DISASTER", sz: 8pt, c: red))
  content((4.6, -0.75), dlbl("last good copy", sz: 6.5pt, c: purple))

  line((12.4, 0.5), (12.4, -0.5), stroke: 1.4pt + green)
  content((12.4, 0.95), dlbl("service restored", sz: 7pt, c: green))

  bracket(4.6, 7.8, -1.5, "RPO = data you LOSE (writes since last copy)", purple)
  bracket(7.8, 12.4, -3.0, "RTO = time you are DOWN (detect + decide + restore)", green)
  content((15.0, -0.8), dlbl("reconcile + backfill", sz: 6.5pt, c: orange))
  content((2.0, -0.75), dlbl("normal operation", sz: 6.5pt, c: luma(120)))
}))
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
