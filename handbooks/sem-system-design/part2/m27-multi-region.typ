#import "/shared/lib/template.typ": *
#reg(1, "M27", "Multi-Region Active-Active")
#chapterhead("Part 2 · Modules", "M27 · Multi-Region Deployments")
#ix("Active-active")
#ix("Split brain")
#ix("Data sovereignty")

#h1("M27 · Multi-Region Active-Active", c: purple)

#text[
  Multi-region is where the speed of light stops being a theoretical concern and becomes a line
  item in your p99. Every design here is a negotiation with one fact:
  #underline(stroke: 1pt + red)[a cross-continent round trip is ~150 ms] and no amount of
  engineering makes it shorter.
]
#v(2mm)

#h2("1 · Three topologies", c: blue)

#pfig("Fig M27.1 · one write in an active–active system, and what a region failure costs it")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.4, 20.6, 2.9, "every record has a home region · each region sized for N/(N−1) = 150% of its own load · a witness in a third location")

  ppill(1.8, 0, "in", "EU user writes", w: 3.6)
  pstep(6.5, 0, "a", "Anycast route", "BGP shift · seconds", st-integ, n: 1, actor: "routing", w: 4.2)
  pdec(11.7, 0, "d", "home region up?", w: 2.5)
  pstep(16.9, 0, "b", "local commit", "1 fsync · 1–5 ms", st-auto, n: 2, actor: "eu-west primary", w: 4.4)
  pstep(16.9, -3.5, "c", "async replicate", "50–200 ms lag · 10 MB/s", st-auto, n: 3, actor: "", w: 4.6)
  ppill(9.4, -3.5, "out", "served from EU and US", c: green, w: 5.0)
  pstep(3.4, -3.5, "x", "quorum promote, or refuse", "witness decides · RTO ≈ 2 min", st-dec, n: 4, actor: "", w: 6.0)

  line("in.east", "a.west", mark: (end: ">"), stroke: hot)
  line("a.east", "d.west", mark: (end: ">"), stroke: hot)
  line("d.east", "b.west", mark: (end: ">"), stroke: hot)
  plabel(14.3, 0, "yes", c: green)
  line("b.south", "c.north", mark: (end: ">"), stroke: async)
  plabel(17.9, -1.8, "us-east", c: purple, dy: 0.0)
  line("c.west", "out.east", mark: (end: ">"), stroke: async)
  plabel(13.2, -3.5, "RPO > 0", c: purple)
  line("d.south", (11.7, -1.9), (3.4, -1.9), "x.north", mark: (end: ">"), stroke: except)
  plabel(7.6, -1.9, "no — region partitioned", c: red, dy: -0.45)
  content((3.4, -5.1), dlbl("the minority side is fenced; LWW across datacentres is clock skew, not a merge", sz: 6.6pt, c: red))
}))
#pcards(
  [Ownership partitioned by region so cross-region writes never contend. Nothing in the hot path crosses a region boundary — a stray call costs 150 ms.],
  [In: a write addressed to the record's home region. Out: a local commit, replicated asynchronously; on failure, a fenced minority and a quorum decision.],
  [Anycast + client-side region list · Postgres / DynamoDB global tables · a third-location witness · 60 MB/s inter-region egress ≈ \$12–15k/month],
)
#v(1.5mm)

#key[
  #text(fill: green, weight: "bold")[Partition by ownership and the conflict problem
  disappears.] Give every record a home region --- EU users' data is written only in EU --- and
  cross-region writes never contend. Replication becomes one-directional per record, and
  "active-active" means both regions are busy, not that both write the same rows. Reach for
  CRDTs or consensus only for the genuinely shared data that remains, which is usually a small
  fraction.
]
#v(2mm)

#h2("2 · Capacity and latency arithmetic", c: orange)

#formula("What each topology costs per write")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[Single region:] write = 1 local fsync ≈
    #text(fill: green, weight: "bold")[1–5 ms].
    #linebreak()
    #text(weight: "bold")[Sync cross-region quorum] (US-East + US-West + EU, majority):
    nearest two of three, so ~70 ms #sym.arrow.r every write pays
    #text(fill: red, weight: "bold")[~70 ms] forever, on a healthy network. That is the PACELC
    #text(weight: "bold")[ELSE] branch (Part 1 §3.3) — not a disaster cost, a
    #underline(stroke: 1pt + red)[permanent one].
    #linebreak()
    #text(weight: "bold")[Async replication:] local write 2 ms, replication lag
    #text(fill: orange, weight: "bold")[50–200 ms] #sym.arrow.r fast writes, RPO > 0, and a
    failover may lose the last 200 ms of commits.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Replication bandwidth:] 10,000 writes/s × 1 KB =
    #text(weight: "bold")[10 MB/s] per replica stream. Three regions fully meshed = 6 streams =
    #text(fill: orange, weight: "bold")[60 MB/s] of inter-region egress ≈
    #text(fill: red, weight: "bold")[\$12k–15k/month] at typical cross-region rates. Replication
    is a #underline(stroke: 1pt + green)[bandwidth bill], not just a latency decision.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Failover RTO:] DNS TTL 60 s + health-check detection 30 s + promotion
    30 s ≈ #text(fill: orange, weight: "bold")[2 minutes] minimum, and client DNS caches
    routinely ignore TTLs — real clients take longer.
  ]
]
#v(2mm)

