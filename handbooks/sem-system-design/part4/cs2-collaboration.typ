#import "/shared/lib/template.typ": *
#reg(1, "CS2", "Real-Time Collaborative Workspace")
#chapterhead("Part 4 · Case Studies", "CS2 · Collaborative Workspace")

#h1("CS2 · Collaborative Workspace & Media", c: blue)

#text[
  A Figma/Slack/Docs hybrid: many people editing one document simultaneously, chat alongside it,
  and media uploads. The defining constraint is that
  #underline(stroke: 1pt + green)[two people will edit the same character at the same instant],
  and the system must produce one answer both of them accept without asking either.
]
#v(2mm)

#h2("1 · Requirements", c: blue)

#grid(columns: (1fr, 1fr), gutter: 4mm,
  block(inset: 2.5mm, radius: 2pt, fill: rgb("#eef7f1"), stroke: (left: 2pt + green))[
    #text(size: 8.4pt)[#text(fill: green, weight: "bold")[Functional] \
      Concurrent editing with live cursors and presence \
      Offline editing, reconciled on reconnect \
      Comments, threads, \@mentions \
      File upload, preview generation, inline media \
      Fine-grained sharing: org / team / doc / element]
  ],
  block(inset: 2.5mm, radius: 2pt, fill: rgb("#f4f8fd"), stroke: (left: 2pt + blue))[
    #text(size: 8.4pt)[#text(fill: blue, weight: "bold")[Non-functional] \
      #text(weight: "bold")[Local echo < 16 ms] (one frame) \
      #text(weight: "bold")[Remote propagation p99 < 200 ms] \
      100 concurrent editors per document \
      #text(weight: "bold")[No lost edits, ever] — the product promise \
      Permission check p99 < 10 ms]
  ])
#v(1.5mm)

#text(size: 8.8pt)[
  #text(fill: purple, weight: "bold")[The requirement that dictates the architecture:] local echo
  under 16 ms means edits apply #underline(stroke: 1pt + red)[before any server confirms them].
  The client is therefore authoritative for its own view, and the server's job is convergence, not
  validation-then-apply. Every subsequent decision follows from this.
]
#v(2mm)

#h2("2 · Capacity estimation", c: orange)

#formula("Edit traffic, fan-out and permission load")[
  #text(size: 8.5pt)[
    #text(weight: "bold")[Edit rate.] Active typing ≈ 5 keystrokes/s. A doc with 20 active
    editors = 100 ops/s, fanned out to 20 clients =
    #text(fill: orange, weight: "bold")[2,000 messages/s per busy document].
    #linebreak()
    10,000 concurrent busy documents #sym.arrow.r
    #text(fill: red, weight: "bold")[20M messages/s] if naively broadcast.
    #linebreak()
    #text(fill: green, weight: "bold")[Batching at 50 ms] collapses 5 keystrokes into 1 message
    #sym.arrow.r #text(fill: green, weight: "bold")[4M/s], and
    #underline(stroke: 1pt + green)[50 ms is still well inside the 200 ms budget]. This single
    decision is a 5× infrastructure saving.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Connections.] 500k concurrent users × ~10 KB per WebSocket =
    #text(weight: "bold")[5 GB] of connection state; at 50k conns/node that is
    #text(fill: orange, weight: "bold")[10 gateway nodes], ×1.5 for deploys = 15 (M10).
    #linebreak() #v(1mm)
    #text(weight: "bold")[CRDT storage overhead.] Per-character metadata is the cost of
    convergence: a 50 KB document may carry
    #text(fill: red, weight: "bold")[500 KB–2 MB] of CRDT state. At 10M documents that is
    #text(fill: red, weight: "bold")[5–20 TB] — compaction and tombstone GC are
    #underline(stroke: 1pt + red)[mandatory, not optional].
    #linebreak() #v(1mm)
    #text(weight: "bold")[Permissions.] Every read checks access: 50,000 doc opens/s ×
    ~5 checks each = #text(fill: orange, weight: "bold")[250k authz/s] at p99 < 10 ms. This
    is a dedicated, heavily-cached service — not a join in the application database.
  ]
]
#v(2mm)

