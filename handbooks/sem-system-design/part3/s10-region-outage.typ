#import "/shared/lib/template.typ": *
#reg(1, "S10", "Catastrophic primary region outage")
#chapterhead("Part 3 · Interview Scenarios", "S10 · Region Failover")

#h1("S10 · Losing an Entire Region", c: red)

#text[
  #text(fill: purple, weight: "bold")[The prompt.] Your primary cloud region is gone — not
  degraded, gone. Control plane unreachable, instances unrecoverable, no ETA from the provider.
  Execute the failover, and explain what you knew about it beforehand.
]
#v(2mm)

#h2("1 · The dilemma and its root cause", c: red)

#text(size: 9pt)[
  Failover is not a technical decision, it is a #underline(stroke: 1pt + red)[one-way bet made
  with incomplete information]. Failing over costs you the writes still in the replication lag
  window and is difficult to reverse. Waiting costs continued downtime against an outage that
  might last ten minutes or ten hours. Both choices are wrong if you guess the duration wrong, and
  nobody tells you the duration.

  #text(fill: purple, weight: "bold")[Root cause of most failed failovers.] The standby exists on
  paper but has never served production traffic. Its configuration has drifted, its capacity is
  sized optimistically, its secrets expired, and the runbook references a service renamed a year
  ago. #underline(stroke: 1pt + green)[A region that only takes traffic during a disaster will
  fail during the disaster.]
]
#v(2mm)

#formula("What failover actually costs")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[Data loss:] async replication lag of 200 ms at 5,000 writes/s =
    #text(fill: red, weight: "bold")[~1,000 writes lost], permanently. Those are real orders,
    payments or messages. Know this number #underline(stroke: 1pt + green)[before] the incident —
    it is the price of the decision.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Time to serve:] detection 30 s + decision
    #text(fill: orange, weight: "bold")[5–15 min (human)] + promotion 60 s + DNS/Anycast shift
    60–300 s + cold caches 5–10 min #sym.arrow.r realistic RTO
    #text(fill: red, weight: "bold")[15–30 minutes], of which the
    #underline(stroke: 1pt + red)[human decision is the largest term].
    #linebreak() #v(1mm)
    #text(weight: "bold")[Capacity:] two regions each sized for their own 50% means the survivor
    needs #text(fill: red, weight: "bold")[200% of its normal load]. If it was provisioned at
    120%, failover moves the outage rather than ending it. Size for N/(N−1) — with two regions
    that is 100% spare in each (M27).
    #linebreak() #v(1mm)
    #text(weight: "bold")[DNS reality:] a 60 s TTL does not mean 60 s. Resolvers and client
    libraries cache beyond TTL; a long tail of clients takes
    #text(fill: orange, weight: "bold")[10–30 minutes] to move. Anycast or client-side failover
    is materially faster.
  ]
]
#v(2mm)

#h2("2 · Execution", c: green)

#align(center, cetz.canvas(length: 0.8cm, {
  import cetz.draw: *
  swimlane(-0.4, -1.5, 18.4, 1.9, "DECIDE, PROMOTE, SHIFT, RECONCILE", red, rgb("#fdf0ee"))
  let ph(x, n, l, s, c) = rnode(x, 0.9, n, l, s, c, w: 3.3, h: 1.0)
  ph(2.2, "a", "1 · confirm", "region, not us", blue)
  ph(6.0, "b", "2 · DECIDE", "named human", red)
  ph(9.8, "c", "3 · promote", "fence the old", orange)
  ph(13.6, "d", "4 · shift traffic", "anycast / client", green)
  ph(17.2, "e", "5 · reconcile", "after recovery", purple)
  for (x, y) in (("a","b"),("b","c"),("c","d"),("d","e")) {
    line(x + ".east", y + ".west", mark: (end: ">"), stroke: hot)
  }
  content((9.0, -0.4), dlbl("FENCING is the step teams forget — the old primary must never write again",
    sz: 6.6pt, c: red))
  content((9.0, -1.1), dlbl("without it, a partially-recovered region resumes writing: split brain (S5)",
    sz: 6.5pt, c: red))
}))
#v(1.5mm)

