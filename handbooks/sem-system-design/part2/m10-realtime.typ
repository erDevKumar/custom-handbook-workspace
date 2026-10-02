#import "/shared/lib/template.typ": *
#reg(1, "M10", "Bidirectional Real-Time Communication")
#chapterhead("Part 2 · Modules", "M10 · Real-Time Communication")
#ix("WebSocket")
#ix("Server-Sent Events")
#ix("Connection draining")

#h1("M10 · Real-Time Communication", c: blue)

#text[
  Request/response is wrong whenever the #underline(stroke: 1pt + green)[server] knows something
  first. The options differ less in capability than in what they cost you operationally: a
  connection you hold open is a resource you must drain, migrate and pay for while it sits idle.
]
#v(2mm)

#h2("1 · The four transports", c: blue)

#table(
  columns: (auto, auto, auto, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#eef4fb") } else { none },
  text(font: headfont, size: 8.5pt, fill: blue)[Transport],
  text(font: headfont, size: 8.5pt, fill: blue)[Direction],
  text(font: headfont, size: 8.5pt, fill: blue)[Cost],
  text(font: headfont, size: 8.5pt, fill: blue)[Use when],

  text(size: 8.3pt)[Polling],
  text(size: 8.3pt)[client pulls],
  text(size: 8.3pt, fill: red)[wasteful],
  text(size: 8pt)[Updates are rare and latency tolerance is high. Simplest to operate],

  text(size: 8.3pt)[Long polling],
  text(size: 8.3pt)[client pulls, server holds],
  text(size: 8.3pt, fill: orange)[a conn each],
  text(size: 8pt)[Proxies hostile to WebSockets; a reliable fallback],

  text(size: 8.3pt, fill: green)[SSE],
  text(size: 8.3pt)[server → client],
  text(size: 8.3pt, fill: green)[cheap],
  text(size: 8pt)[#underline(stroke: 1pt + green)[One-way] feeds: notifications, live scores,
    progress. Plain HTTP, auto-reconnect built in],

  text(size: 8.3pt, fill: green)[WebSocket],
  text(size: 8.3pt)[both ways],
  text(size: 8.3pt, fill: orange)[stateful],
  text(size: 8pt)[Genuine bidirectional chat, collaboration, games],
)
#v(2mm)

#key[
  Most "we need WebSockets" requirements are one-directional and are better served by
  #text(fill: green, weight: "bold")[SSE] --- which is ordinary HTTP, survives proxies, reconnects
  itself, and needs no new protocol at the edge. Choose WebSocket when the
  #underline(stroke: 1pt + green)[client] must also push continuously, not merely sometimes.
]
#v(2mm)

#h2("2 · Fan-out across a connection fleet", c: green)

#align(center, cetz.canvas(length: 0.82cm, {
  import cetz.draw: *
  swimlane(-0.4, -1.6, 18.4, 2.4, "CONNECTION FLEET", blue, rgb("#f4f8fd"))
  rnode(2.4, 1.3, "u1", "250k clients", "mobile · flaky", purple, w: 3.8, h: 0.9)
  rnode(7.6, 1.3, "lb", "L4 load balancer", "sticky by conn", blue, w: 4.2, h: 0.9)
  line("u1.east", "lb.west", mark: (end: ">"), stroke: hot)

  rnode(13.0, 1.9, "g1", "gateway 1", "50k conns", green, w: 3.2, h: 0.75)
  rnode(13.0, 0.75, "g2", "gateway 2", "50k conns", green, w: 3.2, h: 0.75)
  rnode(13.0, -0.4, "g3", "gateway N", "50k conns", green, w: 3.2, h: 0.75)
  line("lb.east", "g1.west", mark: (end: ">"), stroke: hot)
  line("lb.east", "g2.west", mark: (end: ">"), stroke: hot)
  line("lb.east", "g3.west", mark: (end: ">"), stroke: hot)

  rnode(9.0, -3.3, "bus", "Redis pub/sub backplane", "or Kafka — fan-out to all gateways", purple,
    w: 7.4, h: 1.0)
  line("g1.south", (13.0, -2.3), (9.0, -2.3), "bus.north", mark: (end: ">"), stroke: async)
  line("g2.south", (13.0, -2.3), (9.0, -2.3), "bus.north", mark: (end: ">"), stroke: async)
  content((16.0, -2.4), dlbl("a gateway only knows ITS OWN", sz: 6.3pt, c: red))
  content((16.0, -3.0), dlbl("connections — hence the bus", sz: 6.3pt, c: red))
  bracket(0.6, 17.0, -4.3, "publish once -> every gateway delivers to its local subscribers", purple)
}))
#v(1.5mm)