#h2("3 · Topology", c: blue)

#pfig("Fig CS2.1 · topology — the client owns its state, the server owns the order")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  swimlane(-0.4, -1.1, 20.4, 2.1, "CLIENT — authoritative for local state", purple, rgb("#f5eefa"))
  rnode(3.2, 0.5, "c1", "client A", "local CRDT + IndexedDB", purple, w: 5.0, h: 0.9)
  rnode(10.0, 0.5, "c2", "client B", "local CRDT", purple, w: 3.8, h: 0.9)
  rnode(17.2, 0.5, "c3", "client C — offline", "queues ops locally", orange, w: 5.2, h: 0.9)

  swimlane(-0.4, -5.0, 20.4, -1.6, "COLLAB TIER", green, rgb("#f6fbf7"))
  rnode(3.6, -2.7, "ws", "WS gateway", "sticky per doc", blue, w: 4.4, h: 0.9)
  rnode(10.0, -2.7, "doc", "doc server", "one owner per doc", green, w: 4.6, h: 0.9)
  rnode(17.0, -2.7, "authz", "authz (Zanzibar)", "ReBAC · cached · 10 ms", red, w: 5.4, h: 0.9)
  line("c1.south", "ws.north", mark: (end: ">"), stroke: hot)
  line("c2.south", (10.0, -1.95), (3.6, -1.95), "ws.north", mark: (end: ">"), stroke: hot)
  line("ws.east", "doc.west", mark: (end: ">"), stroke: hot)
  line("doc.east", "authz.west", mark: (end: ">"), stroke: lookup)
  badge(6.8, -2.7, "1", green)
  plabel(6.8, -2.7, "ops batched at 50 ms", c: green, dy: -0.72)
  badge(13.9, -2.7, "2", green)
  plabel(13.9, -2.7, "may this user edit?", c: red, dy: -0.72)
  content((10.6, -4.4), dlbl("one owner per document = total order without consensus", sz: 6.6pt, c: green))
  line("c3.south", (17.2, -1.95), (14.0, -1.95), mark: (end: ">"), stroke: async)
  plabel(15.6, -1.95, "on reconnect", c: purple, dy: 0.26)

  swimlane(-0.4, -8.0, 20.4, -5.5, "STORAGE & MEDIA", orange, rgb("#fdf7f2"))
  cylinder(3.6, -6.8, "op", "op log — source of truth", orange, w: 5.6, h: 1.0)
  cylinder(10.0, -6.8, "snap", "snapshots / 1,000 ops", orange, w: 5.0, h: 1.0)
  rnode(15.6, -6.8, "s3", "object store", "presigned (M16)", purple, w: 4.2, h: 0.9)
  rnode(19.6, -6.8, "tr", "transcode", "spot workers", green, w: 3.2, h: 0.9)
  line("doc.south", (10.0, -5.7), (3.6, -5.7), "op.north", mark: (end: ">"), stroke: hot)
  line("op.east", "snap.west", mark: (end: ">"), stroke: async)
  line("s3.east", "tr.west", mark: (end: ">"), stroke: async)
  badge(6.0, -5.7, "3", green)
  plabel(8.6, -5.7, "durable BEFORE broadcast", c: green, dy: 0.46)
  plabel(6.8, -6.8, "compaction", c: purple, dy: -0.38)
  bracket(0.4, 20.0, -8.4, "local echo 16 ms · remote propagation p99 200 ms · permission check p99 10 ms", purple)
}))
#pcards(
  [One elected owner per document; the client already holds the full CRDT locally and renders from
   it without waiting for any server.],
  [In: batched CRDT ops `(client_id, lamport_clock, payload)`. Out: a durable op-log entry, then
   fan-out to every other client on the doc.],
  [WS gateway (sticky by doc) · doc server · Zanzibar-style authz · Postgres/S3 op log · snapshots],
)
#v(2mm)

