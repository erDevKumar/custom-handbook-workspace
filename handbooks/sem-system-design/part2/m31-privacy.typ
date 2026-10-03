#import "/shared/lib/template.typ": *
#reg(1, "M31", "Data Privacy, Retention & Compliance")
#chapterhead("Part 2 · Modules", "M31 · Privacy & Compliance")
#ix("GDPR erasure")
#ix("Crypto-shredding")
#ix("Tokenisation")

#h1("M31 · Privacy, Retention & Compliance", c: red)

#text[
  "Delete this user" sounds like a `DELETE` statement. In a real system that user's data is in
  the primary database, three read replicas, a search index, a cache, an analytics warehouse,
  seven days of backups, a Kafka topic, and a third-party email provider.
  #underline(stroke: 1pt + red)[Deletion is a distributed systems problem], and the regulator
  gives you 30 days.
]
#v(2mm)

#h2("1 · Where a user's data actually lives", c: red)

#pfig("Fig M31.1 · one erasure request fanning out, and the copy that cannot be rewritten")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.4, 20.6, 2.9, "a data inventory naming every system holding PII, with an owner · per-user keys in a vault · a processor register")

  ppill(2.2, 0, "in", "erasure request", w: 4.0)
  pstep(8.0, 0, "a", "deletion saga", "30-day clock · auditable (M4)", st-auto, n: 1, actor: "orchestrator", w: 5.6)
  pstep(15.3, 0, "b", "live systems", "DB + index + cache", st-auto, n: 2, actor: "~12 targets", w: 4.6)
  pdec(19.0, -3.4, "d", "rewritable?", w: 2.1)
  pstep(13.2, -3.4, "c", "batched hard delete", "1,000 rows/txn · 50k rows", st-man, n: 3, actor: "", w: 5.4)
  ppill(2.9, -3.4, "out", "per-target confirmation", c: green, w: 5.4)
  pstep(13.4, -6.6, "x", "crypto-shred the key", "backups + archives · 35-day window", st-dec, n: 4, actor: "", w: 6.4)

  line("in.east", "a.west", mark: (end: ">"), stroke: hot)
  line("a.east", "b.west", mark: (end: ">"), stroke: hot)
  plabel(12.1, 0, "333/day", c: green)
  line("b.east", (20.6, 0), (20.6, -3.4), "d.east", mark: (end: ">"), stroke: hot)
  line("d.west", "c.east", mark: (end: ">"), stroke: hot)
  plabel(17.1, -3.4, "yes", c: green)
  line("c.west", "out.east", mark: (end: ">"), stroke: hot)
  plabel(8.4, -3.4, "warehouse anonymised", c: green)
  line("d.south", (19.0, -6.6), "x.east", mark: (end: ">"), stroke: except)
  plabel(17.7, -6.6, "no — immutable", c: red, dy: -0.42)
  content((4.4, -6.6), dlbl("a restore must re-apply pending erasures\nbefore the data becomes live again", sz: 6.5pt, c: red))
}))
#pcards(
  [A maintained inventory of every system holding personal data. Soft delete is an undo window, never erasure — a scheduled hard delete must follow it.],
  [In: a verified erasure request. Out: per-target confirmation plus an audit log of what was deleted and when; keys destroyed for anything immutable.],
  [Saga orchestrator · Postgres cascades in 1,000-row batches · search index by doc id · cache key sweep · per-user keys in KMS · third-party erasure APIs],
)
#v(1.5mm)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Backups are the honest problem.] You cannot surgically edit an
  immutable backup without destroying its integrity. The accepted practice is to document a
  bounded backup retention window (say 35 days), delete from live systems immediately, and let
  backups age out --- while ensuring that a #underline(stroke: 1pt + green)[restore re-applies
  pending erasures] before the data becomes live again. Write that mechanism down; auditors ask
  for it specifically.
]
#v(2mm)

#h2("2 · Techniques", c: purple)

#table(
  columns: (auto, 1fr, auto, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#f5eefa") } else { none },
  text(font: headfont, size: 8.5pt, fill: purple)[Technique],
  text(font: headfont, size: 8.5pt, fill: purple)[Mechanism],
  text(font: headfont, size: 8.5pt, fill: purple)[Reversible],
  text(font: headfont, size: 8.5pt, fill: purple)[Use],

  text(size: 8.3pt)[Hard delete],
  text(size: 8pt)[Row removed, FKs cascade],
  text(size: 8.3pt, fill: red)[no],
  text(size: 8pt)[The default for erasure],

  text(size: 8.3pt)[Soft delete],
  text(size: 8pt)[`deleted_at` set; row remains],
  text(size: 8.3pt, fill: green)[yes],
  text(size: 8pt, fill: red)[#underline(stroke: 1pt + red)[Not] erasure — data is still there],

  text(size: 8.3pt, fill: green)[Crypto-shredding],
  text(size: 8pt)[Per-user key; destroy the key and ciphertext is unrecoverable],
  text(size: 8.3pt, fill: red)[no],
  text(size: 8pt, fill: green)[Backups, archives, immutable logs],

  text(size: 8.3pt)[Tokenisation],
  text(size: 8pt)[PII replaced by a token; a vault holds the mapping],
  text(size: 8.3pt, fill: orange)[via vault],
  text(size: 8pt)[Shrinks the systems in audit scope],

  text(size: 8.3pt)[Anonymisation],
  text(size: 8pt)[Identifiers stripped, aggregates retained],
  text(size: 8.3pt, fill: red)[no],
  text(size: 8pt)[Analytics that must survive erasure],
)
#v(1.5mm)

#key[
  #text(fill: green, weight: "bold")[Crypto-shredding is the technique that makes immutable
  storage compliant.] Encrypt each user's data with a per-user key held in a key vault. Erasure
  becomes #underline(stroke: 1pt + green)[deleting one key] --- every copy, in every backup, in
  every archive, becomes permanently unreadable at once, without rewriting a single byte.
  #note[Caveat worth saying out loud: this is only as strong as your key management. A key
  escrowed in a second system that nobody deletes is not shredded.]
]
#v(2mm)

