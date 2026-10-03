#import "/shared/lib/template.typ": *
// CHAPTER-HEAD: Part 1 · Core Architectural Foundations | 1 · Scalability Mechanics
#reg(1, "1", "Scalability Mechanics")
#chapterhead("Part 1 · Core Architectural Foundations", "1 · Scalability Mechanics")
#ix("Amdahl's Law")
#ix("Gustafson's Law")
#ix("Stateless design")
#ix("Event loop")
#ix("Thread-per-request")

#h1("1. Scalability Mechanics", c: blue)

#text[
  Scalability is #text(fill: red, weight: "bold")[not] speed. A system is scalable when adding
  resources buys a #underline(stroke: 1pt + green)[proportional] increase in useful throughput.
  A system can be very fast and not scale at all --- it simply hits a wall sooner.
  The interview question is almost never "make it faster"; it is
  #text(fill: purple)[where does this stop scaling, and why].
]
#v(2.5mm)

// ---------------------------------------------------------------- 1.1 --------
#h2("1.1  Vertical vs. Horizontal", c: blue)

#pfig("Fig 1.1 · the two ways to add capacity, and what each one buys")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.6, 20.6, 3.6, "traffic is measured, the bottleneck is identified, and the migration has a quarter — not a sprint")

  ppill(2.4, 0, "load", "rising load")

  // VERTICAL — one box grows
  pstep(7.4, 1.5, "up", "scale UP", "64 → 128 vCPU · 1TB RAM", st-start,
    n: 1, actor: "one machine", w: 4.4)
  pstep(7.4, -1.6, "out", "scale OUT", "N × 8 vCPU behind an LB", st-man,
    n: 2, actor: "a fleet", w: 4.4)

  line("load.east", (4.6, 0), (4.6, 1.5), "up.west", mark: (end: ">"), stroke: hot)
  line("load.east", (4.6, 0), (4.6, -1.6), "out.west", mark: (end: ">"), stroke: hot)

  pdec(13.0, 1.5, "cap", "biggest SKU?", w: 2.1)
  pdec(13.0, -1.6, "coord", "coordination?", w: 2.1)
  line("up.east", "cap.west", mark: (end: ">"), stroke: hot)
  line("out.east", "coord.west", mark: (end: ">"), stroke: hot)

  pstep(18.4, 1.5, "wall", "hard ceiling", "resize = restart", st-dec,
    n: 3, actor: "blast radius 1", w: 3.8)
  pstep(18.4, -1.6, "cost", "soft ceiling", "coordination cost", st-man,
    n: 4, actor: "lose 1 node = 1/N", w: 3.8)
  line("cap.east", "wall.west", mark: (end: ">"), stroke: miss)
  plabel(14.9, 1.5, "yes", c: red)
  line("coord.east", "cost.west", mark: (end: ">"), stroke: hot)
  plabel(14.9, -1.6, "then", c: green)

  content((7.4, -3.4), dlbl("cost curve goes superlinear past mid-range", sz: 6.5pt, c: orange))
  content((15.2, -3.4), dlbl("partial failure · clock skew · cache coherence", sz: 6.5pt, c: purple))
  bracket(5.0, 20.4, -4.1, "you do not just add nodes — you add nodes AND a coordination strategy", purple)
}))
#plegend(
  ("happy path", hot), ("failure / fallthrough", miss),
  ("async", async), ("probe", lookup), ("return rail", loopbk),
)
#pcards(
  [A measured bottleneck, and headroom to migrate before the ceiling is hit.],
  [In: rising request rate. Out: either a bigger SKU, or N interchangeable nodes plus a load balancer.],
  [Cloud instance SKUs · load balancer with health checks and least-conn · an autoscaler.],
)
#v(1.5mm)

#text[
  #text(fill: blue, weight: "bold")[Vertical] keeps the programming model intact --- one process,
  one memory space, no network in the middle. That is its real value: you keep using locks and
  pointers instead of consensus and retries. It dies for three reasons. There is a biggest
  machine. The resize usually costs a restart. And one failure takes the whole system.

  #text(fill: green, weight: "bold")[Horizontal] removes the ceiling but imports a new universe
  of problems: partial failure, clock skew, retries, cache coherence across nodes, and the
  question of #text(fill: purple)[where state lives]. You do not "just add nodes" --- you add
  nodes #underline(stroke: 1pt + green)[and a coordination strategy].
  #note[Practical order of operations: scale up first, because it is cheap and preserves
  simplicity. Scale out when you hit a real ceiling --- and before you hit it, because the
  migration takes a quarter, not a sprint.]
]
#v(2mm)

// ---------------------------------------------------------------- 1.2 --------
#h2("1.2  Amdahl’s Law — the ceiling nobody budgets for", c: orange)

