#import "/shared/lib/template.typ": *
#reg(1, "M23", "Coordination & Distributed Locking")
#chapterhead("Part 2 · Modules", "M23 · Distributed Locking")
#ix("Distributed lock")
#ix("Redlock")
#ix("Lease")

#h1("M23 · Coordination & Distributed Locking", c: red)

#text[
  A distributed lock is the most misused primitive in this book. The mechanics are easy; the
  guarantee is not. The question that matters is never "did I acquire the lock" but
  #underline(stroke: 1pt + red)[do I still hold it at the moment my write lands].
]
#v(2mm)

#h2("1 · Why a lock alone is not safety", c: red)

#pfig("Fig M23.1 · the pause no lease survives, and the one check that still rejects the stale write")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.4, 20.6, 2.6, "the lock is for efficiency unless the resource itself validates a token · no network call inside the critical section")

  ppill(1.9, 0, "c1", "client 1 acquires", w: 3.6)
  pstep(6.8, 0, "lease", "lease + token 33", "etcd Raft · 5–15ms RTT", st-auto, n: 1, actor: "lock svc", w: 4.4)
  pstep(12.0, 0, "pause", "stop-the-world pause", "GC / VM migration · unbounded", st-dec, n: 2, actor: "client 1", w: 5.4)
  pstep(17.6, 0, "exp", "lease expires", "C1 cannot know", st-dec, n: 3, actor: "lock svc", w: 3.8)

  line("c1.east", "lease.west", mark: (end: ">"), stroke: hot)
  line("lease.east", "pause.west", mark: (end: ">"), stroke: hot)
  line("pause.east", "exp.west", mark: (end: ">"), stroke: miss)

  pstep(4.0, -3.6, "c2", "client 2 acquires", "token 34 · legitimately", st-man, n: 4, actor: "client 2", w: 4.4)
  pdec(10.2, -3.6, "d", "token ≥ highest seen?", w: 3.0)
  ppill(16.6, -3.6, "ok", "write applied", w: 3.4, c: green)
  pstep(10.2, -7.0, "rej", "write rejected at the resource", "storage layer refuses token 33", st-dec, n: 5, w: 6.8)

  line("exp.south", (17.6, -1.9), (4.0, -1.9), "c2.north", mark: (end: ">"), stroke: wrap)
  plabel(10.8, -1.9, "both clients now believe they hold the lock", c: red)
  line("c2.east", "d.west", mark: (end: ">"), stroke: hot)
  line("d.east", "ok.west", mark: (end: ">"), stroke: hot)
  plabel(13.8, -3.6, "token 34 — yes", c: green)
  line("d.south", "rej.north", mark: (end: ">"), stroke: except)
  plabel(14.2, -5.4, "C1 wakes with token 33 — no", c: red, dy: 0)
}))
#pcards(
  [Monotonic token issued with every grant, and a storage layer that actually compares it — the check must live where the damage would occur],
  [In: two clients, one of them paused past its lease · Out: exactly one applied write; the stale one refused by the resource, not by the lock],
  [etcd / ZooKeeper (Raft, Zab) for the lease and revision · Redis `SET NX PX` only where duplicated work is the worst case · DB CAS where the data already lives],
)
#v(1.5mm)

#text(size: 9pt)[
  Between acquiring a lock and performing the write, a client can stop for an arbitrary period:
  a stop-the-world GC pause, a hypervisor migrating the VM, a severed network, or simply CPU
  starvation. The lease expires, another client legitimately acquires the lock, and then the
  first client wakes up and writes --- #underline(stroke: 1pt + red)[with no way to know it lost
  the lock]. Shortening the lease makes this more likely, not less.
]
#v(2mm)

#key[
  #text(fill: green, weight: "bold")[Fencing tokens] are the only correct answer. Each lock grant
  returns a monotonically increasing number. Every write carries its token, and the
  #underline(stroke: 1pt + green)[storage layer rejects any token lower than the highest it has
  seen]. The stale writer's request is refused by the resource itself — the one place the check
  can be trusted, because it is the place the damage would occur.
]
#v(2mm)

#h2("2 · Where to put the lock", c: purple)