#h2("4 · CRDT vs OT, and the data model", c: purple)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Choose CRDTs] (Shapiro et al., 2011) over operational
  transformation. OT requires a central server to transform every operation against concurrent
  ones, and the transformation functions are
  #underline(stroke: 1pt + red)[notoriously hard to get right] — Google Docs' OT implementation
  took years to stabilise. CRDTs converge by construction (M3): merge is commutative, associative
  and idempotent, so offline clients, reordered messages and duplicate delivery are all
  automatically safe. The cost is metadata, which is a storage problem rather than a correctness
  problem — and storage is cheap while correctness bugs in a collaborative editor are existential.
]
#v(1.5mm)

#table(
  columns: (auto, auto, 1fr, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#f5eefa") } else { none },
  text(font: headfont, size: 8.4pt, fill: purple)[Entity],
  text(font: headfont, size: 8.4pt, fill: purple)[Store],
  text(font: headfont, size: 8.4pt, fill: purple)[Key],
  text(font: headfont, size: 8.4pt, fill: purple)[Note],

  text(size: 8.2pt)[Op log],
  text(size: 8.2pt)[Postgres / S3],
  text(size: 8pt)[`(doc_id, seq)` — append-only],
  text(size: 8pt)[Source of truth; replay rebuilds any state],

  text(size: 8.2pt)[Snapshot],
  text(size: 8.2pt)[Object store],
  text(size: 8pt)[`doc:{id}:snap:{seq}` every ~1,000 ops],
  text(size: 8pt)[Bounds replay time on document open],

  text(size: 8.2pt)[Relation tuple],
  text(size: 8.2pt)[Authz store],
  text(size: 8pt)[`(object, relation, subject)`],
  text(size: 8pt)[Zanzibar model: `doc:42#editor@user:7`],

  text(size: 8.2pt)[Media],
  text(size: 8.2pt)[Object store],
  text(size: 8pt)[Content-addressed by hash],
  text(size: 8pt)[Dedupes identical uploads for free],
)
#v(1.5mm)

#text(size: 8.8pt)[
  #text(fill: red, weight: "bold")[Permissions are the hidden hard problem.] "Can user 7 edit
  element 99 in doc 42?" may depend on org membership, team membership, doc sharing, element
  overrides and link-sharing — a #underline(stroke: 1pt + green)[graph traversal], not a row
  lookup. The Zanzibar model stores relation tuples and answers reachability questions, with
  aggressive caching and a consistency token so a permission
  #text(fill: red)[revocation] is never served stale. #note[Get this wrong and you have a data
  leak, which in a collaboration product is the one bug that ends customer relationships. Budget
  for it as a first-class service, not as middleware.]
]
#v(2mm)

#h2("5 · Client & edge contracts", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[The defining path is one keystroke's round trip.] It splits
  in two the instant it starts: the local half must finish in 16 ms and
  #underline(stroke: 1pt + green)[never consults the server], while the remote half has 200 ms to
  reach every other client. Reading them as one synchronous path is the mistake that produces a
  laggy editor.
]
#v(1.5mm)

