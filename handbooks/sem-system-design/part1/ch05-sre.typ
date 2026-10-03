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

#pfig("Fig 5.1 · from a measurement to a contract — and why the internal target sits inside the external promise")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.6, 20.6, 2.9, "the SLI is measured where the USER is — a load balancer's 200 OK in 50ms says nothing about a stalled mobile client")

  ppill(2.0, 0, "user", "real user traffic", w: 3.8)
  pstep(7.2, 0, "sli", "SLI", "\"99.4% of reads < 300ms\"", st-start,
    n: 1, actor: "the measurement", w: 4.0)
  pstep(13.2, 0, "slo", "SLO", "\"99.9% must be < 300ms\"", st-man,
    n: 2, actor: "internal target", w: 4.0)
  pstep(19.2, 0, "sla", "SLA", "\"99.5% or you get credits\"", st-dec,
    n: 3, actor: "contract + penalty", w: 4.0)
  line("user.east", "sli.west", mark: (end: ">"), stroke: hot)
  line("sli.east", "slo.west", mark: (end: ">"), stroke: hot)
  plabel(10.2, 0, "target it", c: green)
  line("slo.east", "sla.west", mark: (end: ">"), stroke: miss)
  plabel(16.2, 0, "promise it", c: red)

  ploop("sli.south", "user.south", -1.5, "measured continuously from the client side, not the server side", c: blue)

  bracket(11.2, 20.6, -2.8, "the SLO is STRICTER than the SLA — that gap is your margin for being human", purple)
}))
#pcards(
  [Client-side instrumentation, an agreed measurement window, and a target chosen before the contract is signed.],
  [In: every real user request. Out: a number (SLI), a target to hold (SLO), and a promise with money attached (SLA).],
  [RUM / client SDK · metrics backend with quantiles · the SLO document · the customer contract.],
)
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

#pfig("Fig 5.2 · burn rate — the same budget, spent at three speeds, routed to three different responses")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.6, 20.6, 4.9, "an SLO exists, the window is fixed (30 days), and the budget was agreed in advance while everyone was calm")

  ppill(2.1, 0, "b", "error budget", c: purple, w: 3.8)
  pstep(7.2, 0, "m", "measure burn", "errors ÷ budget, per window", st-auto,
    n: 1, actor: "alerting rule", w: 4.4)
  pdec(11.6, 0, "d", "how fast?", w: 1.9)

  pstep(17.8, 2.6, "page", "PAGE someone", "budget gone in ~2 days", st-dec,
    n: 2, actor: "14.4x · 1h + 5m windows", w: 5.2)
  pstep(17.8, 0, "tick", "raise a ticket", "10% burnt in a day", st-integ,
    n: 3, actor: "3x · 1d + 2h windows", w: 5.2)
  pstep(17.8, -2.6, "ok", "on pace — ship", "unused budget is wasted velocity", st-man,
    n: 4, actor: "1x · 3d + 6h windows", w: 5.2)

  line("b.east", "m.west", mark: (end: ">"), stroke: hot)
  line("m.east", "d.west", mark: (end: ">"), stroke: hot)
  line("d.east", "page.west", mark: (end: ">"), stroke: miss)
  plabel(14.4, 1.6, "14.4x", c: red, dy: 0)
  line("d.east", "tick.west", mark: (end: ">"), stroke: 1.1pt + orange)
  plabel(14.4, 0, "3x", c: orange)
  line("d.east", "ok.west", mark: (end: ">"), stroke: hot)
  plabel(14.4, -1.6, "1x", c: green, dy: 0)

  ploop("ok.south", "m.south", -4.0, "re-evaluate on BOTH windows — the long one proves it is real, the short one proves it is STILL happening", c: blue)
  content((6.0, -5.2), dlbl("budget exhausted → feature freeze, reliability work only, until it refills", sz: 7pt, c: red))
}))
#pcards(
  [An SLO with a fixed window, and a prior agreement on what an exhausted budget means for the roadmap.],
  [In: the error rate over a long and a short window. Out: one of three actions — page, ticket, or permission to ship.],
  [Prometheus / Grafana multi-window burn-rate rules · the pager rotation · the feature-freeze policy.],
)
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
