#import "/shared/lib/template.typ": *
#reg(1, "S3", "80 TB migration, zero downtime, zero loss")
#chapterhead("Part 3 · Interview Scenarios", "S3 · 80 TB Live Migration")

#h1("S3 · Migrating 80 TB at 15k QPS", c: orange)

#text[
  #text(fill: purple, weight: "bold")[The prompt.] An 80 TB MySQL table serving 15,000 QPS must
  move to Cassandra or DynamoDB. No downtime, no data loss, and the business will not accept a
  maintenance window. How long does this take, and how do you prove it is safe before cutting
  over?
]
#v(2mm)

#h2("1 · The dilemma and its root cause", c: red)

#text(size: 9pt)[
  Migration is not a copy; it is #underline(stroke: 1pt + green)[running two systems in parallel
  until you can prove they agree]. The dilemma is that the source is a moving target: by the time
  you finish copying 80 TB, millions of rows have changed. Any design that treats this as a
  one-shot export is wrong before it starts.

  #text(fill: purple, weight: "bold")[Root cause of most failed migrations:] teams plan the data
  copy and neglect the #text(fill: red, weight: "bold")[verification and rollback] phases, which
  are the parts that take the longest and carry all the risk.
]
#v(2mm)

#formula("How long, and at what cost")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[Bulk copy:] 80 TB at a throttled 200 MB/s (staying inside the source's
    spare I/O) #sym.arrow.r 80,000,000 MB / 200 = 400,000 s =
    #text(fill: orange, weight: "bold")[4.6 days] of continuous backfill.
    #linebreak()
    Faster is possible but competes with production traffic — the throttle
    #underline(stroke: 1pt + green)[is] the design.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Change capture during the copy:] 15,000 QPS at ~20% writes =
    #text(weight: "bold")[3,000 writes/s]. Over 4.6 days that is
    #text(fill: orange, weight: "bold")[1.2 billion changes] the CDC stream must apply on top of
    the bulk copy. The target must sustain bulk-load plus 3,000 writes/s concurrently.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Verification:] comparing 80 TB row by row is another multi-day job. Use
    sampled comparison continuously (0.1% of reads shadowed) plus
    #underline(stroke: 1pt + green)[checksummed range scans] over partitions, so verification
    runs alongside the backfill rather than after it.
    #linebreak() #v(1mm)
    #text(fill: red, weight: "bold")[Realistic end-to-end: 6–10 weeks], of which the copy is one
    week. The rest is dual-write hardening, verification, and the staged read cutover.
  ]
]
#v(2mm)

#h2("2 · The solution — six phases, each reversible", c: green)

#align(center, cetz.canvas(length: 0.8cm, {
  import cetz.draw: *
  swimlane(-0.4, -1.5, 18.4, 1.8, "EVERY PHASE ROLLS BACK BY CONFIG, NOT BY RESTORE", green,
    rgb("#f6fbf7"))
  let ph(x, n, lbl, sub, c) = {
    rnode(x, 0.8, n, lbl, sub, c, w: 2.9, h: 1.0)
  }
  ph(2.0, "p1", "1 · dual-write", "both, async target", green)
  ph(5.2, "p2", "2 · backfill", "throttled, 4.6 d", orange)
  ph(8.4, "p3", "3 · CDC catch-up", "tail the binlog", orange)
  ph(11.6, "p4", "4 · verify", "checksums + shadow", purple)
  ph(14.8, "p5", "5 · read cutover", "1% → 100%", green)
  ph(17.6, "p6", "6 · retire", "stop dual-write", red)
  for (a, b) in (("p1", "p2"), ("p2", "p3"), ("p3", "p4"), ("p4", "p5"), ("p5", "p6")) {
    line(a + ".east", b + ".west", mark: (end: ">"), stroke: hot)
  }
  content((9.0, -0.6), dlbl("MySQL remains the source of truth until phase 6", sz: 6.6pt, c: purple))
  content((9.0, -1.2), dlbl("a problem at any phase = flip reads back, nothing is lost", sz: 6.5pt, c: green))
}))
#v(1.5mm)

