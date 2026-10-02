#import "/shared/lib/template.typ": *
#reg(1, "M22", "Concurrency Control & Isolation")
#chapterhead("Part 2 · Modules", "M22 · Concurrency Control")
#ix("MVCC")
#ix("Write skew")
#ix("Lost update")
#ix("Phantom read")

#h1("M22 · Concurrency Control & Isolation", c: purple)

#text[
  Isolation levels are a contract about which concurrency anomalies you have agreed to tolerate.
  Almost every database ships defaulting to something weaker than
  #text(fill: red, weight: "bold")[serializable], which means your application is already
  exposed to anomalies --- the only question is whether you chose them deliberately.
]
#v(2mm)

#h2("1 · The anomalies, in order of subtlety", c: red)

#table(
  columns: (auto, 1fr, auto, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#fdf0ee") } else { none },
  text(font: headfont, size: 8.5pt, fill: red)[Anomaly],
  text(font: headfont, size: 8.5pt, fill: red)[What happens],
  text(font: headfont, size: 8.5pt, fill: red)[Prevented at],
  text(font: headfont, size: 8.5pt, fill: red)[Danger],

  text(size: 8.3pt)[Dirty read],
  text(size: 8pt)[You read a value another transaction has not committed — and may roll back],
  text(size: 8.3pt)[Read Committed],
  text(size: 8.3pt, fill: green)[rare today],

  text(size: 8.3pt)[Non-repeatable read],
  text(size: 8pt)[The same row read twice in one transaction returns different values],
  text(size: 8.3pt)[Repeatable Read],
  text(size: 8.3pt, fill: orange)[moderate],

  text(size: 8.3pt)[Phantom read],
  text(size: 8pt)[A range query re-run returns new rows matching the predicate],
  text(size: 8.3pt)[Serializable],
  text(size: 8.3pt, fill: orange)[moderate],

  text(size: 8.3pt, fill: red)[Lost update],
  text(size: 8pt)[Two read-modify-writes; one silently overwrites the other],
  text(size: 8.3pt)[RR + locking, or CAS],
  text(size: 8.3pt, fill: red)[high],

  text(size: 8.3pt, fill: red)[Write skew],
  text(size: 8pt)[Each transaction reads, checks an invariant, writes a #emph[different] row — both valid alone, invariant broken together],
  text(size: 8.3pt, fill: red)[Serializable only],
  text(size: 8.3pt, fill: red)[severe],
)
#v(2mm)

#align(center, cetz.canvas(length: 0.82cm, {
  import cetz.draw: *
  swimlane(-0.4, -2.3, 18.4, 2.0, "WRITE SKEW — the one that passes every review", red, rgb("#fdf0ee"))
  content((4.4, 1.3), dlbl("rule: at least ONE doctor must stay on call", sz: 7pt, c: purple))
  rnode(3.4, 0.2, "t1", "Txn A (Alice)", "reads: 2 on call → OK", blue, w: 4.6, h: 1.0)
  rnode(10.4, 0.2, "t2", "Txn B (Bob)", "reads: 2 on call → OK", blue, w: 4.6, h: 1.0)
  content((3.4, -1.0), dlbl("UPDATE alice SET oncall=false", sz: 6.4pt, c: red))
  content((10.4, -1.0), dlbl("UPDATE bob SET oncall=false", sz: 6.4pt, c: red))
  content((15.6, 0.2), dlbl("both COMMIT", sz: 7pt, c: red))
  content((15.6, -0.5), dlbl("0 on call", sz: 7.5pt, c: red))
  content((7.0, -1.75), dlbl("neither wrote the same row, so no lock ever conflicted", sz: 6.5pt, c: red))
}))
#v(1.5mm)

#key[
  Write skew is the dangerous one because #underline(stroke: 1pt + red)[no row-level mechanism
  catches it] --- the transactions touch different rows. Snapshot isolation, the default in
  Postgres Repeatable Read and in Oracle, permits it. Only true serializability (Postgres
  `SERIALIZABLE` / SSI), or an explicit lock on the #emph[predicate] (`SELECT … FOR UPDATE` over
  the whole set), prevents it.
]
#v(2mm)

#h2("2 · MVCC, and optimistic vs pessimistic", c: blue)

#text(size: 9pt)[
  #text(fill: blue, weight: "bold")[MVCC] keeps multiple versions of each row, so readers never
  block writers and writers never block readers --- each transaction sees a consistent snapshot
  as of its start. The cost is #text(fill: orange)[version accumulation]: old versions must be
  vacuumed, and a long-running read transaction pins every version created since it began.
  #note[A reporting query left open for hours is a classic production incident: it prevents
  vacuum from reclaiming anything, the table bloats, and performance degrades across the whole
  database for reasons that look unrelated to the query.]
]
#v(2mm)

