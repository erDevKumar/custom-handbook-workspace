#import "/shared/lib/template.typ": *
#reg(1, "M20", "Cascading Failures & Load Shedding")
#chapterhead("Part 2 · Modules", "M20 · Cascading Failures")
#ix("Load shedding")
#ix("Cascading failure")
#ix("Little's Law")

#h1("M20 · Cascading Failures & Load Shedding", c: red)

#text[
  An overloaded system that accepts every request serves #underline(stroke: 1pt + red)[none of
  them]. Queues grow, every response arrives after the client has already given up, and the work
  is wasted twice. Shedding load is how a system degrades instead of collapsing --- it is a
  deliberate choice to fail some requests fast so the rest succeed.
]
#v(2mm)

#h2("1 · Anatomy of a cascade", c: red)

#pfig("Fig M20.1 · the self-sustaining spiral, and the admission check that breaks it")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.4, 20.6, 2.9, "every route carries a declared priority class · health-check path bypasses shedding, always")

  // the spiral
  ppill(2.0, 0, "sp", "spike, or a node dies", w: 3.8, c: orange)
  pstep(6.8, 0, "qg", "queues grow", "bounded at L = λW = 100", st-auto, n: 1, actor: "service", w: 3.8)
  pstep(11.6, 0, "to", "clients time out", "30s patience · and RETRY", st-dec, n: 2, actor: "client", w: 4.2)
  pstep(16.6, 0, "wa", "load rises", "every response discarded", st-dec, n: 3, actor: "service", w: 4.0)
  ploop("wa.east", "sp.east", 1.95, "the cascade outlives its trigger", c: red)

  line("sp.east", "qg.west", mark: (end: ">"), stroke: miss)
  line("qg.east", "to.west", mark: (end: ">"), stroke: miss)
  line("to.east", "wa.west", mark: (end: ">"), stroke: miss)

  // the break
  pstep(3.2, -3.8, "adm", "admission check", "adaptive limiter · 0.01ms", st-man, n: 4, actor: "server", w: 4.2)
  pdec(8.8, -3.8, "d", "in-flight < 100?", w: 2.3)
  pstep(14.8, -3.8, "srv", "serve at full speed", "50ms, p99 bounded", st-man, n: 5, actor: "service", w: 5.0)
  ppill(19.6, -3.8, "ok", "200 OK", w: 2.4, c: green)
  pstep(8.8, -7.0, "shed", "shed by class", "retries first · 503 + Retry-After", st-dec, n: 6, w: 5.2)

  line("wa.south", (16.6, -2.1), (3.2, -2.1), "adm.north", mark: (end: ">"), stroke: wrap)
  plabel(9.9, -2.1, "`X-Retry: 2` marks a request the system already failed once", c: luma(110))
  line("adm.east", "d.west", mark: (end: ">"), stroke: hot)
  line("d.east", "srv.west", mark: (end: ">"), stroke: hot)
  plabel(11.6, -3.8, "yes", c: green)
  line("d.south", "shed.north", mark: (end: ">"), stroke: except)
  plabel(11.4, -5.4, "no — fail fast, do not queue", c: red, dy: 0)
  line("srv.east", "ok.west", mark: (end: ">"), stroke: hot)
}))
#pcards(
  [L = λW derived from measured throughput and latency, not picked: 2,000 QPS × 50 ms = 100 concurrent],
  [In: admitted work only · Out: a full-speed 200 for the admitted subset, a fast 503/429 for the rest],
  [Netflix `concurrency-limits` (TCP Vegas gradient) · bounded LIFO queue · deadline propagation · retry budget ≈ 10%],
)
#v(1.5mm)

#text(size: 9pt)[
  The defining property is that the cascade #underline(stroke: 1pt + red)[outlives its
  trigger]. Remove the original spike and the system stays down, because retries alone now
  exceed capacity. This is why "wait for it to recover" fails and why restarting the fleet often
  works --- it drops the in-flight backlog.
  #note[Three amplifiers turn a blip into an outage: retries without jitter (Part 1 §6.2),
  unbounded queues, and timeouts longer than the client's patience. Any one of them is survivable;
  together they guarantee the spiral.]
]
#v(2mm)

#h2("2 · Concurrency limits beat rate limits", c: green)

#text(size: 9pt)[
  A rate limit is a guess about capacity made in advance. A
  #text(fill: green, weight: "bold")[concurrency limit] measures it continuously: cap in-flight
  requests, and the limit adapts automatically as the service gets slower or faster.
  #text(fill: purple, weight: "bold")[Adaptive algorithms] (Netflix's `concurrency-limits`,
  borrowing TCP Vegas's congestion control) watch the gradient between minimum and current
  latency and shrink the limit when queueing appears --- before latency becomes visible to users.
]
#v(2mm)