#text(size: 9pt)[
  #text(fill: green, weight: "bold")[1 · Dual-write first, not last.] Writes go to MySQL
  synchronously (still authoritative) and to the target asynchronously via the transactional
  outbox (M9) — never a raw dual write, which loses events on crash. Target failures must
  #underline(stroke: 1pt + red)[never] fail the user's request.

  #text(fill: green, weight: "bold")[2 · Backfill by primary-key range,] throttled on replication
  lag, resumable from a checkpoint. Writes already flowing from phase 1 may race the backfill, so
  the loader must use a conditional write that never overwrites a
  #underline(stroke: 1pt + green)[newer] version.

  #text(fill: green, weight: "bold")[3 · CDC closes the gap] for anything written before
  dual-write was enabled, tailing the binlog from a recorded position.

  #text(fill: green, weight: "bold")[4 · Verify two ways.] Offline: checksummed range scans over
  partitions, re-run until the mismatch count is zero twice in a row. Online:
  #text(fill: purple)[shadow reads] — serve from MySQL, also read the target, compare, and log
  divergence without affecting the user. Shadow-read mismatch rate is the metric that authorises
  cutover.

  #text(fill: green, weight: "bold")[5 · Shift reads gradually] behind a flag (M24):
  1% → 10% → 50% → 100%, watching error rate, p99 and the mismatch counter at each step.

  #text(fill: green, weight: "bold")[6 · Retire MySQL last,] after a deliberate soak at 100%
  reads. Until this moment, rollback is a single flag flip.
]
#v(2mm)

#key[
  The migration is not finished when the data is copied — it is finished when
  #underline(stroke: 1pt + green)[shadow reads have agreed for long enough that you trust them].
  Teams that cut over on "the backfill completed" discover their divergence in production, where
  the only remedy is a reconciliation job written under pressure.
]
#v(2mm)

#h2("3 · SEM execution strategy", c: purple)

#text(size: 8.9pt)[
  #text(fill: purple, weight: "bold")[Access-pattern review is the real first phase.] Cassandra
  and DynamoDB demand a partition key chosen from the dominant query (M2), and
  #underline(stroke: 1pt + red)[it cannot be changed later without repeating this entire
  project]. Any query that does not include it becomes a scatter-gather or a secondary index with
  its own consistency caveats. Spend a week enumerating every query before writing any code —
  this is where the migration is won or lost.

  #text(fill: purple, weight: "bold")[Team and duration.] 6–10 weeks, 3–4 engineers:
  one on the dual-write and outbox path, one on backfill and CDC, one on verification tooling,
  one rotating on production support. Verification deserves a
  #underline(stroke: 1pt + green)[named owner] — it is the phase teams under-resource and the one
  that protects the data.

  #text(fill: purple, weight: "bold")[Blast radius.] Target writes are asynchronous and failure
  of the target is invisible to users through phase 5. Read cutover is percentage-gated per
  endpoint, so the first exposure is 1% of one query type.

  #text(fill: purple, weight: "bold")[Stakeholder framing.] Leadership hears "migration" and
  expects weeks. Set the expectation early:
  #text(fill: green)["The copy takes a week. Proving correctness takes a month. We will not cut
  over on a schedule; we will cut over on a mismatch rate of zero."] Report weekly on
  #text(weight: "bold")[rows verified] and #text(weight: "bold")[shadow mismatch rate] — two
  numbers that make progress legible without requiring the audience to understand CDC.

  #text(fill: purple, weight: "bold")[The decision you must document:] what mismatch rate
  authorises cutover, and who signs it off. Deciding that mid-migration, with a deadline
  approaching, produces the wrong answer.
]
#v(2mm)

#anti("the big-bang cutover weekend")[
  The plan is to freeze writes Friday night, export, import, verify, and reopen Sunday. The export
  of 80 TB alone exceeds the window; verification is skipped for time; an encoding difference in a
  text column is discovered Monday after #text(fill: red, weight: "bold")[two days of writes] have
  landed in the new store. Rolling back now means replaying those writes into MySQL — a
  reconciliation nobody built, written under maximum pressure. Meanwhile the business was down for
  48 hours and the migration #underline(stroke: 1pt + red)[still is not complete].
  #text(fill: green)[Fix:] parallel run with dual-write and shadow verification. It takes longer
  on the calendar and is reversible at every point, which is the only property that matters when
  80 TB of customer data is involved.
]
