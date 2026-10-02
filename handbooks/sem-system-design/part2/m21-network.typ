#import "/shared/lib/template.typ": *
#reg(1, "M21", "Network Protocols & Edge Optimisation")
#chapterhead("Part 2 · Modules", "M21 · Network Protocols & Edge")
#ix("QUIC")
#ix("HTTP/3")
#ix("Head-of-line blocking")
#ix("Anycast")

#h1("M21 · Network Protocols & Edge", c: green)

#text[
  On a datacentre network the protocol barely matters. On a mobile network it dominates: packet
  loss, 200 ms round trips, and an IP address that changes when the user walks out of a café.
  Every improvement from HTTP/1.1 to HTTP/3 targets one thing ---
  #underline(stroke: 1pt + green)[fewer round trips, and no shared fate between streams].
]
#v(2mm)

#h2("1 · The protocol ladder", c: blue)

#align(center, cetz.canvas(length: 0.82cm, {
  import cetz.draw: *
  swimlane(-0.4, -2.1, 18.4, 2.3, "CONNECTION SETUP — round trips before the first byte", blue,
    rgb("#f4f8fd"))
  let lane(y, lbl, segs, total, c) = {
    content((1.9, y), dlbl(lbl, sz: 6.8pt, c: c))
    let x = 3.6
    for s in segs {
      rect((x, y - 0.26), (x + s.at(1), y + 0.26), stroke: 0.9pt + s.at(2), fill: white)
      content((x + s.at(1) / 2, y), dlbl(s.at(0), sz: 5.8pt, c: ink))
      x = x + s.at(1) + 0.12
    }
    content((x + 1.0, y), dlbl(total, sz: 6.6pt, c: c))
  }
  lane(1.5, "HTTP/1.1 + TLS", (("TCP", 2.2, blue), ("TLS 1.2", 4.4, orange), ("req", 2.2, green)), "3 RTT", red)
  lane(0.5, "HTTP/2 + TLS 1.3", (("TCP", 2.2, blue), ("TLS 1.3", 2.2, orange), ("req", 2.2, green)), "2 RTT", orange)
  lane(-0.5, "HTTP/3 (QUIC)", (("QUIC + TLS", 2.2, purple), ("req", 2.2, green)), "1 RTT", green)
  lane(-1.5, "HTTP/3 resumed", (("0-RTT + req", 2.2, green),), "0 RTT", green)
  content((13.6, -1.5), dlbl("← repeat visit: data rides the first packet", sz: 6.3pt, c: green))
}))
#v(1.5mm)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[HTTP/1.1] allows one in-flight request per connection, so
  browsers open six and everything else queues.
  #text(fill: orange, weight: "bold")[HTTP/2] multiplexes streams over one TCP connection ---
  but TCP guarantees ordered delivery of the #underline(stroke: 1pt + red)[whole byte stream], so
  a single lost packet stalls #text(fill: red)[every] multiplexed stream. That is
  #text(fill: red, weight: "bold")[head-of-line blocking at the transport layer], and it makes
  HTTP/2 worse than HTTP/1.1 on a lossy mobile link.

  #text(fill: green, weight: "bold")[HTTP/3] moves to QUIC over UDP, implementing ordering
  per-stream in userspace. A lost packet stalls only its own stream. It also merges the transport
  and TLS handshakes into one round trip.
]
#v(2mm)

#key[
  QUIC's decisive mobile feature is #text(fill: purple, weight: "bold")[connection migration]. A
  TCP connection is identified by the 4-tuple, so changing IP — Wi-Fi to cellular — kills it and
  forces a full reconnect. QUIC identifies connections by a
  #underline(stroke: 1pt + green)[connection ID], so the session survives the network change with
  no new handshake. For an app that rides in a pocket, this matters more than throughput.
]
#v(2mm)

#h2("2 · TCP vs UDP vs QUIC", c: purple)

#table(
  columns: (auto, auto, auto, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#f5eefa") } else { none },
  text(font: headfont, size: 8.5pt, fill: purple)[Property],
  text(font: headfont, size: 8.5pt, fill: purple)[TCP],
  text(font: headfont, size: 8.5pt, fill: purple)[UDP],
  text(font: headfont, size: 8.5pt, fill: purple)[QUIC],

  text(size: 8.3pt)[Ordering], text(size: 8.3pt, fill: orange)[whole stream],
  text(size: 8.3pt, fill: red)[none], text(size: 8.3pt, fill: green)[per stream],
  text(size: 8.3pt)[Handshake], text(size: 8.3pt)[1 RTT + TLS],
  text(size: 8.3pt, fill: green)[none], text(size: 8.3pt, fill: green)[1 RTT, 0 on resume],
  text(size: 8.3pt)[HOL blocking], text(size: 8.3pt, fill: red)[yes],
  text(size: 8.3pt, fill: green)[n/a], text(size: 8.3pt, fill: green)[no],
  text(size: 8.3pt)[IP change], text(size: 8.3pt, fill: red)[connection dies],
  text(size: 8.3pt, fill: green)[stateless], text(size: 8.3pt, fill: green)[migrates],
  text(size: 8.3pt)[Implemented in], text(size: 8.3pt)[kernel],
  text(size: 8.3pt)[kernel], text(size: 8.3pt, fill: orange)[userspace — more CPU],
  text(size: 8.3pt)[Use for], text(size: 8.3pt)[everything legacy],
  text(size: 8.3pt)[realtime media, games], text(size: 8.3pt, fill: green)[mobile APIs, web],
)
#v(2mm)