#formula("Amdahl (1967)")[
  #align(center, text(size: 12pt)[S(N) = 1 / ( s + (1 - s) / N )])
  #v(1.5mm)
  #text(size: 8.8pt)[
    #text(weight: "bold")[s] = the serial fraction that cannot be parallelised.
    #text(weight: "bold")[N] = processors. #text(weight: "bold")[S] = speedup over one processor.
  ]
]
#v(2mm)

#text[
  Worked example. A request spends #text(fill: orange, weight: "bold")[5%] of its time in a
  section that cannot run concurrently --- a single-writer index update, say. So s = 0.05.
]
#v(1.5mm)

#table(
  columns: (auto, 1fr, auto, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#fff3e8") } else { none },
  text(font: headfont, size: 9pt, fill: orange)[N],
  text(font: headfont, size: 9pt, fill: orange)[Arithmetic],
  text(font: headfont, size: 9pt, fill: orange)[Speedup],
  text(font: headfont, size: 9pt, fill: orange)[Efficiency],

  text(size: 9pt)[1],   text(size: 8.5pt)[1 / (0.05 + 0.95/1) = 1 / 1.0],
  text(size: 9pt)[1.00x], text(size: 9pt, fill: green)[100%],

  text(size: 9pt)[10],  text(size: 8.5pt)[1 / (0.05 + 0.095) = 1 / 0.145],
  text(size: 9pt)[6.90x], text(size: 9pt, fill: green)[69%],

  text(size: 9pt)[100], text(size: 8.5pt)[1 / (0.05 + 0.0095) = 1 / 0.0595],
  text(size: 9pt)[16.81x], text(size: 9pt, fill: orange)[17%],

  text(size: 9pt)[1000],text(size: 8.5pt)[1 / (0.05 + 0.00095) = 1 / 0.05095],
  text(size: 9pt)[19.63x], text(size: 9pt, fill: red)[2%],

  text(size: 9pt, weight: "bold")[#sym.infinity],
  text(size: 8.5pt)[1 / 0.05],
  text(size: 9pt, weight: "bold", fill: red)[20.00x],
  text(size: 9pt, fill: red)[0%],
)
#v(2mm)

#key[
  5% serial work caps you at #text(fill: red, weight: "bold")[20x] forever. Going from 100 to
  1000 cores --- a #text(fill: red)[10x] bill --- buys 2.8x more speedup and burns
  #text(fill: red, weight: "bold")[98%] of the hardware. The asymptote is
  #text(fill: orange, weight: "bold")[1/s]. Find s before you buy anything.
]
#v(2mm)

#text[
  #text(fill: purple, weight: "bold")[The counterpoint you should also know.] Gustafson (1988)
  observed that in practice we do not hold the problem size fixed --- we grow it. If the
  parallel portion scales with the data while the serial part stays constant, speedup becomes
  roughly linear again. #note[Amdahl governs fixed-size latency ("make this one request
  faster"). Gustafson governs throughput at growing scale ("serve 10x the users"). Interviewers
  asking about scaling usually mean Gustafson's world --- but the serial section still bounds
  any single request's latency, and that is where p99 comes from.]
]
#v(2mm)

#anti("\"just add more replicas\"")[
  The reflex when a service saturates is to raise the replica count. If the bottleneck is a
  #underline(stroke: 1pt + red)[serial section] --- a single-writer database, a shared advisory
  lock, a leader election, one hot partition --- replicas do not divide the work, they
  #text(fill: red, weight: "bold")[queue] for it. Throughput flattens while p99 climbs, because
  each new replica adds a competitor for the same lock. Measure the serial fraction
  #text(fill: green)[first]: profile where the request actually blocks, not where it spends CPU.
]
#v(2.5mm)

// ---------------------------------------------------------------- 1.3 --------
#h2("1.3  Stateless vs. Stateful — where the boundary goes", c: purple)

#text[
  "Stateless" does not mean the system has no state. It means #text(fill: purple)[this process]
  holds no state that cannot be rebuilt from somewhere else. That is the property that makes a
  node disposable --- and disposability is what horizontal scaling actually requires. You can
  only load-balance across nodes that are interchangeable.
]
#v(2mm)

