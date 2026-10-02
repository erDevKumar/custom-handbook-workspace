#import "/shared/lib/template.typ": *
#reg(1, "S7", "Presence for 50M concurrent users")
#chapterhead("Part 3 · Interview Scenarios", "S7 · Global Presence System")

#h1("S7 · Presence at 50M Concurrent", c: blue)

#text[
  #text(fill: purple, weight: "bold")[The prompt.] Online, offline, last-seen — for 50 million
  simultaneously connected users, globally. It looks like a trivial boolean per user. It is one
  of the highest write-rate systems you will ever design.
]
#v(2mm)

#h2("1 · The dilemma and its root cause", c: red)

#text(size: 9pt)[
  Presence is deceptive because the #underline(stroke: 1pt + green)[state] is tiny and the
  #underline(stroke: 1pt + red)[churn] is enormous. Every user transition is a write, every
  heartbeat is a potential write, and every subscriber to that user's status is a fan-out. A
  social graph turns 50M users into billions of potential notifications.

  #text(fill: purple, weight: "bold")[Root cause of naive designs.] Treating presence as
  durable state in a database. It is #text(fill: green, weight: "bold")[ephemeral, approximate
  and self-expiring] — three properties that permit a design no transactional store can match.
]
#v(2mm)

#formula("The write and fan-out arithmetic")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[Naive heartbeat writes:] 50M users × 1 heartbeat / 30 s =
    #text(fill: red, weight: "bold")[1.67M writes/s] of pure keepalive. No database accepts this
    economically.
    #linebreak()
    #text(fill: green, weight: "bold")[Fix — do not write heartbeats.] The connection's existence
    #emph[is] the presence. The gateway holding the socket (M10) knows who is online; it writes
    only #underline(stroke: 1pt + green)[transitions], not heartbeats.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Transitions:] with an average session of 20 minutes, 50M users produce
    50,000,000 / 1,200 = #text(fill: orange, weight: "bold")[~42,000 transitions/s] — three
    orders of magnitude smaller, and tractable.
    #linebreak() #v(1mm)
    #text(fill: red, weight: "bold")[Fan-out is the real problem:] 42,000 transitions/s × 150
    contacts each = #text(fill: red, weight: "bold")[6.3M notifications/s] if you push every
    change to every contact.
    #linebreak()
    #text(fill: green, weight: "bold")[Fix — subscribe, do not broadcast.] Only notify watchers
    of users whose presence is #underline(stroke: 1pt + green)[currently on screen]. A user
    viewing a chat list watches ~20 people, not 150, and only while that screen is open. This cuts
    fan-out by 10–50× and is the single most important decision in the design.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Memory:] 50M × 64 B (user id, state, timestamp, gateway id) =
    #text(fill: green, weight: "bold")[3.2 GB] — the entire global presence state fits in a
    sharded Redis cluster with room to spare.
  ]
]
#v(2mm)

#h2("2 · The design", c: green)

#align(center, cetz.canvas(length: 0.8cm, {
  import cetz.draw: *
  swimlane(-0.4, -2.2, 18.4, 2.0, "PRESENCE = CONNECTION STATE + TTL", blue, rgb("#f4f8fd"))
  rnode(2.4, 1.0, "u", "clients", "WebSocket", purple, w: 3.0, h: 0.95)
  rnode(6.8, 1.0, "gw", "edge gateways", "own the sockets", blue, w: 3.8, h: 0.95)
  rnode(11.4, 1.0, "r", "Redis shard", "SETEX ttl=45s", green, w: 3.6, h: 0.95)
  rnode(16.2, 1.0, "sub", "subscription fan-out", "on-screen watchers only", orange, w: 4.2, h: 0.95)
  line("u.east", "gw.west", mark: (end: ">"), stroke: hot)
  line("gw.east", "r.west", mark: (end: ">"), stroke: hot);  badge(9.2, 1.55, "1", green)
  line("r.east", "sub.west", mark: (end: ">"), stroke: async); badge(13.9, 1.55, "2", purple)
  content((9.0, -0.1), dlbl("TTL expiry IS the offline event — no reaper, no tombstones", sz: 6.6pt, c: green))
  content((9.0, -0.8), dlbl("gateway crash → keys expire in 45 s → users correctly show offline",
    sz: 6.5pt, c: green))
  content((9.0, -1.6), dlbl("last_seen written to durable storage only on transition to offline",
    sz: 6.5pt, c: purple))
}))
#v(1.5mm)