#table(
  columns: (auto, 1fr, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#eef4fb") } else { none },
  text(font: headfont, size: 8.5pt, fill: blue)[],
  text(font: headfont, size: 8.5pt, fill: blue)[Pessimistic (PCC)],
  text(font: headfont, size: 8.5pt, fill: blue)[Optimistic (OCC)],

  text(size: 8.3pt)[Mechanism],
  text(size: 8pt)[Lock first, work second (`SELECT … FOR UPDATE`)],
  text(size: 8pt)[Work, then verify a version at commit (CAS)],

  text(size: 8.3pt)[Under contention],
  text(size: 8pt, fill: green)[Queues — fair, predictable],
  text(size: 8pt, fill: red)[Aborts and retries — can livelock],

  text(size: 8.3pt)[Without contention],
  text(size: 8pt, fill: red)[Pays lock cost anyway],
  text(size: 8pt, fill: green)[Nearly free],

  text(size: 8.3pt)[Across requests],
  text(size: 8pt, fill: red)[Cannot hold a lock across a user think-time],
  text(size: 8pt, fill: green)[Natural fit — carry the version to the client],

  text(size: 8.3pt)[Use for],
  text(size: 8pt)[Inventory decrement, seat booking, hot rows],
  text(size: 8pt)[Document edits, profile updates, low-conflict writes],
)
#v(2mm)

#h2("3 · Capacity arithmetic", c: orange)

#formula("When optimistic concurrency stops working")[
  #text(size: 8.6pt)[
    With #text(weight: "bold")[N] concurrent writers to one row and a transaction window
    #text(weight: "bold")[T], conflict probability rises steeply with both.
    #linebreak()
    10 writers, 50 ms window #sym.arrow.r modest conflict, retries absorb it.
    #linebreak()
    1,000 writers on one hot row #sym.arrow.r nearly every attempt conflicts; throughput
    #underline(stroke: 1pt + red)[falls as concurrency rises] because retries consume the
    capacity. #text(fill: red, weight: "bold")[This is the retrograde region of the USL
    (Appendix A).]
    #linebreak() #v(1mm)
    #text(weight: "bold")[Lock hold time is the real budget.] A row lock held for 5 ms permits
    1/0.005 = #text(fill: green, weight: "bold")[200 serialised txn/s] on that row. Held for
    200 ms — because an HTTP call sits inside the transaction — permits
    #text(fill: red, weight: "bold")[5/s]. The fix is almost never a bigger database; it is
    #underline(stroke: 1pt + green)[removing the network call from inside the transaction].
    #linebreak() #v(1mm)
    #text(weight: "bold")[Deadlock probability] grows roughly with the square of transaction
    length. Short transactions, consistent lock ordering, no user interaction inside a
    transaction.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Lost update via read-modify-write.] `SELECT balance` →
  compute → `UPDATE balance = x`. Two concurrent runs both read 100, both write 90, and one
  withdrawal #underline(stroke: 1pt + red)[vanishes]. Read Committed does not prevent it.
  #text(fill: green)[Fix:] atomic `UPDATE … SET balance = balance - 10 WHERE balance >= 10`, or
  `SELECT … FOR UPDATE`, or a version check in the `WHERE` clause.

  #text(fill: red, weight: "bold")[Deadlock from inconsistent ordering.] Txn A locks row 1 then
  row 2; Txn B locks row 2 then row 1. #text(fill: green)[Fix:] always acquire locks in a
  deterministic order (ascending primary key), keep transactions short, and expect the database
  to abort one — retry it.

  #text(fill: red, weight: "bold")[The long transaction.] A transaction opened for a multi-step
  wizard holds locks and pins MVCC versions for minutes.
  #text(fill: green)[Fix:] never span user think-time with a transaction. Use optimistic
  versioning across requests and open the transaction only at the final write.

  #text(fill: red, weight: "bold")[Isolation assumed, not configured.] Code written as if
  serializable, running at Read Committed. #text(fill: green)[Fix:] state the required level per
  operation and test the anomaly — a concurrency bug that appears once a week in production is
  reproducible in a test with two threads.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Two users book the last seat. How do you prevent a double
  booking?]
  #linebreak()
  Make the check and the write atomic: a conditional update guarded by remaining stock, or
  `SELECT … FOR UPDATE` on the inventory row. #note[Testing: do you spot that
  `if (available) { book(); }` is a race? Checking then acting in two statements is the bug.]

  #text(fill: green, weight: "bold")[Q: What is write skew, and why is it hard?]
  #linebreak()
  Two transactions read an overlapping set, each writes a different row, and the invariant
  spanning them breaks. No row lock conflicts, so snapshot isolation allows it.
  #note[Testing: the deepest question in this module. Candidates who can name it have usually
  been burned by it.]

  #text(fill: green, weight: "bold")[Q: Optimistic or pessimistic?]
  #linebreak()
  Measure contention. Low conflict favours optimistic; a hot row favours pessimistic, because
  optimistic degrades as concurrency rises. #note[Testing: that the answer is empirical, not
  ideological.]
]
#v(2mm)

#anti("check-then-act across two statements")[
  `SELECT COUNT(*) FROM seats WHERE booked = false;` then, if the count is positive,
  `UPDATE seats SET booked = true WHERE id = ?`. Between the two statements another transaction
  books the same seat. This passes code review, passes every single-threaded test, and fails
  #underline(stroke: 1pt + red)[only under concurrency] — which is to say, only in production, on
  the busiest day. #text(fill: green)[Fix:] one atomic statement whose `WHERE` clause carries the
  precondition (`UPDATE … WHERE id = ? AND booked = false`) and check the affected row count. If
  it is zero, somebody else won.
]