#h2("3 · Capacity arithmetic", c: orange)

#formula("What a round trip actually costs a mobile user")[
  #text(size: 8.6pt)[
    4G RTT ≈ #text(weight: "bold")[70 ms]; a congested or rural link is 200 ms+.
    #linebreak()
    HTTP/1.1 cold: 3 RTT handshake = #text(fill: red, weight: "bold")[210 ms] before the request
    is even sent. HTTP/3: 1 RTT = #text(fill: green, weight: "bold")[70 ms]. On resume:
    #text(fill: green, weight: "bold")[0 ms].
    #linebreak() #v(1mm)
    #text(weight: "bold")[Now multiply by the API design.] A screen needing 6 sequential calls on
    HTTP/1.1 with no keep-alive: 6 × (210 + 70) =
    #text(fill: red, weight: "bold")[1,680 ms] of pure network. The same screen on one HTTP/3
    connection with a BFF aggregating (M6): 70 + 70 =
    #text(fill: green, weight: "bold")[140 ms]. A #text(weight: "bold")[12×] difference, with no
    change to the backend at all.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Anycast:] one IP advertised from many locations; BGP routes each user
    to the topologically nearest. Cross-continent 150 ms collapses to a regional
    #text(fill: green, weight: "bold")[10–30 ms] for TLS termination, after which traffic rides
    the provider's optimised backbone.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[UDP blocked.] Some corporate and carrier networks drop UDP
  entirely, so QUIC never connects. #text(fill: green)[Fix:] always advertise HTTP/3 via
  `Alt-Svc` over a working HTTP/2 connection, and keep TCP as the fallback. Never ship
  QUIC-only.

  #text(fill: red, weight: "bold")[0-RTT replay.] Data sent in the first packet of a resumed
  session can be captured and replayed by an attacker --- it has no round-trip proof of
  freshness. #text(fill: green)[Fix:] permit 0-RTT only for
  #underline(stroke: 1pt + green)[idempotent] requests. Never for a POST that moves money.

  #text(fill: red, weight: "bold")[Carrier NAT timeout.] Mobile NAT mappings expire after
  30–60 s of silence, so a long-lived connection dies invisibly (M10).
  #text(fill: green)[Fix:] application-level keepalive inside that window; QUIC's `PING` frame
  serves this directly.

  #text(fill: red, weight: "bold")[MTU and fragmentation.] QUIC avoids IP fragmentation by
  probing path MTU; a misconfigured middlebox that blackholes large packets produces a connection
  that completes its handshake and then stalls. #text(fill: green)[Fix:] conservative initial
  datagram size and PMTU discovery enabled.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Why is HTTP/3 better for mobile?]
  #linebreak()
  No transport-level head-of-line blocking under packet loss, a 1-RTT (or 0-RTT) handshake, and
  connection migration across network changes. #note[Testing: do you know HTTP/2 can be
  #underline(stroke: 1pt + red)[worse] than HTTP/1.1 on a lossy link? That is the insight behind
  QUIC's existence.]

  #text(fill: green, weight: "bold")[Q: When would you choose raw UDP?]
  #linebreak()
  Real-time media and games, where a late packet is worthless and retransmission hurts — you want
  the next frame, not the lost one. #note[Testing: whether you can name a case where reliability
  is the wrong default.]

  #text(fill: green, weight: "bold")[Q: What does Anycast give you?]
  #linebreak()
  One IP, many locations, BGP steering to the nearest — lower RTT for TLS and an
  absorbing surface for DDoS. #note[Testing: that edge termination is latency work, not just
  caching.]
]
#v(2mm)

#anti("optimising the backend while ignoring the network")[
  A team spends a quarter cutting server p99 from 120 ms to 40 ms. Users report no improvement,
  because the app makes #text(fill: red, weight: "bold")[eight sequential calls] over
  connections that renegotiate TLS each time: 8 × 280 ms of network against 80 ms of saved
  compute. The measurable work was real and
  #underline(stroke: 1pt + red)[entirely irrelevant to the experience].
  #text(fill: green)[Fix:] measure from the client (M19), then attack round trips first ---
  connection reuse, HTTP/3, aggregation at a BFF, and parallel rather than sequential calls.
  Backend latency is usually the smallest term in the sum.
]
