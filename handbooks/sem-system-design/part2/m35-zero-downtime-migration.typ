#import "/shared/lib/template.typ": *
#reg(1, "M35", "Zero-Downtime Database Migrations")
#chapterhead("Part 2 · Modules", "M35 · Zero-Downtime Migrations")
#ix("Zero-downtime migration")
#ix("Backfill")
#ix("Lock timeout")

#h1("M35 · Zero-Downtime Migrations", c: green)

#text[
  Code rolls back in thirty seconds. A dropped column does not. That asymmetry is the whole
  subject: schema changes must be structured so that the
  #underline(stroke: 1pt + green)[old and new code can both run against the same database] for
  as long as the rollout and any rollback require.
]
#v(2mm)

#h2("1 · Expand–migrate–contract", c: blue)

#pfig("Fig M35.1 · expand–migrate–contract — four deploys, and the gate before the irreversible one")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.4, 20.6, 2.9, "every writer enumerated — admin tools, batch jobs, triggers · lock_timeout so DDL fails fast · telemetry on the old field")

  ppill(2.2, 0, "in", "schema change", w: 3.8)
  pstep(7.4, 0, "a", "1 · EXPAND", "ADD COLUMN nullable · instant", st-man, n: 1, actor: "deploy 1", w: 5.8)
  pstep(15.0, 0, "b", "2 · DUAL-WRITE", "write both, read old", st-man, n: 2, actor: "deploy 2", w: 5.4)
  pstep(15.0, -3.4, "c", "3 · BACKFILL", "10k batches · ~1.4 h for 500M", st-auto, n: 3, actor: "", w: 6.0)
  pdec(8.0, -3.4, "d", "drift = 0?", w: 2.0)
  pstep(2.9, -3.4, "e", "4 · CONTRACT", "DROP COLUMN · irreversible", st-dec, n: 4, actor: "deploy 4", w: 5.2)
  pstep(15.0, -6.6, "x", "throttle on replica lag", "a backfill that outruns it looks like data loss", st-dec, n: 0, actor: "", w: 8.0)

  line("in.east", "a.west", mark: (end: ">"), stroke: hot)
  line("a.east", "b.west", mark: (end: ">"), stroke: hot)
  plabel(11.5, 0, "old pods keep running", c: green, dy: 0.85)
  line("b.south", "c.north", mark: (end: ">"), stroke: hot)
  content((16.9, -1.8), dlbl("flip reads\nto new", sz: 6.3pt, c: green))
  line("c.west", "d.east", mark: (end: ">"), stroke: hot)
  line("d.west", "e.east", mark: (end: ">"), stroke: miss)
  plabel(6.2, -3.4, "yes", c: green)
  line("d.south", (8.0, -6.6), "x.west", mark: (end: ">"), stroke: except)
  plabel(10.0, -6.6, "no", c: red, dy: 0.3)
  ploop("x.east", "c.east", -5.0, "re-run the equality count hours apart", c: blue)
  content((4.0, -6.6), dlbl("rollback from any step is\none deploy, never a restore", sz: 6.5pt, c: purple))
}))
#pcards(
  [Never ship a schema change and the code that needs it in one release. `CREATE INDEX CONCURRENTLY`, `ADD CONSTRAINT NOT VALID` then `VALIDATE` separately.],
  [In: a desired schema. Out: four independently deployable, independently reversible steps — the drop happening days later, gated on telemetry, not confidence.],
  [Postgres / MySQL DDL with `lock_timeout` · a batched backfill keyed by primary-key range · replication-lag throttle · client-version read counters (M7)],
)
#v(1.5mm)

#text(size: 9pt)[
  The rule that makes this work: #underline(stroke: 1pt + red)[never ship a schema change and the
  code that requires it in the same release]. Expand is backwards-compatible, so old pods keep
  running during a rolling deploy (M29). Contract happens days or weeks later, once you are
  certain nothing reads the old shape --- and on mobile, "certain" means instrumented, not
  assumed (M7).
]
#v(2mm)

#h2("2 · Which DDL locks, and for how long", c: red)

#table(
  columns: (auto, auto, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#fdf0ee") } else { none },
  text(font: headfont, size: 8.5pt, fill: red)[Operation],
  text(font: headfont, size: 8.5pt, fill: red)[Lock],
  text(font: headfont, size: 8.5pt, fill: red)[Safe approach],

  text(size: 8.3pt)[`ADD COLUMN` nullable, no default],
  text(size: 8.3pt, fill: green)[instant],
  text(size: 8pt)[Safe on modern Postgres/MySQL — metadata only],

  text(size: 8.3pt)[`ADD COLUMN` with default],
  text(size: 8.3pt, fill: orange)[varies],
  text(size: 8pt)[Safe on PG 11+/MySQL 8; a #underline(stroke: 1pt + red)[full rewrite] on older versions],

  text(size: 8.3pt)[`CREATE INDEX`],
  text(size: 8.3pt, fill: red)[blocks writes],
  text(size: 8pt, fill: green)[`CREATE INDEX CONCURRENTLY` — slower, no write lock],

  text(size: 8.3pt)[`ADD CONSTRAINT` / FK],
  text(size: 8.3pt, fill: red)[full scan],
  text(size: 8pt, fill: green)[Add `NOT VALID`, then `VALIDATE CONSTRAINT` separately],

  text(size: 8.3pt)[`ALTER COLUMN TYPE`],
  text(size: 8.3pt, fill: red)[table rewrite],
  text(size: 8pt)[New column + backfill + swap. Never in place on a large table],

  text(size: 8.3pt)[`DROP COLUMN`],
  text(size: 8.3pt, fill: green)[instant],
  text(size: 8pt, fill: red)[Irreversible — the contract step, done last],
)
#v(1.5mm)

#key[
  The danger is rarely the DDL's own duration --- it is the
  #text(fill: red, weight: "bold")[lock queue] behind it. An `ALTER TABLE` waiting on one
  long-running transaction blocks every subsequent query on that table, including reads. A change
  that would have taken 50 ms takes down the service for the length of the oldest transaction.
  #underline(stroke: 1pt + green)[Always set `lock_timeout` so the migration fails fast rather
  than queueing], and retry.
]
#v(2mm)