#pfig("Fig 1.2 · state never disappears, it relocates — and that is what makes a node disposable")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  swimlane(-0.6, -1.3, 20.6, 2.6, "STATELESS", green, rgb("#f6fbf7"))
  content((7.4, 2.25), dlbl("— any node serves any request", sz: 6.8pt, c: green))
  ppill(2.2, 0.6, "c1", "client · no affinity", w: 4.0)
  pstep(7.2, 0.6, "lb1", "load balancer", "round-robin · no stickiness", st-start,
    n: 1, actor: "edge", w: 4.0)
  pstep(11.8, 1.3, "p1", "pod A", "stateless · killable", st-man, n: 2, actor: "svc", w: 3.4, h: 1.1)
  pstep(11.8, -0.3, "p2", "pod B", "stateless · killable", st-man, n: 2, actor: "svc", w: 3.4, h: 1.1)
  pstep(18.2, 0.6, "sess", "session store", "Redis · TTL 30m · ~1ms", st-auto,
    n: 3, actor: "shared, replicated", w: 4.2)
  line("c1.east", "lb1.west", mark: (end: ">"), stroke: hot)
  line("lb1.east", "p1.west", mark: (end: ">"), stroke: hot)
  line("lb1.east", "p2.west", mark: (end: ">"), stroke: hot)
  line("p1.east", "sess.west", mark: (end: ">"), stroke: async)
  line("p2.east", "sess.west", mark: (end: ">"), stroke: async)
  content((14.8, -0.95), dlbl("state pushed OUT", sz: 6.4pt, c: purple))

  swimlane(-0.6, -8.0, 20.6, -3.2, "STATEFUL", red, rgb("#fdf0ee"))
  content((7.6, -3.55), dlbl("— this client must reach THIS node", sz: 6.8pt, c: red))
  ppill(2.2, -5.0, "c2", "client · pinned", c: red, w: 4.0)
  pstep(7.2, -5.0, "lb2", "load balancer", "sticky / session affinity", st-dec,
    n: 1, actor: "edge", w: 4.0)
  pstep(12.8, -4.3, "n1", "node 1", "[session in RAM]", st-dec, n: 2, actor: "always this one", w: 3.4, h: 1.1)
  pstep(12.8, -5.9, "n2", "node 2", "[other sessions]", st-dec, n: 2, actor: "svc", w: 3.4, h: 1.1)
  pdec(18.2, -4.3, "die", "node dies?", w: 2.1)
  line("c2.east", "lb2.west", mark: (end: ">"), stroke: hot)
  line("lb2.east", "n1.west", mark: (end: ">"), stroke: hot)
  plabel(10.3, -4.3, "sticky", c: red, dy: 0.42)
  line("n1.east", "die.west", mark: (end: ">"), stroke: miss)
  content((18.2, -6.0), dlbl("session lost ·", sz: 6.4pt, c: red))
  content((18.2, -6.6), dlbl("user logged out", sz: 6.4pt, c: red))
  content((7.4, -7.3), dlbl("deploy = log everyone out · no rebalancing", sz: 6.4pt, c: red))
}))
#pcards(
  [An external store exists and is on the critical path; or the protocol genuinely needs a pinned connection.],
  [In: a request with a session cookie. Out: a response — from any pod (top) or from exactly one node (bottom).],
  [L7 load balancer · Kubernetes pods · Redis / Memcached session store · connection draining on the sticky path.],
)
#v(1.5mm)

#text[
  State never disappears --- it #text(fill: purple, weight: "bold")[relocates]. Making a service
  stateless means moving session, cart, and connection state into a store that is itself
  stateful and now on the critical path. You have not removed the hard problem; you have
  #underline(stroke: 1pt + green)[concentrated] it into one system you can replicate, back up,
  and reason about deliberately, instead of scattering it across every pod.
  #note[The honest trade: a stateless tier costs you a network hop per request to fetch what
  used to be in local memory. You pay ~1ms to gain the ability to kill any pod at any time.
  For most services that is the best trade in distributed systems.]
]
#v(2mm)

#compare(
  "STATELESS WINS:",
  [rolling deploys, autoscaling, spot instances, zero-downtime restarts, trivial load
   balancing. Any node can die mid-request.],
  "STATEFUL IS FORCED:",
  [WebSocket fan-out, in-memory game state, leader nodes, large local caches. Then you need
   sticky routing, draining, and a state-transfer plan.],
)
#v(2mm)

#anti("sticky sessions as a scaling strategy")[
  Session affinity looks like it solves the problem --- the user keeps hitting the node that
  has their data, so reads are fast. It silently breaks everything else.
  #text(fill: red)[Load becomes uneven] (a long-lived heavy user pins to one node and you cannot
  rebalance). #text(fill: red)[Deploys become destructive] (restarting a node logs out everyone
  on it). #text(fill: red)[Autoscaling stops working] (new nodes get no traffic from existing
  users). Use affinity only where the protocol genuinely demands it --- a live WebSocket --- and
  pair it with connection draining, never as a substitute for externalising state.
]
#v(2.5mm)

// ---------------------------------------------------------------- 1.4 --------
#h2("1.4  Thread-per-request vs. Event-loop I/O", c: green)

#text[
  Both models serve concurrent requests. They differ in what a waiting request
  #text(fill: purple)[costs] while it waits --- and almost every request spends most of its life
  waiting on something else's network or disk.
]
#v(2mm)