#h2("3 · Capacity arithmetic", c: orange)

#formula("Erasure at scale, and retention savings")[
  #text(size: 8.6pt)[
    10M users, 0.1%/month request erasure #sym.arrow.r
    #text(fill: orange, weight: "bold")[10,000 requests/month] ≈ 333/day. Each fans out to ~12
    systems #sym.arrow.r #text(weight: "bold")[4,000 deletion operations/day] — a real pipeline
    with retries, dead letters and an audit trail, not a cron job.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Cascade size:] one user may own 50,000 rows across 30 tables. A naive
    single-transaction `DELETE` locks those tables for minutes.
    #text(fill: green)[Fix:] batched deletes of 1,000 rows with a pause between batches, so
    production traffic is unaffected.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Retention as a cost lever:] 500 GB/day of logs at \$0.023/GB/month.
    #linebreak()
    #h(3mm) 90-day retention: 45 TB stored #sym.arrow.r
    #text(fill: red, weight: "bold")[\$1,035/month].
    #linebreak()
    #h(3mm) 30-day retention: 15 TB #sym.arrow.r
    #text(fill: green, weight: "bold")[\$345/month].
    #linebreak()
    Shorter retention reduces #underline(stroke: 1pt + green)[both] cost and breach exposure —
    data you do not hold cannot leak, and cannot be subpoenaed.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[The forgotten copy.] Deletion covers the primary database but
  misses the search index, so the user's name still autocompletes. Or it misses the analytics
  warehouse, or a CDC topic with a 7-day retention (M9) that
  #underline(stroke: 1pt + red)[replays the record back] into a rebuilt index.
  #text(fill: green)[Fix:] maintain a data inventory — every system holding personal data, with
  an owner — and make erasure a fan-out saga with per-target confirmation.

  #text(fill: red, weight: "bold")[PII in logs and crash reports.] A request body logged at
  `DEBUG`, or a crash reporter uploading a screenshot containing an email address.
  #text(fill: green)[Fix:] structured logging with field-level redaction by allowlist, and
  configure the crash SDK to strip user data. Audit by searching your own logs for a known test
  identity.

  #text(fill: red, weight: "bold")[Soft delete sold as erasure.] `deleted_at` is set, the UI
  hides the row, and the data remains indefinitely — including in exports and backups. This is a
  compliance failure dressed as a feature. #text(fill: green)[Fix:] soft delete for undo windows
  only, with a scheduled hard delete after a stated period.

  #text(fill: red, weight: "bold")[Third parties forgotten.] Data shared with an email provider,
  an analytics vendor or a support tool is still yours to erase.
  #text(fill: green)[Fix:] a processor register, and erasure API calls as part of the same saga.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Implement GDPR right-to-be-forgotten.]
  #linebreak()
  An auditable deletion saga fanning out to every system in a maintained data inventory, batched
  cascades in the database, crypto-shredding for backups and immutable stores, anonymisation in
  analytics, and API calls to third-party processors.
  #note[Testing: do you think past the primary database? Naming backups and the search index
  unprompted is the signal.]

  #text(fill: green, weight: "bold")[Q: How do you delete from an immutable backup?]
  #linebreak()
  You do not — you crypto-shred, or you document a bounded retention window and re-apply pending
  erasures on restore. #note[Testing: honesty about a genuine constraint. Claiming you can edit
  backups is a tell.]

  #text(fill: green, weight: "bold")[Q: How do you keep PII out of logs?]
  #linebreak()
  Structured logging with an allowlist of loggable fields, redaction in the logging library
  rather than at call sites, and a test that asserts a known test identity never appears.
  #note[Testing: that you enforce it mechanically rather than by review discipline.]
]
#v(2mm)

#anti("treating deletion as a database operation")[
  The erasure endpoint runs `DELETE FROM users WHERE id = ?` and returns 200. Six months later an
  audit finds the user's email in the search index, their name in the analytics warehouse, their
  profile photo in object storage, their messages in a Kafka topic, and their support tickets in
  a third-party tool. The company reported compliance it #underline(stroke: 1pt + red)[did not
  have], which is worse than an acknowledged gap: regulators treat an inaccurate compliance claim
  far more harshly than a disclosed limitation.
  #text(fill: green)[Fix:] a data inventory listing every system that holds personal data, an
  erasure saga that fans out to all of them with confirmation, and an audit log proving what was
  deleted and when.
]
