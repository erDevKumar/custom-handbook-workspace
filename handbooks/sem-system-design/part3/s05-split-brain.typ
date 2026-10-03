#import "/shared/lib/template.typ": *
#reg(1, "S5", "Cross-region split-brain on financial balances")
#chapterhead("Part 3 · Interview Scenarios", "S5 · Split-Brain Resolution")

#h1("S5 · Split-Brain on Financial Balances", c: red)

#text[
  #text(fill: purple, weight: "bold")[The prompt.] The link between two regions failed for
  eleven minutes. Both sides accepted writes. Connectivity is restored and the balances disagree.
  Some customers spent money twice. What do you do in the next hour, and what do you do about the
  design?
]
#v(2mm)

#h2("1 · The dilemma and its root cause", c: red)

#text(size: 9pt)[
  There is #underline(stroke: 1pt + red)[no correct automatic merge] for money. Last-write-wins
  destroys a real transaction. Summing both sides may double-credit. Taking the maximum rewards
  whoever spent more. Every automatic rule is a policy decision about who absorbs a loss, and
  that decision is not an engineering one.

  #text(fill: purple, weight: "bold")[Root cause.] The system permitted
  #text(fill: red, weight: "bold")[two writers for one invariant]. A balance is a
  linearizable-consistency object (Part 1 §3.1) and must have exactly one authority at any
  moment. Split-brain is not a networking failure — it is a design that allowed a minority
  partition to keep accepting writes.
]
#v(2mm)

#h2("2 · The response, in two phases", c: green)

#pfig("Fig S5.1 · split brain — freeze, pick one authority, then classify before touching a balance")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.3, 20.7, 3.0, "the authority rule is decided BEFORE the incident; append-only ledger so corrections are entries, not edits")

  ppill(1.42, 0, "part", "11min split", c: red, w: 2.8)
  pstep(5.62, 0, "det", "two primaries", "quorum alarm · 30s", st-man, n: 1, actor: "on-call", w: 4.8)
  pstep(10.81, 0, "frz", "FREEZE both", "writes off, reads on", st-integ, n: 2, actor: "commander", w: 4.8)
  pdec(15.61, 0, "auth", "pre-agreed\nauthority?")
  ppill(19.53, 0, "stall", "stay frozen", c: red, w: 2.9)

  pstep(10.4, -3.6, "cls", "classify 1.32M", "disjoint vs conflicting", st-auto, n: 3, actor: "recon job", w: 4.8)
  pstep(4.4, -3.6, "auto", "auto-merge 99%", "disjoint + deposits", st-auto, n: 4, actor: "recon job", w: 4.8)
  pstep(17.6, -3.6, "hum", "human queue", "~500-5,000 · 24-48h", st-man, n: 5, actor: "support", w: 4.8)
  ppill(11.0, -7.0, "live", "writes resume on the winner", w: 5.6)

  line("part.east", "det.west", mark: (end: ">"), stroke: miss)
  line("det.east", "frz.west", mark: (end: ">"), stroke: hot)
  line("frz.east", "auth.west", mark: (end: ">"), stroke: hot)
  line("auth.east", "stall.west", mark: (end: ">"), stroke: except)
  plabel(18.5, 0, "no rule", c: red, dy: 0.62)
  line("auth.south", (15.61, -3.6), "cls.east", mark: (end: ">"), stroke: hot)
  plabel(13.6, -2.4, "yes — loser read-only", c: green, dy: 0.0)
  line("cls.west", "auto.east", mark: (end: ">"), stroke: hot)
  line("cls.north", (10.4, -2.0), (17.6, -2.0), "hum.north", mark: (end: ">"), stroke: except)
  plabel(14.0, -1.8, "two spends, one balance", c: red, dy: 0.34)
  line("auto.south", (4.4, -7.0), "live.west", mark: (end: ">"), stroke: hot)
  plabel(6.4, -7.0, "negative first", c: orange, dy: 0.44)

  ploop("hum.south", "cls.south", -5.6, "exposure-ordered re-check after each adjustment", c: blue)
}))
#pcards(
  [One authority per linearizable object; a written rule naming which region wins; tooling that shows a reviewer both versions, both timestamps, both histories],
  [In: 1.32M transactions written on both sides of an 11-minute split · Out: ~99% merged mechanically, 500-5,000 accounts escalated, every correction a new compensating ledger entry],
  [Quorum / lease manager · write freeze at the gateway · reconciliation job over both regions' logs · append-only ledger · support review queue ordered by financial exposure],
)
#v(1.5mm)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Phase 1 — contain (minutes).] Stop writes in
  #underline(stroke: 1pt + green)[both] regions immediately. Divergence is still growing, and
  every further write makes reconciliation harder. Accepting a brief write outage is correct here;
  this is the one scenario where availability is explicitly sacrificed.

  #text(fill: orange, weight: "bold")[Phase 2 — choose one authority.] Not by vote or by data
  volume: by a rule decided in advance — the region holding the pre-partition quorum, or the one
  whose replication log the other can be rebuilt from. Resume writes there only. The other region
  becomes read-only until it is reconciled.

  #text(fill: purple, weight: "bold")[Phase 3 — classify the divergence.] Most records were
  touched on only one side; those merge mechanically. The dangerous set is
  #text(fill: red, weight: "bold")[overlapping writes to the same balance]. Partition the
  reconciliation into:
  #text(fill: green)[disjoint] (apply automatically),
  #text(fill: orange)[overlapping but commutative] (deposits — sum them), and
  #text(fill: red)[overlapping and conflicting] (two spends against one balance — escalate).

  #text(fill: green, weight: "bold")[Phase 4 — reconcile by appending, never by editing.] Correct
  with compensating ledger entries ("adjustment, incident #2026-10-02"), so the history shows what
  happened and why. #underline(stroke: 1pt + red)[Never overwrite a balance] — that destroys the
  evidence auditors and customers will ask for.
]
#v(2mm)

