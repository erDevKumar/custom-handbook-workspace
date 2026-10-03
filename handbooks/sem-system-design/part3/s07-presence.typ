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

#pfig("Fig S7.1 · presence at 50M concurrent — the socket IS the state, and TTL expiry IS the offline event")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.3, 20.7, 3.0, "45s staleness accepted as a product decision; last-seen privacy honoured at the API; sockets held at the edge")

  ppill(1.44, 0, "conn", "socket opens", w: 2.8)
  pstep(5.66, 0, "gw", "gateway owns it", "no heartbeat write", st-start, n: 1, actor: "edge", w: 4.8)
  pstep(10.87, 0, "setex", "SETEX user:42 45", "Redis · 3.2GB total", st-auto, n: 2, actor: "presence svc", w: 4.8)
  pdec(15.69, 0, "ref", "refreshed\nwithin 45s?")
  ppill(19.56, 0, "online", "shown online", w: 2.8)

  pstep(10.6, -3.6, "exp", "key expires", "the offline event itself", st-integ, n: 3, actor: "redis", w: 4.8)
  pstep(5.0, -3.6, "sub", "notify watchers", "42k/s × 20, not × 150", st-auto, n: 4, actor: "fan-out", w: 4.8)
  pstep(16.4, -3.6, "ls", "write last_seen", "on transition · Postgres", st-auto, n: 5, actor: "presence svc", w: 4.8)

  line("conn.east", "gw.west", mark: (end: ">"), stroke: hot)
  line("gw.east", "setex.west", mark: (end: ">"), stroke: hot)
  line("setex.east", "ref.west", mark: (end: ">"), stroke: hot)
  line("ref.east", "online.west", mark: (end: ">"), stroke: hot)
  plabel(17.5, 0, "yes", c: green, dy: 0.44)
  line("ref.south", (15.69, -3.6), "exp.east", mark: (end: ">"), stroke: except)
  plabel(13.6, -2.4, "no — crash or partition", c: red, dy: 0.0)
  line("exp.west", "sub.east", mark: (end: ">"), stroke: async)
  line("exp.north", (10.6, -1.8), (20.0, -1.8), (20.0, -3.6), "ls.east", mark: (end: ">"), stroke: cold)
  plabel(13.5, -1.8, "never on heartbeat", c: orange, dy: 0.34)

  ploop("sub.south", "setex.south", -5.6, "re-SETEX every 20s while the socket lives — no reaper, no tombstones", c: blue)
}))
#pcards(
  [Presence treated as ephemeral and approximate, never as durable state; subscription set bounded by what is on screen; a 45s worst-case staleness the product has signed off],
  [In: 50M live sockets, refreshed in-gateway · Out: ~42,000 online/offline transitions/s fanned out only to on-screen watchers; `last_seen` written once per session end],
  [WebSocket gateways (M10) · sharded Redis with `SETEX ttl=45` · subscription-scoped fan-out · Postgres for durable `last_seen`],
)
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