#text(size: 9pt)[
  #text(fill: green, weight: "bold")[TTL is the whole mechanism.] The gateway refreshes a key
  with a 45-second expiry while the socket is alive. If the gateway dies, the process crashes, or
  the network partitions, the keys simply expire and those users become offline
  #underline(stroke: 1pt + green)[automatically and correctly] — no cleanup job, no stale state,
  no reconciliation after a crash. This property is why Redis is the right store and a relational
  database is not.

  #text(fill: orange, weight: "bold")[Last-seen is a different problem.] It is durable, read
  rarely, and written once per session end. Write it to the primary datastore on the
  offline transition only — never on every heartbeat. #note[Last-seen also carries privacy
  obligations: it reveals behavioural patterns (sleep schedule, working hours). Make it a user
  setting, and honour it at the API, not in the client.]
]
#v(2mm)

#key[
  Presence is #underline(stroke: 1pt + green)[allowed to be wrong for a few seconds], and that
  tolerance is what makes 50M concurrent feasible. Accepting a 45-second worst-case staleness
  removes the need for durability, reaping, consensus and cross-region coordination. A design
  that insists presence be exact will not scale past a fraction of this load.
]
#v(2mm)

#h2("3 · SEM execution strategy", c: purple)

#text(size: 8.9pt)[
  #text(fill: purple, weight: "bold")[Set the accuracy SLO explicitly, early.]
  #text(fill: green)["Presence is accurate within 60 seconds; last-seen within 5 minutes."] This
  single line removes months of argument and is the lever that makes the architecture simple.
  Product will ask for instant accuracy; the cost of that request is a different system by an
  order of magnitude, and your job is to price it rather than absorb it silently.

  #text(fill: purple, weight: "bold")[Regional ownership, not global replication.] Presence is
  regional: users see contacts' status served from their own region, with cross-region presence
  propagated asynchronously and allowed to lag. Replicating 42,000 transitions/s globally and
  synchronously would be the most expensive and least necessary part of the system (M27).

  #text(fill: purple, weight: "bold")[Blast radius.] The deploy is the recurring risk, not the
  disaster: restarting gateways disconnects millions and triggers a reconnect storm (M10). Drain
  with jittered reconnect windows, and treat
  #underline(stroke: 1pt + green)[reconnect capacity as the real peak load] — it exceeds steady
  state by a wide margin and must be the number you provision against.

  #text(fill: purple, weight: "bold")[Team.] Two to three engineers for the core, but the
  dependency is the connection fleet (M10). If that does not exist yet, it is the larger project
  and presence rides on top of it — say so in planning rather than discovering it in month two.

  #text(fill: purple, weight: "bold")[What to monitor.] Not CPU: track
  #text(weight: "bold")[connections per gateway], #text(weight: "bold")[transition rate],
  #text(weight: "bold")[fan-out amplification] and #text(weight: "bold")[reconnect rate]. A
  rising reconnect rate is the leading indicator of every presence incident.
]
#v(2mm)

#anti("storing presence in the primary database")[
  Presence is modelled as `users.is_online` with a `last_heartbeat` column, updated every 30
  seconds. At 50M users that is #text(fill: red, weight: "bold")[1.67M UPDATEs/s] against the
  primary — more write traffic than the entire rest of the product combined. Every update dirties
  a page, bloats WAL, saturates replication, and competes with
  #underline(stroke: 1pt + red)[real business transactions]. Worse, a gateway crash leaves users
  permanently marked online until a reaper job notices, so the data is wrong in exactly the way
  presence must not be. #text(fill: green)[Fix:] ephemeral state in Redis with TTL expiry as the
  offline mechanism, and durable writes only for last-seen, once per session.
]
