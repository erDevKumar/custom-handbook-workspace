#import "/shared/lib/template.typ": *
// CHAPTER-HEAD: Part 2 · Modules | M3 · Consensus & Replication
#reg(1, "M3", "Consensus & Replication")
#chapterhead("Part 2 · Modules", "M3 · Consensus & Replication")
#ix("Raft")
#ix("Quorum")
#ix("Fencing token")
#ix("CRDT")
#ix("Last-write-wins")

#h1("M3 · Consensus & Replication", c: red)

#text[
  Consensus is how a group of machines agrees on #underline(stroke: 1pt + green)[one] value
  despite crashes, delays and lost messages. You need it far less often than you think --- and in
  exactly the places where getting it wrong corrupts data: leader election, cluster membership,
  distributed locks, and ordered logs.
]
#v(2mm)

#h2("1 · Raft — consensus you can actually reason about", c: red)

#text(size: 9pt)[
  Raft (Ongaro & Ousterhout, 2014) was designed explicitly for understandability after a decade
  of Paxos being correct but unimplementable. It decomposes the problem into three parts:
  #text(fill: blue, weight: "bold")[leader election], #text(fill: green, weight: "bold")[log
  replication], and #text(fill: purple, weight: "bold")[safety].

  Time is divided into #text(fill: purple)[terms], each with at most one leader. A follower that
  hears nothing for its election timeout (randomised, typically 150--300ms) becomes a candidate,
  increments the term and requests votes. A node grants one vote per term, so a candidate winning
  a #underline(stroke: 1pt + green)[majority] is unique. All writes go through the leader, which
  appends to its log, replicates, and commits once a majority has acknowledged.
]
#v(2mm)

#pfig("Fig M3.1 · Raft write path — the client hears nothing until a majority has acked")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.3, 20.9, 2.6, "a leader elected for the current term; 5 voting members; election timeout 150-300ms, randomised")

  ppill(1.55, 0, "in", "write x=5", w: 2.8)
  pstep(5.9, 0, "ld", "leader appends", "term 7 idx 42 · 0.1ms", st-dec, n: 1, actor: "leader", w: 4.2)
  pstep(10.7, 0, "rep", "AppendEntries", "4 followers · RTT 2ms", st-auto, n: 2, actor: "replication", w: 4.2)
  pdec(15.3, 0, "q", "3 of 5\nacked?", w: 1.6)
  ppill(19.25, 0, "out", "committed", w: 3.0)

  pstep(15.3, -4.0, "blk", "no commit, no reply", "leader blocks and retries", st-dec, n: 3, actor: "leader", w: 4.8)

  line("in.east", "ld.west", mark: (end: ">"), stroke: hot)
  line("ld.east", "rep.west", mark: (end: ">"), stroke: hot)
  line("rep.east", "q.west", mark: (end: ">"), stroke: hot)
  line("q.east", "out.west", mark: (end: ">"), stroke: hot)
  plabel(17.45, 0, "yes", c: green, dy: 0.62)
  line("q.south", "blk.north", mark: (end: ">"), stroke: except)
  plabel(17.1, -2.1, "minority", c: red, dy: 0)
  content((6.4, -4.2), dlbl("quorum = floor(N/2)+1 = 3 of 5, so two members may be\ndown or lagging and the write still commits. A lagging\nfollower catches up later — it never blocks the commit.", sz: 6.5pt, c: purple))
  content((10.3, -6.4), dlbl("the leader retries AppendEntries until a majority acks or the term ends; the client is told nothing until the entry is applied", sz: 6.5pt, c: blue))
}))
#pcards(
  [A stable leader for the term; an odd member count; each member fsyncs its log before it acks],
  [In: one write · Out: committed only after a majority ack — never reply early. Tolerates 2 of 5 down],
  [Raft (Ongaro 2014) · etcd / Consul / CockroachDB · a fencing token on every lock handoff],
)
#v(2mm)

#h2("2 · Replication models compared", c: purple)

#table(
  columns: (auto, auto, auto, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#f5eefa") } else { none },
  text(font: headfont, size: 8.5pt, fill: purple)[Model],
  text(font: headfont, size: 8.5pt, fill: purple)[Durability],
  text(font: headfont, size: 8.5pt, fill: purple)[Write cost],
  text(font: headfont, size: 8.5pt, fill: purple)[When],

  text(size: 8.3pt)[Async primary/replica],
  text(size: 8pt, fill: red)[loses recent writes],
  text(size: 8pt, fill: green)[1 local fsync],
  text(size: 8pt)[read scaling; RPO > 0 acceptable],

  text(size: 8.3pt)[Sync primary/replica],
  text(size: 8pt, fill: green)[RPO = 0],
  text(size: 8pt, fill: red)[+1 network RTT],
  text(size: 8pt)[ledgers; replica failure blocks writes],

  text(size: 8.3pt)[Raft / Paxos quorum],
  text(size: 8pt, fill: green)[RPO = 0, survives N/2-1],
  text(size: 8pt, fill: orange)[majority RTT],
  text(size: 8pt)[metadata, locks, ordered logs],

  text(size: 8.3pt)[Multi-leader],
  text(size: 8pt, fill: orange)[converges],
  text(size: 8pt, fill: green)[local write],
  text(size: 8pt)[multi-region writes + conflict policy],

  text(size: 8.3pt)[Leaderless (Dynamo)],
  text(size: 8pt, fill: orange)[tunable R+W>N],
  text(size: 8pt, fill: green)[W acks],
  text(size: 8pt)[high availability, per-query tuning],
)
#v(2mm)