#h2("3 · Capacity arithmetic", c: orange)

#formula("Backfilling 500M rows without an incident")[
  #text(size: 8.6pt)[
    Naive: `UPDATE orders SET new_col = old_col` on 500M rows — one transaction, hours long,
    holding locks and generating a #text(fill: red, weight: "bold")[single enormous WAL burst]
    that stalls replication and fills disk.
    #linebreak() #v(1mm)
    #text(fill: green, weight: "bold")[Batched:] 10,000 rows per transaction, keyed by primary
    key range, with a short pause between batches.
    #linebreak()
    500,000,000 / 10,000 = #text(weight: "bold")[50,000 batches]. At 50 ms each plus a 50 ms
    pause #sym.arrow.r 50,000 × 0.1 s = #text(fill: orange, weight: "bold")[5,000 s ≈ 1.4 hours],
    with production traffic unaffected throughout.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Throttle on replication lag:] measure lag each batch and pause if it
    exceeds a threshold. A backfill that outruns replication turns read replicas
    #underline(stroke: 1pt + red)[minutes stale], which looks to users like data loss.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Verification before contract:] a count of rows where
    `new_col IS DISTINCT FROM old_col` must be #text(fill: green, weight: "bold")[zero] across the
    whole table before dropping anything. Run it twice, hours apart, to catch rows written by code
    paths you forgot.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Migration and code in one release.] The deploy is half-rolled
  out; old pods write without the new column while new pods require it.
  #text(fill: green)[Fix:] separate deploys, always, with the schema change first and
  backwards-compatible.

  #text(fill: red, weight: "bold")[The missed writer.] Dual-write is implemented in the service,
  but an admin tool, a batch job, or a database trigger writes the old column only. The backfill
  passes, then drift reappears. #text(fill: green)[Fix:] enumerate
  #underline(stroke: 1pt + green)[every] writer before starting; verification after a delay
  catches what enumeration missed.

  #text(fill: red, weight: "bold")[`CREATE INDEX` without `CONCURRENTLY`.] Writes block for the
  duration of the build on a large table — minutes of downtime from one forgotten keyword.
  #text(fill: green)[Fix:] make it a lint rule in migration review; `CONCURRENTLY` cannot run
  inside a transaction, which is the usual reason people drop it.

  #text(fill: red, weight: "bold")[Mobile clients pinned to the old shape.] The backend contracts
  while app versions from last year still send the old field (M7).
  #text(fill: green)[Fix:] the contract step is gated on client telemetry, not on backend
  readiness.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Rename a column on a 500M-row table with zero downtime.]
  #linebreak()
  Expand (add the new column), dual-write both, backfill in throttled batches, verify equality,
  flip reads, verify again, then contract. Four deploys, each reversible.
  #note[Testing: do you say "rename"? There is no safe rename — it is an add, a migrate, and a
  drop, separated in time.]

  #text(fill: green, weight: "bold")[Q: Why is `ALTER TABLE` risky even when it is fast?]
  #linebreak()
  It needs a lock that queues behind existing transactions and blocks everything arriving after
  it. #note[Testing: understanding of lock queueing rather than DDL duration — this is the
  mechanism behind most migration outages.]

  #text(fill: green, weight: "bold")[Q: How do you know it is safe to drop the old column?]
  #linebreak()
  Instrumented reads: log and count every access to the old field by client version, and drop only
  when the count has been zero for longer than your rollback window.
  #note[Testing: evidence over confidence.]
]
#v(2mm)

#anti("the big-bang migration window")[
  The plan is a Sunday 02:00 maintenance window: take the service down, run the migration, bring
  it up. It is estimated at 30 minutes. At 02:40 the `ALTER TABLE` is still running on a table
  larger than staging; at 03:30 it is clear it will not finish before the business day; and the
  rollback #underline(stroke: 1pt + red)[requires restoring a backup] because the migration is
  half-applied and not reversible. The outage becomes eight hours, and the restore loses the
  writes taken before the window.
  #text(fill: green)[Fix:] expand–contract with online batched backfills. The migration runs for
  hours #text(fill: green, weight: "bold")[while the service serves traffic], every step is
  reversible by a deploy, and there is no window to overrun.
]
