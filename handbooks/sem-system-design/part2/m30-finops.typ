#import "/shared/lib/template.typ": *
#reg(1, "M30", "FinOps & Cost Engineering")
#chapterhead("Part 2 · Modules", "M30 · FinOps & Cost Engineering")
#ix("FinOps")
#ix("Egress cost")
#ix("Rightsizing")

#h1("M30 · FinOps & Cost Engineering", c: orange)

#text[
  Cost is a non-functional requirement with the same standing as latency, and at
  senior-engineering-manager level it is frequently the one you are accountable for. The useful
  skill is knowing #underline(stroke: 1pt + green)[where the money actually goes], which is
  almost never where teams instinctively optimise.
]
#v(2mm)

#h2("1 · Where cloud spend concentrates", c: red)

#table(
  columns: (auto, auto, 1fr, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#fff3e8") } else { none },
  text(font: headfont, size: 8.5pt, fill: orange)[Line item],
  text(font: headfont, size: 8.5pt, fill: orange)[Typical share],
  text(font: headfont, size: 8.5pt, fill: orange)[Biggest lever],
  text(font: headfont, size: 8.5pt, fill: orange)[Effort],

  text(size: 8.3pt)[Compute],
  text(size: 8.3pt)[40–60%],
  text(size: 8pt)[Rightsizing, spot, committed-use discounts, bin packing],
  text(size: 8.3pt, fill: green)[low],

  text(size: 8.3pt, fill: red)[Egress],
  text(size: 8.3pt)[10–30%],
  text(size: 8pt)[CDN, compression, keeping traffic inside an AZ],
  text(size: 8.3pt, fill: green)[low],

  text(size: 8.3pt)[Storage],
  text(size: 8.3pt)[10–20%],
  text(size: 8pt)[Lifecycle tiering, deleting orphans, shorter retention],
  text(size: 8.3pt, fill: green)[low],

  text(size: 8.3pt)[Managed services],
  text(size: 8.3pt)[10–25%],
  text(size: 8pt)[Right tier, reserved capacity, fewer idle clusters],
  text(size: 8.3pt, fill: orange)[medium],

  text(size: 8.3pt, fill: red)[Observability],
  text(size: 8.3pt)[5–15%],
  text(size: 8pt)[Cardinality control, sampling, shorter retention (M19)],
  text(size: 8.3pt, fill: orange)[medium],
)
#v(1.5mm)

#key[
  Three charges surprise teams because they are invisible in code review:
  #text(fill: red, weight: "bold")[cross-AZ traffic] (~\$0.01/GB in #emph[both] directions,
  charged on ordinary service-to-service calls), #text(fill: red, weight: "bold")[NAT gateway
  data processing] (~\$0.045/GB on top of egress), and
  #text(fill: red, weight: "bold")[observability cardinality]. Each can quietly become a
  five-figure monthly line without anyone deploying anything unusual.
]
#v(2mm)

#h2("2 · Capacity arithmetic", c: orange)

#formula("The levers, quantified")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[Rightsizing:] 100 pods requesting 2 vCPU but using 0.4 at p95.
    Right-sizing to 0.6 (with headroom) frees 140 vCPU #sym.arrow.r at \$0.04/vCPU-hr × 730 =
    #text(fill: green, weight: "bold")[\$4,088/month] from a config change.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Egress via CDN:] 100 TB/month direct from origin at \$0.085/GB =
    #text(fill: red, weight: "bold")[\$8,500]. At a 95% CDN hit rate, origin serves 5 TB
    (\$425) and the CDN bills ~\$0.02/GB for 95 TB (\$1,900) #sym.arrow.r
    #text(fill: green, weight: "bold")[\$2,325 total, a 73% saving] — and it is faster.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Compression:] gzip/brotli on JSON typically cuts payloads
    #text(weight: "bold")[70–80%]. 100 TB of API egress becomes ~25 TB #sym.arrow.r saves
    #text(fill: green, weight: "bold")[\$6,375/month] for one header and a few CPU cycles.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Cross-AZ chatter:] 10,000 RPS × 5 KB × 86,400 = 4.3 TB/day crossing an
    AZ boundary = 130 TB/month × \$0.02 (both directions) =
    #text(fill: red, weight: "bold")[\$2,600/month] for traffic that never leaves the region.
    #text(fill: green)[Fix:] topology-aware routing so a service prefers endpoints in its own AZ.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Committed use:] 1-year commitments typically save
    #text(weight: "bold")[30–40%], 3-year up to 60%. Commit to the
    #underline(stroke: 1pt + green)[trough] of your usage, never the peak, and leave the burst on
    on-demand or spot.
  ]
]
#v(2mm)