#pfig("Fig CS2.2 · the edit critical path — local echo in 16 ms, remote convergence in 200 ms")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.2, 20.2, 2.5,
    "document open · client holds the full CRDT in memory · WS session sticky to the owning doc server")

  // ---- row 1: the local half — no server in it at all
  ppill(2.2, 0, "in", "user types a character", c: purple, w: 4.4)
  pstep(8.4, 0, "a", "apply locally", "CRDT merge · < 1 ms", st-man, n: 1, actor: "client A", w: 4.0)
  pstep(13.6, 0, "b", "render frame", "no ack awaited · 16 ms", st-man, n: 2, actor: "client A", w: 4.2)
  pstep(18.8, 0, "c", "batch 50 ms", "5 keys → 1 message", st-auto, n: 3, actor: "client A", w: 4.0)

  line("in.east", "a.west", mark: (end: ">"), stroke: hot)
  line("a.east", "b.west", mark: (end: ">"), stroke: hot)
  plabel(11.2, 0, "optimistic", c: green, dy: 0.72)
  line("b.east", "c.west", mark: (end: ">"), stroke: hot)

  // ---- wrap to row 2: the remote half
  line("c.south", (18.8, -2.0), (2.4, -2.0), (2.4, -3.1), mark: (end: ">"), stroke: wrap)
  plabel(10.6, -2.0, "(client_id, lamport_clock, payload) over the WebSocket", c: luma(110), dy: 0.28)

  pstep(2.4, -4.4, "d", "authz check", "Zanzibar · cached 10 ms", st-integ, n: 4,
    actor: "doc server", w: 4.4)
  pdec(7.6, -4.4, "dc", "still has\nedit rights?", w: 2.2)
  pstep(13.0, -4.4, "e", "append to op log", "durable BEFORE broadcast", st-auto, n: 5,
    actor: "doc server", w: 5.2)
  pstep(18.8, -4.4, "f", "fan out", "to N−1 clients", st-auto, n: 6, actor: "doc server", w: 3.8)

  line("d.east", "dc.west", mark: (end: ">"), stroke: lookup)
  line("dc.east", "e.west", mark: (end: ">"), stroke: hot)
  plabel(10.1, -4.4, "yes", c: green, dy: 0.74)
  line("e.east", "f.west", mark: (end: ">"), stroke: hot)
  plabel(16.2, -4.4, "seq assigned", c: green, dy: 0.74)

  // ---- wrap to row 3: convergence
  line("f.south", (18.8, -6.3), (3.2, -6.3), (3.2, -7.3), mark: (end: ">"), stroke: wrap)
  plabel(10.6, -6.3, "the op is already durable — a crash here loses nothing", c: luma(110), dy: 0.28)

  pstep(3.2, -8.6, "g", "merge remotely", "commutative · idempotent", st-man, n: 7,
    actor: "clients B…N", w: 4.8)
  ppill(10.4, -8.6, "out", "all replicas converged", c: green, w: 5.2)
  line("g.east", "out.west", mark: (end: ">"), stroke: hot)
  plabel(7.1, -8.6, "p99 200 ms", c: green, dy: 0.46)

  // ---- exception: permission revoked while the socket is open
  pstep(17.6, -8.6, "x", "sever the socket", "reject op · force reload", st-dec, n: 0,
    actor: "doc server", w: 4.8)
  line("dc.south", (7.6, -6.9), (0.3, -6.9), (0.3, -10.4), (17.6, -10.4), "x.south",
    mark: (end: ">"), stroke: except)
  plabel(9.0, -10.4, "no — revoked mid-session; checking only at connect time is a leak", c: red, dy: 0.28)
}))
#pcards(
  [Document already open and the full CRDT resident on the client; the WebSocket is sticky to the
   one doc server that owns this document.],
  [In: a keystroke. Out: a rendered frame in 16 ms with no server involved, and a durable,
   sequenced op fanned out to every other editor within 200 ms.],
  [Local CRDT + IndexedDB · WS gateway · doc server · Zanzibar authz cache · op log],
)
#v(2mm)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Edit channel.] WebSocket, binary framing, ops batched at
  50 ms. Each op carries `(client_id, lamport_clock, payload)`. The client applies locally first
  and #underline(stroke: 1pt + green)[never waits for an ack to render].

  #text(fill: green, weight: "bold")[Reconnect.] Client sends its last-known sequence; the server
  returns a delta, or a snapshot plus delta if the gap is large.
  #text(fill: orange)[Never a full document] unless the client has no state.

  #text(fill: green, weight: "bold")[Media.] Presigned direct-to-storage upload, chunked and
  resumable (M16); the document holds only a content hash. Previews are generated asynchronously
  with a placeholder shown meanwhile.

  #text(fill: purple, weight: "bold")[Presence and cursors] go over a
  #underline(stroke: 1pt + green)[separate, lossy channel] — they are ephemeral, unacknowledged,
  and dropped freely under load. Mixing them into the ordered edit stream wastes the ordering
  guarantee on data that does not need it.
]
#v(2mm)

