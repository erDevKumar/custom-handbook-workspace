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

#pfig("Fig M10.1 · one message across a connection fleet — a gateway only knows its own sockets")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.3, 20.9, 2.6, "L4 LB sticky per connection; 50k sockets per gateway; a persisted log behind the bus so reconnects can replay")

  ppill(1.7, 0, "in", "A sends", w: 3.1)
  pstep(6.0, 0, "g1", "gateway 1", "50k conns · 0.2ms", st-man, n: 1, actor: "A's socket", w: 4.2)
  pdec(10.5, 0, "loc", "B on THIS\ngateway?", w: 1.6)
  pstep(14.9, 0, "bus", "pub/sub fan-out", "Redis · 1ms to all N", st-auto, n: 2, actor: "backplane", w: 4.2)
  ppill(19.1, 0, "out", "B's socket", w: 3.3)

  pstep(6.0, -4.0, "dir", "write the local socket", "no hop · 0.2ms", st-start, n: 3, actor: "gateway 1", w: 5.0)

  line("in.east", "g1.west", mark: (end: ">"), stroke: hot)
  line("g1.east", "loc.west", mark: (end: ">"), stroke: hot)
  line("loc.east", "bus.west", mark: (end: ">"), stroke: async)
  plabel(12.5, 0, "no", c: purple, dy: 0.62)
  line("bus.east", "out.west", mark: (end: ">"), stroke: hot)
  line("loc.south", (10.5, -4.0), "dir.east", mark: (end: ">"), stroke: hot)
  plabel(9.5, -4.0, "yes", c: green, dy: 0.34)
  content((16.0, -4.2), dlbl("Redis pub/sub is fire-and-forget:\na gateway that is briefly disconnected\nmisses those messages permanently.\nBack it with a log clients can replay.", sz: 6.5pt, c: red))
  content((5.7, -6.4), dlbl("most \"we need WebSockets\" requirements are one-way and SSE serves them better", sz: 6.5pt, c: blue))
}))
#pcards(
  [Sticky L4 routing per connection; a drain plan for deploys; a persisted log so clients replay by last-seen id],
  [In: one message · Out: delivered to every subscriber across N gateways. Local 0.2ms, cross-gateway +1ms],
  [L4 load balancer · WebSocket/SSE gateways, 50k conns each · Redis pub/sub or a Kafka backplane],
)
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