#formula("Scale of the problem — and why the tail is manageable")[
  #text(size: 8.6pt)[
    11-minute partition, 2,000 transactions/s across both regions #sym.arrow.r
    #text(weight: "bold")[1.32M transactions] written during the split.
    #linebreak()
    If 500k accounts were active and writes distributed independently, the probability any single
    account was written in #underline(stroke: 1pt + green)[both] regions is small — typically
    #text(fill: orange, weight: "bold")[0.1–1%] of active accounts.
    #linebreak() #v(1mm)
    #text(fill: green, weight: "bold")[So: ~500–5,000 accounts need human-reviewed
    reconciliation], not 1.32 million. That is a tractable queue for a support team over 24–48
    hours — provided the engineering work produced a
    #underline(stroke: 1pt + green)[clean, prioritised list] rather than asking humans to search.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Negative balances take priority:] customers who overspent are the
    customer-facing harm. Order the queue by financial exposure, not by account id.
  ]
]
#v(2mm)

#key[
  The reconciliation is #underline(stroke: 1pt + green)[90% engineering and 10% judgement], but
  the 10% is where the money is. Build tooling that does the mechanical merge and escalates the
  genuinely conflicting cases with full context — both versions, both timestamps, both regions'
  transaction histories — so a human decides in seconds rather than investigating for an hour.
]
#v(2mm)

#h2("3 · SEM execution strategy", c: purple)

#text(size: 8.9pt)[
  #text(fill: purple, weight: "bold")[The decision you cannot make during the incident.] Whether
  the company absorbs the loss or claws back from customers is a business decision involving
  finance, legal and support. Your job is to present the options with numbers —
  #text(fill: green)["4,200 accounts affected, total exposure £180,000, 90% under £50"] — and
  implement what is decided. Attempting that call yourself, at 3am, is the most consequential
  mistake available in this scenario.

  #text(fill: purple, weight: "bold")[Regulatory clock.] Financial incidents carry reporting
  obligations with deadlines measured in hours. Involve legal and compliance
  #underline(stroke: 1pt + green)[immediately], not after the technical fix. An engineering team
  that resolves the data and misses a disclosure window has made the situation worse.

  #text(fill: purple, weight: "bold")[Team structure.] Three parallel tracks under one commander:
  containment and authority selection (infra), reconciliation tooling (application engineers),
  and customer communication (support plus comms). They must not be the same people —
  reconciliation requires calm, and comms requires constant attention.

  #text(fill: purple, weight: "bold")[Customer communication.] Proactive and specific beats
  silent and correct. #text(fill: green)["We identified an issue affecting a small number of
  balances during a 4 October outage. Your account was affected and has been corrected; the
  adjustment appears as a separate entry. No action is needed."] Customers who discover a wrong
  balance themselves lose trust permanently; customers told first usually do not.

  #text(fill: purple, weight: "bold")[The real remediation.] Not "improve the network" —
  a #underline(stroke: 1pt + green)[third-location witness] so a majority is unambiguous and the
  minority partition #text(fill: red, weight: "bold")[refuses writes] rather than accepting them
  (M27). The incident's lesson is that the system preferred availability for an object that
  required consistency.
]
#v(2mm)

#anti("automatic merge for financial data")[
  A conflict-resolution rule is configured so the system "heals itself" after a partition.
  Last-write-wins silently discards a real customer transaction, decided by
  #text(fill: red, weight: "bold")[clock skew between two datacentres], and there is no record
  that a write was dropped. The books now disagree with reality by an amount nobody can compute,
  and the discrepancy is discovered weeks later during reconciliation — by which point
  #underline(stroke: 1pt + red)[the source data has aged out of the logs].
  #text(fill: green)[Fix:] money gets a single writer, enforced by quorum with a third-location
  witness. If a partition occurs, the minority side stops accepting writes. A brief outage is a
  recoverable event; silently losing a transaction is not.
]