#formula("Little's Law sets the limit")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[L = λW.] Service handles 2,000 QPS at 50 ms
    #sym.arrow.r L = 2,000 × 0.05 = #text(fill: orange, weight: "bold")[100 concurrent requests].
    That is the limit — not a number someone picked.
    #linebreak() #v(1mm)
    #text(weight: "bold")[What happens above it:] admit 200 concurrent and latency doubles to
    100 ms with #underline(stroke: 1pt + red)[no throughput gain] — the extra 100 are queueing,
    not working. Admit 1,000 and latency is 500 ms, by which point every client has timed out and
    every completed response is #text(fill: red, weight: "bold")[discarded work].
    #linebreak() #v(1mm)
    #text(weight: "bold")[Queueing is non-linear.] At 50% utilisation, queue wait ≈ service time.
    At 90% it is #text(fill: orange)[9×]. At 99% it is
    #text(fill: red, weight: "bold")[99×]. This is why the operating target is
    #underline(stroke: 1pt + green)[≤ 70%] — the headroom is not waste, it is the margin that
    keeps latency bounded.
  ]
]
#v(2mm)

#h2("3 · Shedding by priority", c: purple)

#table(
  columns: (auto, auto, 1fr, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#f5eefa") } else { none },
  text(font: headfont, size: 8.5pt, fill: purple)[Class],
  text(font: headfont, size: 8.5pt, fill: purple)[Shed at],
  text(font: headfont, size: 8.5pt, fill: purple)[Examples],
  text(font: headfont, size: 8.5pt, fill: purple)[Response],

  text(size: 8.3pt, fill: red)[Critical],
  text(size: 8.3pt)[never],
  text(size: 8pt)[Checkout, payment, login, health checks],
  text(size: 8.3pt)[serve],

  text(size: 8.3pt, fill: orange)[Important],
  text(size: 8.3pt)[90% load],
  text(size: 8pt)[Order history, profile updates],
  text(size: 8.3pt)[503 + Retry-After],

  text(size: 8.3pt, fill: green)[Optional],
  text(size: 8.3pt)[70% load],
  text(size: 8pt)[Recommendations, related items, analytics beacons],
  text(size: 8.3pt)[empty / cached],

  text(size: 8.3pt, fill: luma(120))[Retries],
  text(size: 8.3pt)[first],
  text(size: 8pt)[Any request carrying a retry marker],
  text(size: 8.3pt)[429],
)
#v(1.5mm)

#key[
  Shed #underline(stroke: 1pt + green)[retries before first attempts]. A retry is work the system
  already failed to do once; a first attempt is a user still waiting. Marking retries (`X-Retry:
  2`) and dropping them first breaks the feedback loop that drives the spiral — and costs one
  header.
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Unbounded queues.] A queue with no limit converts an overload
  into unbounded latency; requests sit for 30 s and are answered long after the client gave up.
  #text(fill: green)[Fix:] bounded queues that reject when full, plus
  #text(fill: purple, weight: "bold")[LIFO under stress] — counter-intuitive, but under overload
  the newest request is the only one whose client might still be waiting. Also drop any request
  whose deadline has already passed before starting work on it.

  #text(fill: red, weight: "bold")[Health check in the shed path.] Load shedding returns 503 to
  everything including the load balancer's probe, so the LB removes every healthy instance and
  the service goes fully dark. #text(fill: green)[Fix:] health checks bypass shedding, always.

  #text(fill: red, weight: "bold")[Retry storm on recovery.] The service comes back and is
  immediately hit by every accumulated retry (Part 1 §6.4).
  #text(fill: green)[Fix:] keep breakers open through recovery, full jitter, and a retry budget
  capping retries at ~10% of traffic.

  #text(fill: red, weight: "bold")[Shedding the wrong thing.] Under load the system drops
  checkout while faithfully serving recommendations, because nobody classified the endpoints.
  #text(fill: green)[Fix:] priority is a #underline(stroke: 1pt + green)[declared property] of
  every route, reviewed like any other config.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Traffic is 10× normal. What happens?]
  #linebreak()
  Concurrency limits cap admission, optional endpoints shed first, retries shed before first
  attempts, and the core path keeps serving at full speed for the subset admitted.
  #note[Testing: do you accept that some requests #underline(stroke: 1pt + green)[must] fail? The
  weak answer is "autoscale" — scaling takes minutes and the cascade takes seconds.]

  #text(fill: green, weight: "bold")[Q: Why not just add more instances?]
  #linebreak()
  Scaling is minutes away and the shared dependency (database, cache) is usually the real
  bottleneck — more instances multiply pressure on it.
  #note[Testing: whether you see that horizontal scaling can #emph[accelerate] a cascade.]

  #text(fill: green, weight: "bold")[Q: How do you pick the concurrency limit?]
  #linebreak()
  Little's Law from measured throughput and latency, or an adaptive limiter that derives it from
  the latency gradient. #note[Testing: a number with a derivation beats a number someone tuned by
  feel.]
]
#v(2mm)

#anti("the unbounded worker queue")[
  A service queues incoming work with no cap, "so nothing is lost". During a spike the queue
  grows to 500,000 items. Every client timed out at 30 s, but workers keep processing a backlog
  whose results #text(fill: red, weight: "bold")[nobody is waiting for], burning full capacity on
  dead work while new requests queue behind it. Memory climbs until the process is OOM-killed,
  losing the queue entirely — the outcome unbounded queueing was meant to prevent.
  #text(fill: green)[Fix:] bounded queue, reject when full, and discard any item whose deadline
  has expired #underline(stroke: 1pt + green)[before] processing it.
]