#h2("6 · Failure modes", c: red)

#text(size: 8.8pt)[
  #text(fill: red, weight: "bold")[Doc server dies mid-session.] #text(fill: green)[Fix:] ops are
  durable in the log before broadcast; a new owner is elected and replays from the last snapshot.
  Clients reconnect and resync by sequence number — the ops they sent but did not see acked are
  re-sent and deduplicated by `(client_id, clock)`.
]
#v(1.5mm)

#pfig("Fig CS2.3 · failure response — the doc server dies with 20 people editing")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.2, 20.2, 2.5,
    "every op durable in the log before it was broadcast · snapshot taken every ~1,000 ops")

  // ---- detection
  ppill(2.2, 0, "in", "doc server process dies", c: red, w: 5.0)
  pstep(9.0, 0, "a", "detect", "lease expiry · ~2 s", st-dec, n: 1, actor: "gateway", w: 3.4)
  pstep(14.4, 0, "b", "elect new owner", "one owner, still", st-auto, n: 2,
    actor: "control plane", w: 4.6)
  pdec(19.2, 0, "d", "snapshot\nfresh?", w: 2.0)

  line("in.east", "a.west", mark: (end: ">"), stroke: miss)
  line("a.east", "b.west", mark: (end: ">"), stroke: except)
  plabel(11.7, 0, "clients see the socket drop", c: red, dy: 0.74)
  line("b.east", "d.west", mark: (end: ">"), stroke: hot)

  // ---- wrap to mitigation row
  line("d.south", (19.2, -2.1), (2.4, -2.1), (2.4, -3.1), mark: (end: ">"), stroke: wrap)
  plabel(10.6, -2.1, "yes — replay bounded to the ops since that snapshot", c: luma(110), dy: 0.28)

  pstep(2.4, -4.4, "e", "load snapshot", "object store", st-auto, n: 3, actor: "new owner", w: 4.0)
  pstep(7.8, -4.4, "f", "replay the tail", "op log · ≤1,000 ops", st-auto, n: 4,
    actor: "new owner", w: 4.4)
  pstep(13.6, -4.4, "g", "clients reconnect", "jittered · last seq sent", st-man, n: 5,
    actor: "clients", w: 5.0)
  pstep(19.2, -4.4, "h", "server sends delta", "not the whole doc", st-auto, n: 6,
    actor: "new owner", w: 4.6)

  line("e.east", "f.west", mark: (end: ">"), stroke: hot)
  line("f.east", "g.west", mark: (end: ">"), stroke: hot)
  plabel(10.9, -4.4, "state rebuilt", c: green, dy: 0.74)
  line("g.east", "h.west", mark: (end: ">"), stroke: hot)

  // ---- wrap to recovery row
  line("h.south", (19.2, -6.3), (3.4, -6.3), (3.4, -7.3), mark: (end: ">"), stroke: wrap)
  plabel(10.6, -6.3, "unacked ops are re-sent by the client and deduplicated on (client_id, clock)",
    c: luma(110), dy: 0.28)

  pstep(3.4, -8.6, "i", "merge duplicates", "idempotent by construction", st-auto, n: 7,
    actor: "new owner", w: 5.4)
  ppill(11.6, -8.6, "out", "zero lost edits", c: green, w: 4.4)
  line("i.east", "out.west", mark: (end: ">"), stroke: hot)
  plabel(8.6, -8.6, "converged", c: green, dy: 0.34)

  // ---- exception: no usable snapshot — full replay, slow but correct
  pstep(17.8, -8.6, "x", "full log replay", "slow open, never wrong", st-dec, n: 0,
    actor: "new owner", w: 4.8)
  line("d.east", (21.6, 0), (21.6, -11.4), (17.8, -11.4), "x.south",
    mark: (end: ">"), stroke: except)
  plabel(10.4, -11.4, "no usable snapshot — degrade on latency, never on correctness", c: red, dy: 0.28)

  ploop("out.south", "i.south", -10.2, "recovered without operator action — clients never saw a lost keystroke")
}))
#pcards(
  [An op was durable in the log before it was ever broadcast; snapshots every ~1,000 ops bound how
   far the new owner must replay.],
  [In: the loss of one doc-server process. Out: a new elected owner, resynced clients, and a
   lost-edit count of zero — the product promise this case study is built around.],
  [Lease-based ownership · object-store snapshots · op log replay · jittered client reconnect (M10)],
)
#v(2mm)

