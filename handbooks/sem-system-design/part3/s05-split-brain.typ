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

#align(center, cetz.canvas(length: 0.8cm, {
  import cetz.draw: *
  swimlane(-0.4, -1.4, 18.4, 2.0, "CONTAIN FIRST, RECONCILE SECOND", red, rgb("#fdf0ee"))
  rnode(2.4, 1.0, "a", "1 · FREEZE", "stop both regions", red, w: 3.2, h: 0.95)
  rnode(6.6, 1.0, "b", "2 · pick authority", "one region wins", orange, w: 3.6, h: 0.95)
  rnode(11.0, 1.0, "c", "3 · classify", "overlap vs disjoint", purple, w: 3.4, h: 0.95)
  rnode(15.6, 1.0, "d", "4 · reconcile", "ledger entries, not edits", green, w: 4.2, h: 0.95)
  for (x, y) in (("a", "b"), ("b", "c"), ("c", "d")) {
    line(x + ".east", y + ".west", mark: (end: ">"), stroke: hot)
  }
  content((9.0, -0.3), dlbl("NEVER resume writes before the authority is chosen", sz: 6.6pt, c: red))
  content((9.0, -0.95), dlbl("every correction is a NEW ledger entry — the history is evidence",
    sz: 6.5pt, c: green))
}))
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