#pfig("Fig 1.3 · what a waiting request costs in each concurrency model")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  swimlane(-0.6, -2.0, 20.6, 2.4, "THREAD-PER-REQUEST", blue, rgb("#f4f8fd"))
  content((8.0, 2.05), dlbl("— one waiter per request", sz: 6.8pt, c: blue))
  ppill(2.2, 0.4, "ti", "10k requests")
  pstep(7.4, 0.4, "th", "accept", "1 thread each · ~1MB stack", st-start,
    n: 1, actor: "kernel", w: 4.2)
  pdec(12.8, 0.4, "tw", "I/O done?", w: 2.1)
  pstep(18.0, 0.4, "tr", "respond", "10GB of stacks resident", st-dec, n: 2, actor: "", w: 3.6)
  line("ti.east", "th.west", mark: (end: ">"), stroke: hot)
  line("th.east", "tw.west", mark: (end: ">"), stroke: hot)
  line("tw.east", "tr.west", mark: (end: ">"), stroke: hot)
  plabel(15.6, 0.4, "yes", c: green)
  ploop("tw.south", "th.south", -1.3, "no → thread BLOCKS, holding its stack", c: red)

  swimlane(-0.6, -8.6, 20.6, -4.0, "EVENT LOOP", green, rgb("#f6fbf7"))
  content((6.0, -4.35), dlbl("— one waiter per core", sz: 6.8pt, c: green))
  ppill(2.2, -6.0, "ei", "100k conns")
  pstep(7.4, -6.0, "el", "event loop", "1 thread / core", st-man,
    n: 1, actor: "runtime", w: 4.2)
  pstep(12.8, -6.0, "ep", "epoll / kqueue", "readiness · ~200 B each", st-auto,
    n: 2, actor: "kernel", w: 4.2)
  pstep(18.0, -6.0, "er", "resume cb", "no stack parked", st-man, n: 3, actor: "", w: 3.6)
  line("ei.east", "el.west", mark: (end: ">"), stroke: hot)
  line("el.east", "ep.west", mark: (end: ">"), stroke: lookup)
  line("ep.east", "er.west", mark: (end: ">"), stroke: hot)
  plabel(15.6, -6.0, "ready", c: green)
  ploop("er.south", "el.south", -7.5, "callback returns → loop picks the next ready fd", c: green)
  content((10.2, -9.5), dlbl("BUT one blocking call on this loop stalls EVERY other request", sz: 7pt, c: red))
}))
#pcards(
  [Workload classified I/O-bound or CPU-bound first; on the loop, every library on the path must be non-blocking.],
  [In: 10k–100k concurrent connections. Out: responses — paid for in RAM and context switches (top) or in blocking risk (bottom).],
  [OS threads and the kernel scheduler · epoll / kqueue · Node, Netty, nginx, Envoy · a worker pool for CPU work.],
)
#v(1.5mm)

#text[
  #text(fill: blue, weight: "bold")[Thread-per-request] is simple and debuggable: a stack trace
  shows the whole request, and blocking code is correct code. The cost is the thread itself ---
  roughly 1MB of stack, plus kernel scheduling. At 10,000 concurrent slow requests you need
  10,000 threads, and the machine spends its time
  #text(fill: red)[context-switching instead of working].

  #text(fill: green, weight: "bold")[Event loop] keeps one thread per core and parks waiting
  work as a callback with a few hundred bytes of state. 100,000 idle connections are nearly
  free, which is why it dominates proxies, gateways, and WebSocket fan-out.
  #note[The catch, and it is severe: ONE blocking call --- a synchronous file read, a CPU-heavy
  JSON parse, a regex backtracking --- stalls every other request on that loop. In the threaded
  model, one slow request blocks one thread. In the loop model, it blocks everyone.]
]
#v(2mm)

#key[
  Choose by workload, not fashion. #text(fill: red, weight: "bold")[I/O-bound]
  (proxy, gateway, chat fan-out, API aggregation) #sym.arrow event loop.
  #text(fill: orange, weight: "bold")[CPU-bound] (transcode, ML inference, compression)
  #sym.arrow threads or a worker pool --- an event loop gives you nothing when the CPU is the
  bottleneck, and makes debugging worse. Modern virtual threads (Java 21, Go goroutines) blur
  this: cheap stacks plus blocking-style code.
]
#v(2mm)

#anti("blocking inside the event loop")[
  A team moves to an async runtime for throughput, then calls a synchronous library ---
  `JSON.parse` on a 10MB payload, a blocking DB driver, `fs.readFileSync` --- inside a handler.
  Throughput #text(fill: red, weight: "bold")[collapses below] the threaded version it replaced,
  and the symptom is baffling: p50 stays fine while p99 explodes, because one slow request
  delays an entire batch behind it. #text(fill: green)[Fix:] move CPU work to a worker pool,
  and treat "is every library on this path non-blocking" as a release gate, not a code review
  preference.
]