#text(size: 9pt)[
  #text(fill: blue, weight: "bold")[1 · Confirm it is the region, not you.] Check the provider's
  status page, your own external probes from a third location, and whether other services in that
  region are affected. Failing over for a local misconfiguration is a self-inflicted outage with
  data loss attached.

  #text(fill: red, weight: "bold")[2 · The decision must have a named owner and a pre-agreed
  threshold.] "If the primary is unavailable for more than 10 minutes with no provider ETA, the
  on-call commander declares failover." Deciding this
  #underline(stroke: 1pt + green)[in advance] converts a 15-minute debate into a 30-second check.

  #text(fill: orange, weight: "bold")[3 · Promote, and fence the old primary.] Promotion is
  mechanical. Fencing is the part that is skipped under pressure and causes the worse incident:
  revoke the old region's credentials, change the replication topology, and ensure that if it
  returns it #text(fill: red, weight: "bold")[cannot accept writes]. Without fencing you have
  built S5.

  #text(fill: green, weight: "bold")[4 · Shift traffic by the fastest mechanism you have.]
  Anycast withdrawal beats DNS; client-side failover with a region list beats both, because it
  does not depend on infrastructure that may also be impaired.

  #text(fill: purple, weight: "bold")[5 · Reconcile after recovery.] The writes lost in the lag
  window are identified from the old region's logs once it returns, then replayed or compensated
  — as ledger entries, never as silent edits (S5).
]
#v(2mm)

#key[
  The #underline(stroke: 1pt + green)[decision latency] is usually the largest component of RTO,
  and it is the cheapest to fix. Pre-authorise the failover with an explicit threshold so on-call
  does not need to wake a VP to get permission. Teams that require executive approval mid-incident
  routinely turn a 20-minute RTO into two hours.
]
#v(2mm)

#h2("3 · SEM execution strategy", c: purple)

#text(size: 8.9pt)[
  #text(fill: purple, weight: "bold")[Run the drill, quarterly, in production.] A failover that
  has never been executed is a hypothesis. Schedule it, announce it, and do it during business
  hours with everyone watching. #note[Every drill finds something: an expired certificate, a
  hard-coded regional endpoint, a secret that exists only in the primary, a service whose
  readiness probe depends on a resource in the dead region. Finding those on a Tuesday afternoon
  is the entire point.]

  #text(fill: purple, weight: "bold")[Active-active beats cold standby] for exactly this reason —
  both regions serve real traffic continuously, so configuration drift and capacity shortfalls
  surface immediately rather than during a disaster (M27). The cost difference is smaller than it
  appears once you account for the standby you were already paying for.

  #text(fill: purple, weight: "bold")[Team structure.] Commander (decides, does not type),
  operator (executes), scribe (timeline), comms (customers and executives). The commander's
  hardest job is #underline(stroke: 1pt + green)[preventing well-intentioned parallel fixes] —
  during a region failover, uncoordinated changes are how the recovery itself fails.

  #text(fill: purple, weight: "bold")[Communication.] Be explicit about data:
  #text(fill: green)["We have failed over to EU-West. Service is restored. Transactions in the
  final few seconds before failover may not have been recorded; we are identifying and correcting
  those now and will contact affected customers directly."] Hiding known data loss is the decision
  that turns an incident into a trust problem.

  #text(fill: purple, weight: "bold")[Afterwards.] The post-mortem's main finding is rarely the
  cloud provider — it is your #underline(stroke: 1pt + green)[decision latency] and whatever the
  drill would have caught. Fix those two things and the next one is routine (S15).
]
#v(2mm)

#anti("the disaster recovery plan nobody has executed")[
  The DR document specifies a 4-hour RTO and has been reviewed annually for three years. During
  the real outage: the restore credentials expired eight months ago; the standby's capacity was
  sized for a 2022 traffic level; two services have hard-coded the primary region's endpoint; the
  runbook references a service that was renamed; and the person who wrote it left the company.
  RTO becomes #text(fill: red, weight: "bold")[eleven hours], most of it spent discovering
  problems rather than fixing the outage.
  #underline(stroke: 1pt + red)[The plan was never wrong — it was never true.]
  #text(fill: green)[Fix:] execute it quarterly in production, time it with a stopwatch, and
  publish the measured number as your RTO. An untested DR plan is a document, not a capability.
]