#h2("3 · Routing and data sovereignty", c: green)

#text(size: 9pt)[
  #text(fill: blue, weight: "bold")[GeoDNS] resolves a hostname to the nearest region, but DNS
  caching makes failover slow and unreliable. #text(fill: green, weight: "bold")[Anycast] (M21)
  shifts traffic at the network layer within seconds and is strictly better for failover.
  #text(fill: purple, weight: "bold")[Client-side failover] — the app holding a region list and
  retrying elsewhere on failure — is the fastest of all, and the only one that works when DNS
  itself is the thing that failed.

  #text(fill: red, weight: "bold")[Sovereignty is a hard constraint, not a preference.] GDPR and
  similar regimes may require that EU personal data be stored and processed in the EU. That
  forbids the simple answer of replicating everything everywhere.
  #note[The practical pattern: partition #underline(stroke: 1pt + green)[personal data] by
  region with no cross-border replication, and replicate only non-personal reference data
  globally. Design this at the schema level on day one — retrofitting a sovereignty boundary into
  a globally-replicated database is a multi-quarter project.]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Split brain.] The link between regions fails; both promote
  themselves and accept writes. On reconnection the datasets conflict and there is no correct
  automatic merge for money. #text(fill: green)[Fix:] a witness or quorum in a
  #underline(stroke: 1pt + green)[third] location so a majority is unambiguous, and explicit
  fencing so the minority side stops accepting writes.

  #text(fill: red, weight: "bold")[Failover to an untested region.] The standby has stale
  configuration, missing secrets, insufficient capacity, or a replication lag nobody measured.
  #text(fill: green)[Fix:] serve real traffic from every region continuously — a region that
  only takes traffic during a disaster will fail during the disaster.

  #text(fill: red, weight: "bold")[Asymmetric capacity.] Three regions each sized for exactly
  their own traffic; one fails and the other two receive 50% more than they can serve.
  #text(fill: green)[Fix:] size each region for #text(weight: "bold")[N/(N−1)] of total load.
  Three regions means each must handle 50%, so you are provisioning 150% in total.

  #text(fill: red, weight: "bold")[Cross-region chatter.] A service in EU calls a database in US
  on the request path, adding 150 ms per call — and a microservice chain multiplies it.
  #text(fill: green)[Fix:] every request must be servable entirely within one region. Audit for
  cross-region calls in the hot path; they are usually accidental.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Design a multi-region active-active system.]
  #linebreak()
  Partition data ownership by region so writes never conflict, replicate asynchronously for
  read locality and DR, route with Anycast plus client-side failover, size each region for
  N/(N−1), and keep a third-location witness to prevent split brain.
  #note[Testing: do you avoid the conflict problem rather than solving it? Partitioning is the
  senior answer; "we'll use CRDTs everywhere" is not.]

  #text(fill: green, weight: "bold")[Q: An entire region fails. Walk me through it.]
  #linebreak()
  Health checks detect, traffic shifts via Anycast or client retry, the surviving regions absorb
  the load they were provisioned for, writes owned by the dead region are either unavailable or
  promoted after a quorum decision, and reconciliation runs on recovery.
  #note[Testing: whether you confront the writes owned by the failed region. Reads are easy;
  writes are the question.]

  #text(fill: green, weight: "bold")[Q: Why not synchronous replication everywhere?]
  #linebreak()
  It charges every write a cross-region round trip forever, and it makes any region's outage a
  global write outage. #note[Testing: PACELC fluency — the ELSE branch is the cost people forget.]
]
#v(2mm)

#anti("active-active with no ownership model")[
  Both regions accept writes to the same rows, with last-write-wins to "handle" conflicts. It
  works in testing, where concurrent cross-region writes to one row never happen. In production a
  user updates their profile from a phone routed to EU while a background job updates the same
  row in US; LWW silently discards one, decided by #text(fill: red, weight: "bold")[clock skew
  between two datacentres]. Nobody notices until a customer insists they changed a setting that
  keeps reverting, and there is #underline(stroke: 1pt + red)[no log of the discarded write] to
  investigate. #text(fill: green)[Fix:] give every record a home region, route writes there, and
  reserve conflict resolution for data genuinely written in both places — where you choose CRDTs
  or an explicit merge, deliberately.
]