#text(size: 9pt)[
  The structural problem: user A is connected to gateway 1, user B to gateway 7. When A sends a
  message for B, gateway 1 has #underline(stroke: 1pt + red)[no socket to B]. Something must
  route between gateways --- a Redis pub/sub channel per room, or a Kafka topic partitioned by
  room. #note[Redis pub/sub is fire-and-forget: a gateway that is briefly disconnected
  #text(fill: red)[misses messages permanently]. For chat where history matters, back it with a
  persisted log and have clients request missed messages on reconnect by last-seen id.]
]
#v(2mm)

#h2("3 · Capacity arithmetic", c: orange)

#formula("What 1M concurrent connections actually costs")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[Memory:] ~10 KB per idle WebSocket (kernel buffers + app state)
    #sym.arrow.r 1,000,000 × 10 KB = #text(fill: orange, weight: "bold")[10 GB] just to hold
    them open, before a single message is sent.
    #linebreak()
    #text(weight: "bold")[Gateways:] 50,000 connections per node is a safe practical ceiling
    (file descriptors, epoll, GC pressure) #sym.arrow.r
    #text(fill: orange, weight: "bold")[20 nodes] minimum, +50% for failover and rolling deploys
    #sym.arrow.r #text(fill: green, weight: "bold")[30 nodes].
    #linebreak() #v(1mm)
    #text(weight: "bold")[Heartbeats:] carrier NAT tables drop idle mappings after
    #text(fill: red)[30–60s], so a ping every 25s is required or mobile connections die silently.
    1M connections × 1 ping / 25 s = #text(fill: orange, weight: "bold")[40,000 pings/s] inbound
    — pure overhead you must provision for.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Reconnect storm:] if one gateway holding 50k connections dies, all 50k
    reconnect at once. Without jitter that is a #text(fill: red, weight: "bold")[50,000 QPS
    spike] of TLS handshakes and auth checks onto the survivors — which can take them down too.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Deploy drops every connection.] A rolling restart terminates
  sockets; every client reconnects simultaneously.
  #text(fill: green)[Fix:] connection draining --- stop accepting new connections, send a
  "please reconnect" frame with a #underline(stroke: 1pt + green)[randomised delay], and let
  clients migrate over minutes rather than milliseconds.

  #text(fill: red, weight: "bold")[Silent death on mobile.] The device moves from Wi-Fi to
  cellular; the socket is dead but neither side has noticed. The app shows "connected" and
  receives nothing. #text(fill: green)[Fix:] application-level heartbeat with a timeout, not TCP
  keepalive (whose default is ~2 hours). Treat a missed pong as a disconnect.

  #text(fill: red, weight: "bold")[Backpressure ignored.] A slow client cannot drain its socket;
  the server buffers unboundedly until it runs out of memory.
  #text(fill: green)[Fix:] bounded per-connection queues and an explicit policy — drop the
  oldest for a live feed, or disconnect the client and let it resync.

  #text(fill: red, weight: "bold")[Fan-out amplification.] A message to a 100,000-member channel
  is 100,000 socket writes. #text(fill: green)[Fix:] cap channel size, shard large channels, and
  for very large broadcasts prefer a pull model with a cached snapshot over per-connection push.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: WebSocket or SSE?]
  #linebreak()
  SSE unless the client needs to push continuously. SSE is plain HTTP, reconnects automatically,
  and passes through proxies that mishandle upgrades. #note[Testing: do you default to the
  heavier tool? Choosing SSE and explaining why is a stronger answer than defaulting to
  WebSocket.]

  #text(fill: green, weight: "bold")[Q: How do you deploy without dropping 1M connections?]
  #linebreak()
  Drain gradually with jittered reconnect instructions; never restart the fleet at once.
  #note[Testing: operational experience. Most candidates design the happy path and never
  consider that a deploy is a mass-disconnect event.]

  #text(fill: green, weight: "bold")[Q: User A and user B are on different gateways. How does
  the message get there?]
  #linebreak()
  A backplane --- Redis pub/sub or a Kafka topic keyed by room --- that every gateway subscribes
  to. #note[Testing: whether you spotted that connection state is #emph[per node]. Candidates
  often draw one box labelled "WebSocket server" and never confront fan-out.]
]
#v(2mm)

#anti("stateful connections without a drain plan")[
  A team ships WebSockets and scales to 500k connections. The first rolling deploy disconnects
  everyone within seconds; all 500k clients reconnect immediately with no backoff. The
  reconnection flood overwhelms the auth service, which fails, so clients retry harder. The
  #text(fill: red, weight: "bold")[deploy becomes a self-inflicted outage] lasting far longer
  than the deploy itself. #text(fill: green)[Fix:] drain gracefully, jitter every reconnect, and
  load-test the reconnect storm --- it is the real peak load of a real-time system, not steady
  state.
]