#text(size: 8.8pt)[
  #text(fill: red, weight: "bold")[CRDT state unbounded growth.] Tombstones from deleted text
  accumulate forever. #text(fill: green)[Fix:] periodic compaction once all active clients are
  past a sequence point, plus snapshot-and-truncate. Without this, documents get slower every
  month they are edited — a defect that only appears after a year in production.

  #text(fill: red, weight: "bold")[Permission revoked mid-session.] A user loses access while
  their WebSocket is open. #text(fill: green)[Fix:] authz changes publish an invalidation event;
  the doc server re-checks and #underline(stroke: 1pt + green)[severs the connection
  immediately]. Checking only at connection time is a leak.

  #text(fill: red, weight: "bold")[Offline client returns after a week] with hundreds of queued
  ops against a document that has moved far ahead. #text(fill: green)[Fix:] CRDT merge handles it
  by construction — this is precisely why CRDTs were chosen over OT, and the case worth stating
  in an interview.

  #text(fill: red, weight: "bold")[Deploy drops every connection.] #text(fill: green)[Fix:]
  drain with jittered reconnect (M10, M29). With 500k connections, an undrained deploy is a
  self-inflicted outage.
]
#v(2mm)

#h2("7 · Delivery roadmap", c: purple)

#text(size: 8.8pt)[
  #text(fill: purple, weight: "bold")[Team topology.]
  #text(weight: "bold")[Sync Core] (CRDT, op log, doc servers — the deepest expertise and
  hardest to hire),
  #text(weight: "bold")[Connection Platform] (gateways, presence, drain),
  #text(weight: "bold")[Permissions] (authz service, sharing UX),
  #text(weight: "bold")[Media], and #text(weight: "bold")[Client] (web, desktop, mobile —
  typically the largest team, since the client carries real algorithmic complexity here).

  #text(fill: purple, weight: "bold")[Phasing.]
  #text(weight: "bold")[M0–M4:] single-doc-server CRDT prototype, no offline, no media — prove
  convergence under adversarial concurrent editing.
  #text(weight: "bold")[M5–M8:] connection fleet, presence, permissions service.
  #text(weight: "bold")[M9–M12:] offline sync, media pipeline, compaction.
  #text(weight: "bold")[M13+:] scale-out, multi-region read replicas.
  #underline(stroke: 1pt + green)[Do not start with offline] — it is the hardest part and
  meaningless until convergence is proven online.

  #text(fill: purple, weight: "bold")[SLO targets.] Local echo p99 < 16 ms (client-measured) ·
  remote propagation p99 < 200 ms · permission check p99 < 10 ms ·
  #text(weight: "bold")[lost-edit rate: 0] · doc-open p99 < 1 s.

  #text(fill: purple, weight: "bold")[The investment to defend.] Convergence testing is where the
  product's credibility lives: property-based tests generating thousands of random concurrent
  op sequences, asserting all replicas converge to the same state. Fuzzing the CRDT is
  #underline(stroke: 1pt + green)[more valuable than any amount of manual QA], and leadership
  will not ask for it. Put it in the plan explicitly, because the alternative is discovering
  divergence in a customer's document.
]
