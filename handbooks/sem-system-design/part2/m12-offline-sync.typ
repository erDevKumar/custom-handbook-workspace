#import "/shared/lib/template.typ": *
#reg(1, "M12", "Offline-First Sync & Conflict Resolution")
#chapterhead("Part 2 · Modules", "M12 · Offline-First Synchronisation")
#ix("Offline-first sync")
#ix("Delta sync")
#ix("Vector clock")

#h1("M12 · Offline-First Synchronisation", c: purple)

#text[
  Offline-first inverts the usual assumption: the #underline(stroke: 1pt + green)[local
  database is the source of truth for the UI], and the network is an optimisation. The app
  reads and writes locally and always feels instant. The hard part is not storing data offline
  --- it is deciding what happens when two devices changed the same thing.
]
#v(2mm)

#h2("1 · The sync loop", c: blue)

#align(center, cetz.canvas(length: 0.82cm, {
  import cetz.draw: *
  swimlane(-0.4, -1.6, 9.0, 2.6, "DEVICE", purple, rgb("#f5eefa"))
  rnode(2.3, 1.7, "ui", "UI", "reads local only", purple, w: 3.0, h: 0.85)
  cylinder(2.3, 0.0, "local", "SQLite / Room", purple, w: 3.6, h: 1.1)
  rnode(6.6, 0.0, "oq", "outbound queue", "pending mutations", orange, w: 3.4, h: 1.0)
  line("ui.south", "local.north", mark: (end: ">"), stroke: hot); badge(2.3, 0.85, "1", green)
  line("local.east", "oq.west", mark: (end: ">"), stroke: hot);   badge(4.6, 0.0, "2", green)
  content((4.4, -1.2), dlbl("write is local + instant — UI never waits", sz: 6.4pt, c: green))

  swimlane(9.8, -1.6, 18.4, 2.6, "SERVER", green, rgb("#f6fbf7"))
  rnode(12.6, 1.4, "api", "sync API", "push + pull delta", green, w: 3.8, h: 0.9)
  cylinder(16.2, 1.4, "srv", "authoritative", green, w: 3.2, h: 1.0)
  rnode(12.6, -0.5, "res", "conflict resolver", "LWW | CRDT | manual", red, w: 4.2, h: 0.95)
  line("oq.east", "api.west", mark: (end: ">"), stroke: async);  badge(10.6, 0.75, "3", purple)
  line("api.east", "srv.west", mark: (end: ">"), stroke: hot)
  line("api.south", "res.north", mark: (end: ">"), stroke: miss)
  content((16.0, -0.5), dlbl("delta since cursor", sz: 6.4pt, c: green))
  line("res.west", (9.6, -0.5), (2.3, -0.5), "local.south", mark: (end: ">"), stroke: async)
  badge(6.0, -0.5, "4", purple)
  bracket(0.6, 17.4, -2.4, "pull by cursor, not by timestamp — clocks disagree", purple)
}))
#v(2mm)

#text(size: 9pt)[
  #text(fill: purple, weight: "bold")[Delta sync, not full sync.] The client stores a cursor ---
  a server-issued sequence number or opaque token --- and asks for everything after it. Never
  sync on `updated_at > lastSync`: device clocks drift, and a row written during the request
  window is silently skipped forever. #note[The cursor must come from the
  #underline(stroke: 1pt + green)[server's] ordering (a monotonic version column, or the WAL
  position from M9). That is the only clock both sides agree on.]

  #text(fill: green, weight: "bold")[Optimistic UI with rollback.] Apply the change locally,
  show it immediately, queue the mutation. If the server rejects it, revert and tell the user.
  This requires every mutation to be #text(fill: orange, weight: "bold")[idempotent] and carry a
  client-generated id, because "did my write land?" is unanswerable after a timeout on a mobile
  network.
]
#v(2mm)

#h2("2 · Conflict resolution strategies", c: red)

#table(
  columns: (auto, 1fr, auto, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#fdf0ee") } else { none },
  text(font: headfont, size: 8.5pt, fill: red)[Strategy],
  text(font: headfont, size: 8.5pt, fill: red)[Behaviour],
  text(font: headfont, size: 8.5pt, fill: red)[Data loss],
  text(font: headfont, size: 8.5pt, fill: red)[Use for],

  text(size: 8.3pt)[Last-write-wins],
  text(size: 8pt)[Newest timestamp wins. Trivial; depends on clocks you do not control],
  text(size: 8.3pt, fill: red)[silent],
  text(size: 8pt)[settings, prefs],

  text(size: 8.3pt)[Server-wins],
  text(size: 8pt)[Client change discarded on conflict. Predictable and honest],
  text(size: 8.3pt, fill: orange)[client's edit],
  text(size: 8pt)[server-owned data],

  text(size: 8.3pt)[Vector clocks],
  text(size: 8pt)[Detects #emph[concurrent] vs. causal; surfaces a real conflict],
  text(size: 8.3pt, fill: green)[none],
  text(size: 8pt)[when you must detect],

  text(size: 8.3pt)[CRDT merge],
  text(size: 8pt)[Converges automatically, no coordination],
  text(size: 8.3pt, fill: green)[none],
  text(size: 8pt)[counters, sets, text],

  text(size: 8.3pt)[Manual],
  text(size: 8pt)[Show both versions, user chooses],
  text(size: 8.3pt, fill: green)[none],
  text(size: 8pt)[documents, notes],

  text(size: 8.3pt)[Append-only],
  text(size: 8pt)[No updates exist, so no conflicts exist],
  text(size: 8.3pt, fill: green)[none],
  text(size: 8pt, fill: green)[messages, ledgers],
)
#v(2mm)

#key[
  The best conflict resolution is #underline(stroke: 1pt + green)[a data model with no
  conflicts]. Chat works offline trivially because messages are appended, never edited. Before
  reaching for CRDTs, ask whether the entity can be modelled as an immutable event log --- it
  usually can, and every downstream problem disappears with it.
]
#v(2mm)

