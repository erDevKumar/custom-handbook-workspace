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

#align(center, cetz.canvas(length: 0.88cm, {
  import cetz.draw: *
  swimlane(-0.3, -4.2, 7.9, 1.6, "VERTICAL (scale up)", blue, rgb("#f4f8fd"))
  rnode(3.8, 0.1, "big", "one bigger box", "64 -> 128 vCPU · 1TB RAM", blue, w: 5.2, h: 1.4)
  content((3.8, -1.5), dlbl("ceiling: largest SKU money can buy", sz: 6.8pt, c: red))
  content((3.8, -2.2), dlbl("blast radius: 1 (it IS the system)", sz: 6.8pt, c: red))
  content((3.8, -2.9), dlbl("resize = restart on most platforms", sz: 6.8pt, c: red))
  content((3.8, -3.6), dlbl("cost curve: superlinear past mid-range", sz: 6.8pt, c: orange))

  swimlane(8.6, -4.2, 18.3, 1.6, "HORIZONTAL (scale out)", green, rgb("#f6fbf7"))
  rnode(11.0, 0.5, "n1", "n1", "8 vCPU", green, w: 2.3, h: 0.95)
  rnode(13.8, 0.5, "n2", "n2", "8 vCPU", green, w: 2.3, h: 0.95)
  rnode(16.6, 0.5, "n3", "n3", "8 vCPU", green, w: 2.3, h: 0.95)
  rnode(13.8, -2.1, "lb", "load balancer", "health checks · least-conn", green, w: 5.0, h: 1.1)
  line("n1.south", (11.0, -1.1), (13.8, -1.1), "lb.north", stroke: hot)
  line("n2.south", "lb.north", stroke: hot)
  line("n3.south", (16.6, -1.1), (13.8, -1.1), "lb.north", stroke: hot)
  content((13.8, -3.1), dlbl("ceiling: coordination cost", sz: 6.8pt, c: orange))
  content((13.8, -3.8), dlbl("lose 1 node = lose 1/N capacity", sz: 6.8pt, c: green))
  bracket(8.9, 18.0, -4.6, "add nodes AND a coordination strategy", purple)
}))
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

#align(center, cetz.canvas(length: 0.86cm, {
  import cetz.draw: *
  swimlane(-0.3, -1.4, 18.3, 2.6, "STATELESS — any node serves any request", green, rgb("#f6fbf7"))
  rnode(2.4, 0.9, "c1", "client", "no affinity", blue, w: 2.8, h: 1.0)
  rnode(6.6, 0.9, "lb1", "load balancer", "round-robin", blue, w: 3.2, h: 1.0)
  rnode(11.0, 1.7, "s1", "svc A", "stateless pod", green, w: 2.8, h: 0.9)
  rnode(11.0, 0.1, "s2", "svc B", "stateless pod", green, w: 2.8, h: 0.9)
  rnode(15.8, 0.9, "db1", "session store", "Redis · TTL 30m", purple, w: 3.6, h: 1.1)
  line("c1.east", "lb1.west", mark: (end: ">"), stroke: hot)
  line("lb1.east", "s1.west", mark: (end: ">"), stroke: hot)
  line("lb1.east", "s2.west", mark: (end: ">"), stroke: hot)
  line("s1.east", "db1.west", mark: (end: ">"), stroke: async)
  line("s2.east", "db1.west", mark: (end: ">"), stroke: async)
  content((13.6, -0.9), dlbl("state pushed OUT -> any pod is disposable", sz: 6.6pt, c: green))

  swimlane(-0.3, -6.6, 18.3, -2.2, "STATEFUL — this client must reach THIS node", red, rgb("#fdf0ee"))
  rnode(2.4, -4.2, "c2", "client", "pinned", blue, w: 2.8, h: 1.0)
  rnode(6.8, -4.2, "lb2", "load balancer", "sticky / affinity", red, w: 3.4, h: 1.0)
  rnode(11.6, -3.4, "t1", "node 1", "[session in RAM]", red, w: 3.2, h: 0.95)
  rnode(11.6, -5.2, "t2", "node 2", "[session in RAM]", red, w: 3.2, h: 0.95)
  line("c2.east", "lb2.west", mark: (end: ">"), stroke: hot)
  line("lb2.east", "t1.west", mark: (end: ">"), stroke: miss)
  content((16.2, -3.4), dlbl("node dies ->", sz: 6.6pt, c: red))
  content((16.2, -4.1), dlbl("session lost,", sz: 6.6pt, c: red))
  content((16.2, -4.8), dlbl("user logged out", sz: 6.6pt, c: red))
  content((11.6, -6.2), dlbl("deploy = log everyone out · no rebalancing", sz: 6.6pt, c: red))
}))
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

#align(center, cetz.canvas(length: 0.86cm, {
  import cetz.draw: *
  swimlane(-0.3, -3.6, 8.6, 1.7, "THREAD-PER-REQUEST", blue, rgb("#f4f8fd"))
  rnode(1.9, 0.9, "r1", "req 1", "", blue, w: 1.9, h: 0.7)
  rnode(1.9, -0.4, "r2", "req 2", "", blue, w: 1.9, h: 0.7)
  rnode(1.9, -1.7, "r3", "req 3", "", blue, w: 1.9, h: 0.7)
  rnode(5.3, 0.9, "t1", "thread 1", "~1MB stack", orange, w: 2.6, h: 0.75)
  rnode(5.3, -0.4, "t2", "thread 2", "~1MB stack", orange, w: 2.6, h: 0.75)
  rnode(5.3, -1.7, "t3", "thread 3", "~1MB stack", orange, w: 2.6, h: 0.75)
  line("r1.east", "t1.west", mark: (end: ">"), stroke: hot)
  line("r2.east", "t2.west", mark: (end: ">"), stroke: hot)
  line("r3.east", "t3.west", mark: (end: ">"), stroke: hot)
  content((7.6, 0.9), dlbl("BLOCKED", sz: 6.2pt, c: red))
  content((7.6, -0.4), dlbl("BLOCKED", sz: 6.2pt, c: red))
  content((7.6, -1.7), dlbl("running", sz: 6.2pt, c: green))
  content((4.2, -2.5), dlbl("10k concurrent = 10k threads = 10GB stacks", sz: 6.5pt, c: red))
  content((4.2, -3.1), dlbl("CPU burns on context switching", sz: 6.5pt, c: red))

  swimlane(9.4, -3.6, 18.3, 1.7, "EVENT LOOP", green, rgb("#f6fbf7"))
  rnode(11.2, 0.9, "e1", "req 1", "", blue, w: 1.9, h: 0.7)
  rnode(11.2, -0.4, "e2", "req 2", "", blue, w: 1.9, h: 0.7)
  rnode(11.2, -1.7, "e3", "req 3", "", blue, w: 1.9, h: 0.7)
  rnode(14.6, -0.4, "loop", "event loop", "1 thread / core", green, w: 3.2, h: 1.9)
  line("e1.east", "loop.west", mark: (end: ">"), stroke: hot)
  line("e2.east", "loop.west", mark: (end: ">"), stroke: hot)
  line("e3.east", "loop.west", mark: (end: ">"), stroke: hot)
  rnode(17.3, -0.4, "q", "epoll", "readiness", purple, w: 2.0, h: 1.3)
  line("loop.east", "q.west", mark: (end: ">"), stroke: lookup)
  content((14.0, -2.5), dlbl("100k idle conns = a few hundred bytes each", sz: 6.5pt, c: green))
  content((14.0, -3.1), dlbl("BUT: one blocking call stalls EVERYONE", sz: 6.5pt, c: red))
}))
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