#h2("3 · Making cost visible", c: green)

#text(size: 9pt)[
  Cost that is not attributable is cost that nobody reduces. The prerequisite is
  #text(fill: green, weight: "bold")[tagging] --- every resource labelled with team, service and
  environment --- so the bill can be split by owner rather than arriving as one number nobody
  recognises.
  #note[Showback (here is what your service cost) changes behaviour more reliably than chargeback
  (here is your bill) in most organisations, because it informs without creating incentives to
  hide usage. Pair it with a #underline(stroke: 1pt + green)[cost-per-unit] metric — dollars per
  1,000 requests, per active user, per GB ingested — so efficiency is visible independently of
  growth. Absolute spend rising while unit cost falls is a healthy system.]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Optimising the wrong 5%.] A team spends a quarter shaving
  compute while egress and observability --- the actual majority of the bill --- go untouched.
  #text(fill: green)[Fix:] read the bill before optimising. Rank by spend, attack the top item.

  #text(fill: red, weight: "bold")[Over-committing.] Three-year reservations bought at peak, then
  the architecture changes and you pay for capacity you cannot use.
  #text(fill: green)[Fix:] commit to the stable baseline only; prefer flexible commitments that
  apply across instance families.

  #text(fill: red, weight: "bold")[Zombie resources.] Unattached volumes, idle load balancers,
  orphaned snapshots, dev clusters nobody shut down. Individually trivial, collectively
  #text(fill: red)[10–20%] of many bills. #text(fill: green)[Fix:] scheduled sweeps, mandatory
  tags, and auto-expiry on non-production environments.

  #text(fill: red, weight: "bold")[Cutting cost into an outage.] Headroom removed to save money,
  then a traffic spike arrives with nothing to absorb it (M25).
  #text(fill: green)[Fix:] treat reliability headroom as a #underline(stroke: 1pt + green)[named
  line item] in the budget, not as slack to be reclaimed.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Your cloud bill doubled. How do you investigate?]
  #linebreak()
  Break it down by service and tag, compare against traffic growth to separate scale from
  regression, then attack the largest line — usually compute idle, egress, or observability
  cardinality. #note[Testing: a methodical approach rather than a guess. Unit cost (\$ per 1,000
  requests) is what distinguishes growth from waste.]

  #text(fill: green, weight: "bold")[Q: How do you cut costs without hurting reliability?]
  #linebreak()
  Attack waste before capacity: rightsizing, CDN and compression, lifecycle tiering, zombie
  cleanup, spot for interruptible work. Protect headroom explicitly.
  #note[Testing: that you will not trade an SLO for a budget without saying so out loud.]

  #text(fill: green, weight: "bold")[Q: When are reserved instances a mistake?]
  #linebreak()
  When committed above the usage trough, or when the architecture is likely to change within the
  term. #note[Testing: awareness that a commitment is a bet on your own roadmap.]
]
#v(2mm)

#anti("optimising compute while ignoring egress")[
  A team runs a three-month efficiency programme, rightsizing every workload and saving
  #text(fill: green)[\$12k/month] on compute. The bill barely moves, because
  #text(fill: red, weight: "bold")[\$40k/month] is egress --- uncompressed JSON APIs served
  directly from origin with no CDN, plus cross-AZ service chatter. Two configuration changes
  (enable brotli, put a CDN in front) would have saved
  #underline(stroke: 1pt + red)[three times as much in a day].
  #text(fill: green)[Fix:] start from the invoice, ranked by line item. Engineering intuition
  points at compute because that is what engineers touch; the bill points elsewhere.
]