#h2("3 · Capacity arithmetic", c: orange)

#formula("Sync payload and battery budget")[
  #text(size: 8.6pt)[
    1M DAU, 50 changed records/user/day, 500 B per record #sym.arrow.r
    1,000,000 × 50 × 500 B = #text(fill: orange, weight: "bold")[25 GB/day] of sync egress.
    #linebreak()
    Sync every 15 min while foregrounded (≈ 20 syncs/day/user) #sym.arrow.r
    20,000,000 requests/day #sym.arrow.r 20,000,000 / 86,400 =
    #text(fill: orange, weight: "bold")[231 QPS] average, ×3 peak ≈ 700 QPS.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Why batching matters more than payload size:] a mobile radio stays in
    a high-power state for ~10 s after any transmission. 20 separate syncs =
    #text(fill: red, weight: "bold")[200 s of radio-on time]; one batched sync of the same bytes
    is ~10 s. #underline(stroke: 1pt + red)[Request count drains battery, not kilobytes.]
    #linebreak() #v(1mm)
    #text(weight: "bold")[Initial sync is the dangerous one:] a new device pulling 2 years of
    history at 500 B × 36,500 records = #text(fill: red, weight: "bold")[18 MB] on a cold start.
    Paginate it, prioritise the most recent window, and make the app usable before it finishes.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Clock skew corrupts LWW.] A device two minutes ahead wins
  every conflict it participates in, including against newer data. The user's stale edit
  silently overwrites a colleague's correct one.
  #text(fill: green)[Fix:] server-assigned versions, never client wall-clock time.

  #text(fill: red, weight: "bold")[The poison mutation.] A queued mutation fails server-side
  validation permanently --- a deleted parent, a revoked permission. It retries forever and
  #underline(stroke: 1pt + red)[blocks every mutation behind it] in the queue.
  #text(fill: green)[Fix:] bounded retries, then move it to a failed state, surface it to the
  user, and let the rest of the queue drain.

  #text(fill: red, weight: "bold")[Tombstone resurrection.] Device A deletes a record while
  device B edits it offline. B syncs and the record reappears, because an edit to a row that no
  longer exists looks like an insert. #text(fill: green)[Fix:] soft deletes with tombstones
  retained longer than your maximum plausible offline window.

  #text(fill: red, weight: "bold")[Unbounded local growth.] The device database grows forever
  and the app is eventually evicted by the OS for disk use.
  #text(fill: green)[Fix:] a local retention policy — keep the recent window, fetch older data
  on demand.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: How do you sync when two devices edited offline?]
  #linebreak()
  Decide the conflict policy per entity, not globally: append-only where possible, CRDT for
  counters and sets, manual resolution for documents, server-wins for server-owned data.
  #note[Testing: do you ask #underline(stroke: 1pt + green)[what kind of data] before answering?
  A single global policy is the wrong answer for every real app.]

  #text(fill: green, weight: "bold")[Q: Why not sync on `updated_at`?]
  #linebreak()
  Device clocks disagree, and rows written during the request window are skipped permanently.
  Use a server-issued monotonic cursor. #note[Testing: a subtle, very common bug. It works in
  development and loses data in production.]

  #text(fill: green, weight: "bold")[Q: The user hits send with no connection. What happens?]
  #linebreak()
  Write locally, show it immediately as pending, queue an idempotent mutation with a
  client-generated id, reconcile on reconnect, and roll back visibly if rejected.
  #note[Testing: whether you design for the offline case as the #emph[normal] path rather than
  an error branch.]
]
#v(2mm)

#anti("optimistic UI with no rollback path")[
  The app shows the user's edit instantly and queues the mutation. The server rejects it --- a
  permission change, a validation rule, a deleted parent. The app
  #text(fill: red, weight: "bold")[never tells the user]. They see their change locally,
  everyone else sees the old value, and the divergence persists until a reinstall wipes local
  state. The bug report reads "my changes don't save sometimes", which is unreproducible by
  design. #text(fill: green)[Fix:] every optimistic write needs a visible pending state, a
  defined rejection path, and a UI that can honestly say
  #underline(stroke: 1pt + green)[this did not save, here is why].
]
