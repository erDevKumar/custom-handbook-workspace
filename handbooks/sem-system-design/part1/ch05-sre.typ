#import "/shared/lib/template.typ": *
// CHAPTER-HEAD: Part 1 · Core Architectural Foundations | 5 · SRE Operational Standards
#reg(1, "5", "SRE Operational Standards")
#chapterhead("Part 1 · Core Architectural Foundations", "5 · SRE Operational Standards")
#ix("SLI / SLO / SLA")
#ix("Golden Signals")
#ix("Error budget")
#ix("Burn rate")
#ix("DORA metrics")

#h1("5. SRE Operational Standards", c: green)

#text[
  SRE's contribution is not a toolset, it is a #text(fill: green, weight: "bold")[decision
  procedure]: define what "working" means numerically, measure it from the user's side, spend
  the difference deliberately. Everything below exists to turn
  #text(fill: red)["the site feels slow"] into a number someone can be accountable for.
]
#v(2.5mm)

// ---------------------------------------------------------------- 5.1 --------
#h2("5.1  SLI, SLO, SLA — three words people use wrongly", c: blue)

#align(center, cetz.canvas(length: 0.9cm, {
  import cetz.draw: *
  node(2.6, 0.5, "sli", "SLI", blue, w: 2.6, h: 1.0)
  node(8.0, 0.5, "slo", "SLO", green, w: 2.6, h: 1.0)
  node(13.6, 0.5, "sla", "SLA", red, w: 2.6, h: 1.0)
  line("sli.east", "slo.west", mark: (end: ">"), stroke: hot)
  line("slo.east", "sla.west", mark: (end: ">"), stroke: miss)
  content((2.6, -0.65), dlbl("the measurement", sz: 7.5pt, c: blue))
  content((2.6, -1.25), dlbl("\"99.4% of reads < 300ms\"", sz: 7pt, c: luma(110)))
  content((8.0, -0.65), dlbl("the internal target", sz: 7.5pt, c: green))
  content((8.0, -1.25), dlbl("\"99.9% must be < 300ms\"", sz: 7pt, c: luma(110)))
  content((13.6, -0.65), dlbl("the contract + penalty", sz: 7.5pt, c: red))
  content((13.6, -1.25), dlbl("\"99.5% or you get credits\"", sz: 7pt, c: luma(110)))
  content((5.3, 1.3), dlbl("set a target", sz: 6.5pt, c: green))
  content((10.8, 1.3), dlbl("promise externally", sz: 6.5pt, c: red))
}))
#v(1.5mm)

#text[
  Always set the #text(fill: green, weight: "bold")[SLO stricter than the SLA]. If you promise
  customers 99.5% and target 99.5% internally, you breach the contract the moment you miss by
  anything. Target 99.9% internally against a 99.5% commitment, and the gap is your margin for
  being human. #note[Measure the SLI where the #underline(stroke: 1pt + green)[user] is, not at
  the server. A load balancer reporting 200 OK in 50ms tells you nothing about the mobile client
  that waited 4 seconds on a stalled TLS handshake over a bad carrier network.]
]
#v(2.5mm)

// ---------------------------------------------------------------- 5.2 --------
#h2("5.2  The Four Golden Signals", c: orange)

#table(
  columns: (auto, 1fr, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#fff3e8") } else { none },
  text(font: headfont, size: 9pt, fill: orange)[Signal],
  text(font: headfont, size: 9pt, fill: orange)[What it catches / the trap],
  text(font: headfont, size: 9pt, fill: orange)[Watch],

  text(size: 9pt, fill: blue, weight: "bold")[Latency],
  text(size: 8.4pt)[Separate #text(fill: green)[successful] from #text(fill: red)[failed]
    latency. A fast 500 will otherwise flatter your p99 --- errors that return instantly make
    the dashboard look better as the system gets worse.],
  text(size: 8.4pt)[p50 / p99 / p99.9],

  text(size: 9pt, fill: blue, weight: "bold")[Traffic],
  text(size: 8.4pt)[Demand on the system. Needed to interpret the other three: a 50% error rate
    on 4 requests is noise, on 400,000 it is an incident.],
  text(size: 8.4pt)[req/s, by route],

  text(size: 9pt, fill: blue, weight: "bold")[Errors],
  text(size: 8.4pt)[Explicit (5xx) #text(fill: red)[and implicit]: 200 OK with an empty body,
    wrong content, or a partial result. The implicit ones are what monitoring misses.],
  text(size: 8.4pt)[rate, not count],

  text(size: 9pt, fill: blue, weight: "bold")[Saturation],
  text(size: 8.4pt)[How full the #underline(stroke: 1pt + red)[most constrained] resource is.
    Usually a queue depth or thread-pool utilisation, rarely CPU. This is the leading indicator
    --- the other three are lagging.],
  text(size: 8.4pt)[queue depth, pool %],
)
#v(2mm)