#h2("3 · Conflict resolution — LWW vs CRDT", c: orange)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Last-Write-Wins] compares timestamps and keeps the newer value.
  It is trivial to implement and it #underline(stroke: 1pt + red)[silently discards data]: two
  concurrent writes, one simply vanishes. Worse, it depends on wall clocks, so a node with 50ms
  of clock skew can "win" with an older value.

  #text(fill: green, weight: "bold")[CRDTs] (Shapiro et al., 2011) are types whose merge is
  commutative, associative and idempotent --- so replicas converge regardless of message order or
  duplication, with #text(fill: green)[no coordination]. A G-Counter merges by taking the max per
  replica; an OR-Set tracks adds and removes with unique tags.
  #note[The cost is metadata growth and semantics you must accept: in an OR-Set, a concurrent
  add and remove resolves to #text(fill: purple)[add wins]. That is a product decision, not an
  implementation detail — make it explicitly.]
]
#v(2mm)

#formula("Quorum arithmetic — R + W > N")[
  #text(size: 8.6pt)[
    N = 5 replicas. #text(weight: "bold")[W=3, R=3:] 3+3 > 5 #sym.arrow.r sets overlap in at
    least one node #sym.arrow.r #text(fill: green, weight: "bold")[strong reads]; survives
    #text(fill: green)[2] failures.
    #linebreak()
    #text(weight: "bold")[W=1, R=1:] 1+1 < 5 #sym.arrow.r
    #text(fill: red, weight: "bold")[eventual]; fastest; may read arbitrarily stale data.
    #linebreak()
    #text(weight: "bold")[W=5, R=1:] fast reads, but #text(fill: red)[any single node down blocks
    every write].
    #linebreak() #v(1mm)
    #text(weight: "bold")[Fault tolerance of a Raft group:] N=3 tolerates 1; N=5 tolerates 2;
    N=7 tolerates 3. Beyond 5--7, the majority RTT grows faster than the availability gain ---
    #text(fill: purple)[bigger clusters are slower, not safer].
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Split brain via a paused leader.] A leader is GC-paused or
  network-isolated for 20 seconds. The cluster elects a new one. The old leader resumes,
  #underline(stroke: 1pt + red)[still believing it holds the lock], and writes.
  #text(fill: green)[Fix:] #text(fill: purple, weight: "bold")[fencing tokens] --- every lock
  grant carries a monotonically increasing number, and the storage layer rejects any write
  carrying a token lower than the highest it has seen. The stale leader's write is refused by the
  resource itself, which is the only place the check can be trusted.

  #text(fill: red, weight: "bold")[Even-sized clusters.] N=4 tolerates only 1 failure, exactly
  like N=3, while costing more and making every write wait for 3 acks instead of 2.
  #text(fill: green)[Always use an odd N.]

  #text(fill: red, weight: "bold")[Slow follower drags the quorum.] Commit waits for the
  #text(fill: orange)[majority], so your write latency is the
  #underline(stroke: 1pt + red)[median] follower's latency, not the fastest. One degraded disk in
  a 5-node group silently raises p99 for the whole cluster.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Why is Raft preferred over Paxos?]
  #linebreak()
  Same guarantees, far clearer decomposition: election, replication, safety --- with a single
  strong leader rather than Paxos's concurrent proposers. #note[Testing: do you know they solve
  the same problem? The weak answer claims Raft is "better"; the right one says it is more
  implementable, which is why etcd, Consul and TiKV use it.]

  #text(fill: green, weight: "bold")[Q: A lock service says you hold the lock. Is that enough?]
  #linebreak()
  No. Between the grant and your write, you may pause and the lease may expire. You need fencing
  tokens checked at the resource. #note[Testing: the single most important distributed-systems
  insight --- #underline(stroke: 1pt + red)[a lock alone is not safety]. This is the question
  that separates candidates who have read Kleppmann from those who have not.]

  #text(fill: green, weight: "bold")[Q: When do you NOT need consensus?]
  #linebreak()
  Whenever operations commute or a conflict can be merged — counters, sets, caches, analytics
  events. #note[Testing: judgement. Consensus costs a majority round trip on every write; a
  candidate who reaches for it everywhere has not understood the price.]
]
#v(2mm)

#anti("using a distributed lock without fencing")[
  A job uses Redis `SETNX` as a lock before writing a file. The holder stops for 15s --- GC pause,
  VM migration, a stop-the-world --- and the lock expires. Another worker acquires it and starts
  writing. The first worker wakes and writes too, #text(fill: red, weight: "bold")[with no idea it
  lost the lock]. Both succeed; the file is corrupted. No timeout tuning fixes this, because the
  pause can always exceed the lease. #text(fill: green)[Fix:] fencing tokens enforced at the
  storage layer, or an engine with compare-and-set on a version the writer must present.
]