#table(
  columns: (auto, auto, auto, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#f5eefa") } else { none },
  text(font: headfont, size: 8.5pt, fill: purple)[Option],
  text(font: headfont, size: 8.5pt, fill: purple)[Safe?],
  text(font: headfont, size: 8.5pt, fill: purple)[Latency],
  text(font: headfont, size: 8.5pt, fill: purple)[Notes],

  text(size: 8.3pt)[Redis `SET NX PX`],
  text(size: 8.3pt, fill: orange)[efficiency only],
  text(size: 8.3pt, fill: green)[< 1 ms],
  text(size: 8pt)[Fine to avoid duplicate work. #text(fill: red)[Never] for correctness],

  text(size: 8.3pt)[Redlock],
  text(size: 8.3pt, fill: red)[contested],
  text(size: 8.3pt, fill: green)[few ms],
  text(size: 8pt)[Kleppmann's critique stands: relies on bounded clock drift and pauses],

  text(size: 8.3pt, fill: green)[etcd / ZooKeeper],
  text(size: 8.3pt, fill: green)[yes, with fencing],
  text(size: 8.3pt, fill: orange)[~10 ms],
  text(size: 8pt)[Raft/Zab consensus; leases with a monotonic revision to fence on],

  text(size: 8.3pt, fill: green)[DB row lock / CAS],
  text(size: 8.3pt, fill: green)[yes],
  text(size: 8.3pt, fill: green)[fast],
  text(size: 8pt)[If the data is already in one DB, the lock belongs there too],
)
#v(1.5mm)

#text(size: 9pt)[
  #text(fill: purple, weight: "bold")[Efficiency versus correctness.] Kleppmann's framing is the
  one to carry into an interview. If the lock exists so two workers do not
  #emph[duplicate effort] — regenerating the same thumbnail — a Redis lock is perfectly
  adequate; the worst case is wasted CPU. If the lock exists so two workers do not
  #emph[corrupt data] — both writing a file, both decrementing a balance — you need consensus
  plus fencing, or no lock at all and an atomic operation instead.
]
#v(2mm)

#h2("3 · Capacity arithmetic", c: orange)

#formula("Lock throughput and the better alternative")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[Serialisation ceiling:] a lock held for #text(weight: "bold")[T]
    permits #text(weight: "bold")[1/T] operations per second on that key. T = 10 ms
    #sym.arrow.r #text(fill: orange, weight: "bold")[100/s]. T = 100 ms (an HTTP call inside the
    critical section) #sym.arrow.r #text(fill: red, weight: "bold")[10/s], regardless of how many
    workers you run.
    #linebreak() #v(1mm)
    #text(weight: "bold")[etcd cost:] every acquire is a Raft write = a majority round trip
    ≈ 5–15 ms. 1,000 locks/s is #text(fill: orange, weight: "bold")[1,000 consensus writes/s] —
    near the practical limit of a 3-node etcd cluster, and it is now a
    #underline(stroke: 1pt + red)[tier-0 dependency of your application].
    #linebreak() #v(1mm)
    #text(fill: green, weight: "bold")[Usually you do not need the lock.] An idempotency key plus
    a unique constraint gives the same guarantee with
    #underline(stroke: 1pt + green)[no coordination]: let both workers proceed, and let the
    database reject the second insert. Throughput becomes the database's write rate — thousands
    per second — instead of 1/T.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Releasing someone else's lock.] A client times out, the lease
  expires, another client acquires it, and the first client's `DEL lock` releases the
  #underline(stroke: 1pt + red)[new owner's] lock. #text(fill: green)[Fix:] store a unique value
  with the lock and release with a Lua script that compares before deleting —
  check-and-delete must be atomic.

  #text(fill: red, weight: "bold")[Lock held across a crash.] The worker dies holding the lock
  and nothing is released. #text(fill: green)[Fix:] always a TTL, never an indefinite lock, with
  heartbeat extension for long work — and the heartbeat must stop if the work stops.

  #text(fill: red, weight: "bold")[The lock service becomes tier-0.] Every request now depends on
  etcd being healthy. #text(fill: green)[Fix:] lock only the operations that genuinely require
  mutual exclusion, and define behaviour when the lock service is unreachable: refuse (safe) or
  proceed (fast) — a decision made in advance, per operation.

  #text(fill: red, weight: "bold")[Lock convoy.] Many workers queue on one lock; each acquisition
  costs a context switch and a round trip, so throughput collapses while CPU looks idle.
  #text(fill: green)[Fix:] shard the lock by key, or redesign so the work does not need
  exclusion.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Implement a distributed lock with Redis.]
  #linebreak()
  `SET key uuid NX PX 30000`, release via a Lua compare-and-delete. Then say the important part:
  this is safe for #underline(stroke: 1pt + green)[efficiency], not correctness, because a paused
  client can write after its lease expires. #note[Testing: the follow-up is always "what if the
  client pauses?" Answering it before being asked is the senior signal.]

  #text(fill: green, weight: "bold")[Q: What is a fencing token?]
  #linebreak()
  A monotonically increasing number issued with the lock and validated at the resource, so a
  stale holder's write is rejected where it would land. #note[Testing: the single most
  load-bearing idea in distributed locking.]

  #text(fill: green, weight: "bold")[Q: How do you avoid needing a lock at all?]
  #linebreak()
  Idempotency keys with a unique constraint, atomic conditional updates, single-writer
  partitioning, or CRDTs. #note[Testing: judgement. The best distributed lock is the one you
  designed out of the system.]
]
#v(2mm)

#anti("Redlock for correctness-critical work")[
  A team uses Redlock to ensure only one worker writes a financial report file. Redlock acquires
  a majority across five independent Redis nodes — which sounds like quorum safety but is not:
  the algorithm assumes #text(fill: red, weight: "bold")[bounded clock drift and bounded process
  pauses], and neither is guaranteed on a real machine. A GC pause longer than the lease, or a
  clock jump from NTP, and two workers write the same file.
  #underline(stroke: 1pt + red)[Adding more Redis nodes does not help] — the flaw is temporal,
  not quorum-related. #text(fill: green)[Fix:] etcd or ZooKeeper with fencing tokens enforced at
  the storage layer, or make the write itself atomic and idempotent so concurrency is harmless.
]