#key[
  Saturation is the only one of the four that predicts the future. Latency, traffic and errors
  tell you what #text(fill: red)[already] went wrong; a queue growing steadily at 3% a minute
  tells you what will go wrong in #text(fill: orange, weight: "bold")[33 minutes]. Alert on
  saturation trends, page on error budget burn.
]
#v(2.5mm)

// ---------------------------------------------------------------- 5.3 --------
#h2("5.3  Error budgets — permission to ship", c: purple)

#formula("The budget, computed")[
  #text(size: 8.8pt)[
    SLO = #text(weight: "bold")[99.9%] over 30 days #sym.arrow.r
    error budget = 0.1% of requests.
    #linebreak() #v(1mm)
    At #text(weight: "bold")[100M] requests/month:
    0.001 #sym.times 100,000,000 =
    #text(fill: orange, weight: "bold")[100,000 failed requests] you are allowed to spend.
    #linebreak()
    In time terms: 0.001 #sym.times 43,200 min =
    #text(fill: orange, weight: "bold")[43.2 minutes] of total unavailability.
  ]
]
#v(2mm)

#text[
  The budget converts a political argument into arithmetic. #text(fill: green)[Budget
  remaining] #sym.arrow.r ship, experiment, take risks; unused budget is wasted velocity.
  #text(fill: red)[Budget exhausted] #sym.arrow.r feature freeze, reliability work only, until
  it refills. #note[The crucial property is that this is agreed #underline(stroke: 1pt + green)[in
  advance], while everyone is calm. Mid-incident is the worst possible time to negotiate whether
  reliability outranks the roadmap --- the answer gets decided by whoever is loudest.]
]
#v(2.5mm)

// ---------------------------------------------------------------- 5.4 --------
#h2("5.4  Burn-rate alerting — pages that mean something", c: red)

#align(center, cetz.canvas(length: 0.9cm, {
  import cetz.draw: *
  line((0.5, 0), (16.5, 0), stroke: 1.2pt + ink)
  line((0.5, 0), (0.5, 3.4), stroke: 1.2pt + ink)
  content((-0.4, 1.7), dlbl("budget", sz: 7pt, c: ink))
  content((8.5, -0.6), dlbl("30-day window ->", sz: 7pt, c: ink))

  // ideal burn
  line((0.5, 3.2), (16.2, 0.2), stroke: (paint: green, thickness: 1.3pt, dash: "dashed"))
  content((13.4, 1.25), dlbl("ideal burn (1x)", sz: 7pt, c: green))

  // 14.4x burn
  line((0.5, 3.2), (2.4, 0.1), stroke: 1.6pt + red)
  content((3.5, 2.5), dlbl("14.4x burn", sz: 7.5pt, c: red))
  content((3.9, 1.95), dlbl("budget gone in 2 days", sz: 7pt, c: red))
  content((3.5, 1.4), dlbl("-> PAGE someone", sz: 7pt, c: red))

  // 3x burn
  line((0.5, 3.2), (7.0, 0.15), stroke: 1.5pt + orange)
  content((8.4, 2.2), dlbl("3x burn -> ticket, not a page", sz: 7.5pt, c: orange))
}))
#v(1.5mm)

#text[
  Burn rate = how fast you are consuming the budget relative to spending it evenly.
  #text(fill: green, weight: "bold")[1x] means you will finish the window exactly on target.
  #text(fill: red, weight: "bold")[14.4x] means a 30-day budget is gone in
  #text(fill: red)[~2 days] --- that deserves a human at 3am.
  #text(fill: orange, weight: "bold")[3x] is a problem for business hours.
]
#v(2mm)

#table(
  columns: (auto, auto, auto, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#fdf0ee") } else { none },
  text(font: headfont, size: 9pt, fill: red)[Burn],
  text(font: headfont, size: 9pt, fill: red)[Long win.],
  text(font: headfont, size: 9pt, fill: red)[Short win.],
  text(font: headfont, size: 9pt, fill: red)[Action — budget consumed],

  text(size: 8.5pt, weight: "bold")[14.4x], text(size: 8.5pt)[1 hour], text(size: 8.5pt)[5 min],
  text(size: 8.3pt, fill: red)[PAGE. 2% of a 30-day budget burnt in one hour.],

  text(size: 8.5pt, weight: "bold")[6x], text(size: 8.5pt)[6 hours], text(size: 8.5pt)[30 min],
  text(size: 8.3pt, fill: orange)[PAGE. 5% burnt in six hours.],

  text(size: 8.5pt, weight: "bold")[3x], text(size: 8.5pt)[1 day], text(size: 8.5pt)[2 hours],
  text(size: 8.3pt, fill: orange)[Ticket. 10% burnt in a day.],

  text(size: 8.5pt, weight: "bold")[1x], text(size: 8.5pt)[3 days], text(size: 8.5pt)[6 hours],
  text(size: 8.3pt)[Ticket. On pace to exactly exhaust the budget.],
)
#v(2mm)

#text[
  The #underline(stroke: 1pt + green)[two-window] requirement is what makes this usable. The long
  window establishes the problem is real; the short window confirms it is
  #text(fill: red, weight: "bold")[still happening]. Without the short window, an alert that
  fired from a 10-minute outage six hours ago keeps paging long after recovery.
]
#v(2.5mm)

// ---------------------------------------------------------------- 5.5 --------
#h2("5.5  DORA — four numbers that predict delivery performance", c: blue)

#table(
  columns: (auto, auto, auto, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#eef4fb") } else { none },
  text(font: headfont, size: 9pt, fill: blue)[Metric],
  text(font: headfont, size: 9pt, fill: blue)[Elite],
  text(font: headfont, size: 9pt, fill: blue)[Low],
  text(font: headfont, size: 9pt, fill: blue)[What a bad number really means],

  text(size: 8.5pt)[Deployment frequency],
  text(size: 8.5pt, fill: green)[on demand], text(size: 8.5pt, fill: red)[< monthly],
  text(size: 8.3pt)[Batch size is large, so every release is high-risk.],

  text(size: 8.5pt)[Lead time for change],
  text(size: 8.5pt, fill: green)[< 1 hour], text(size: 8.5pt, fill: red)[> 6 months],
  text(size: 8.3pt)[Feedback arrives too late to act on.],

  text(size: 8.5pt)[Change failure rate],
  text(size: 8.5pt, fill: green)[0--15%], text(size: 8.5pt, fill: red)[> 40%],
  text(size: 8.3pt)[Testing and staging do not resemble production.],

  text(size: 8.5pt)[Time to restore],
  text(size: 8.5pt, fill: green)[< 1 hour], text(size: 8.5pt, fill: red)[> 1 week],
  text(size: 8.3pt)[This is MTTR --- the cheapest availability lever you own.],
)
#v(2mm)

#key[
  Speed and stability are #underline(stroke: 1pt + green)[not] a trade-off. The DORA research
  (Forsgren, Humble & Kim) found elite performers lead on all four simultaneously --- small
  frequent changes are easier to verify, easier to roll back, and fail less often than the
  quarterly big-bang release that was supposed to be the safe option.
]
#v(2mm)

#anti("alerting on every symptom instead of the budget")[
  A team pages on CPU > 80%, memory > 90%, disk > 85%, and every 5xx. Most fire when nothing is
  user-visible --- CPU at 85% is a machine doing its job. On-call stops reading them, and the
  one alert that mattered is buried in the noise.
  #text(fill: green)[Fix:] page only on #underline(stroke: 1pt + green)[symptoms users feel],
  expressed as error-budget burn. Resource metrics belong on dashboards and in tickets, not on
  the pager. If an alert has never once led to an action, delete it.
]
