#import "/shared/lib/template.typ": *
#reg(1, "M28", "Multi-Tenancy & Isolation")
#chapterhead("Part 2 · Modules", "M28 · Multi-Tenancy")
#ix("Multi-tenancy")
#ix("Noisy neighbour")
#ix("Row-level security")

#h1("M28 · Multi-Tenancy & Isolation", c: blue)

#text[
  Multi-tenancy is a spectrum between two costs: shared infrastructure is cheap but lets one
  tenant hurt another; dedicated infrastructure is isolated but multiplies operational burden by
  the number of customers. Most mature systems run #underline(stroke: 1pt + green)[both at
  once], with tier determining which.
]
#v(2mm)

#h2("1 · Pool, bridge, silo", c: blue)

#pfig("Fig M28.1 · one tenant's query through the isolation controls, pool to silo")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.4, 20.6, 2.9, "tenant id on the JWT · RLS enabled on every table · a test proving tenant A cannot read tenant B by primary key")

  ppill(1.8, 0, "in", "tenant request", w: 3.6)
  pstep(6.6, 0, "a", "per-tenant limiter", "Envoy · cap by tier", st-integ, n: 1, actor: "gateway", w: 4.4)
  pdec(11.7, 0, "d", "over quota?", w: 2.2)
  pstep(16.9, 0, "b", "SET app.tenant_id", "PgBouncer txn mode", st-auto, n: 2, actor: "repo layer", w: 4.6)
  pstep(16.7, -3.5, "c", "RLS filters the rows", "Postgres policy, not WHERE", st-auto, n: 3, actor: "", w: 5.6)
  ppill(8.9, -3.5, "out", "only this tenant's rows", c: green, w: 5.4)
  pstep(3.2, -3.5, "x", "429 + promote to silo", "above threshold, own stack", st-dec, n: 4, actor: "", w: 5.6)

  line("in.east", "a.west", mark: (end: ">"), stroke: hot)
  line("a.east", "d.west", mark: (end: ">"), stroke: hot)
  line("d.east", "b.west", mark: (end: ">"), stroke: hot)
  plabel(14.1, 0, "no", c: green)
  line("b.south", "c.north", mark: (end: ">"), stroke: hot)
  plabel(17.8, -1.8, "scoped conn", c: green, dy: 0.0)
  line("c.west", "out.east", mark: (end: ">"), stroke: hot)
  plabel(12.6, -3.5, "scoped rows", c: green)
  line("d.south", (11.7, -1.9), (3.2, -1.9), "x.north", mark: (end: ">"), stroke: except)
  plabel(7.5, -1.9, "yes — noisy neighbour", c: red, dy: -0.45)
  content((3.2, -5.1), dlbl("the top tenant is 20–40% of load; size the pool from the p99 tenant, never the mean", sz: 6.6pt, c: red))
}))
#pcards(
  [Tenancy enforced below the application: row-level security plus a repository layer that cannot emit an unscoped query. Tenant id in every cache key, set by the client wrapper.],
  [In: a request carrying a tenant id. Out: rows the database proved belong to that tenant — or a 429, and a silo for anyone past the threshold.],
  [Envoy per-tenant limits · PgBouncer transaction mode with a per-tenant cap · Postgres RLS + `statement_timeout` · an analytics replica for reports],
)
#v(1.5mm)

#table(
  columns: (auto, auto, auto, auto, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#eef4fb") } else { none },
  text(font: headfont, size: 8.5pt, fill: blue)[Model],
  text(font: headfont, size: 8.5pt, fill: blue)[Cost/tenant],
  text(font: headfont, size: 8.5pt, fill: blue)[Blast radius],
  text(font: headfont, size: 8.5pt, fill: blue)[Noisy nbr],
  text(font: headfont, size: 8.5pt, fill: blue)[Fits],

  text(size: 8.3pt)[Pool], text(size: 8.3pt, fill: green)[lowest],
  text(size: 8.3pt, fill: red)[all tenants], text(size: 8.3pt, fill: red)[severe],
  text(size: 8pt)[Self-serve, long tail, free tier],

  text(size: 8.3pt)[Bridge], text(size: 8.3pt, fill: orange)[medium],
  text(size: 8.3pt, fill: orange)[per DB], text(size: 8.3pt, fill: orange)[moderate],
  text(size: 8pt)[Mid-market; clean per-tenant backup and export],

  text(size: 8.3pt)[Silo], text(size: 8.3pt, fill: red)[highest],
  text(size: 8.3pt, fill: green)[one tenant], text(size: 8.3pt, fill: green)[none],
  text(size: 8pt)[Enterprise, regulated, sovereignty requirements],
)
#v(2mm)

#key[
  The decisive question is not cost --- it is #underline(stroke: 1pt + green)[what a bug costs
  you]. In a pooled model, one missing `WHERE tenant_id = ?` is a
  #text(fill: red, weight: "bold")[cross-tenant data breach]. That single risk is why regulated
  customers pay for silos, and why pooled systems must enforce tenancy somewhere lower than
  application code.
]
#v(2mm)

#h2("2 · Enforcing isolation below the application", c: purple)

#text(size: 9pt)[
  Relying on every developer to remember a `tenant_id` predicate is a losing strategy --- one
  omission in one query is enough. Push enforcement down:
  #text(fill: green, weight: "bold")[row-level security] in Postgres applies a policy the
  database enforces regardless of the query; a #text(fill: green, weight: "bold")[repository
  layer] that refuses to build a query without a tenant scope; or
  #text(fill: green, weight: "bold")[connection-level] settings (`SET app.tenant_id`) that
  policies read.
  #note[Test this adversarially: a test that authenticates as tenant A and attempts to read
  tenant B's row by primary key should #underline(stroke: 1pt + green)[fail] at the database, not
  merely be absent from the UI. If that test does not exist, the isolation is aspirational.]
]
#v(2mm)

#h2("3 · Capacity arithmetic", c: orange)

#formula("Tenant skew — why averages mislead")[
  #text(size: 8.6pt)[
    1,000 tenants, 10,000 QPS total #sym.arrow.r average
    #text(weight: "bold")[10 QPS/tenant]. The average is useless, because B2B load follows a
    power law.
    #linebreak()
    Realistic distribution: the top tenant is often
    #text(fill: red, weight: "bold")[20–40%] of total load. So one tenant may be
    #text(fill: red, weight: "bold")[2,000–4,000 QPS] — 200–400× the average.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Sizing consequence:] provisioning from the mean under-provisions by two
    orders of magnitude for the largest tenant. Size shared pools from the
    #underline(stroke: 1pt + green)[p99 tenant], and move anyone above a threshold into their own
    silo — both to protect others and because they are usually paying enough to fund it.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Connection pool exhaustion:] 1,000 tenants × 5 connections each =
    #text(fill: red, weight: "bold")[5,000 connections], far beyond a typical Postgres
    `max_connections` of 100–500. #text(fill: green)[Fix:] PgBouncer in transaction mode so
    connections are shared, with a per-tenant cap so one tenant cannot consume the pool.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[The noisy neighbour.] One tenant runs an unindexed report
  across their largest table, saturating shared database I/O, and every other tenant sees
  timeouts. #text(fill: green)[Fix:] per-tenant rate limits and concurrency caps (M13, M20),
  statement timeouts, and a separate replica for analytical queries.

  #text(fill: red, weight: "bold")[Cross-tenant data leak.] One query missing its tenant
  predicate. #text(fill: green)[Fix:] row-level security as the backstop, plus the adversarial
  test above. This is the failure that ends contracts.

  #text(fill: red, weight: "bold")[Migration at silo scale.] A schema change must now be applied
  to 400 databases; it half-succeeds and the fleet is in mixed states.
  #text(fill: green)[Fix:] automated, idempotent, resumable migrations with per-tenant status
  tracking — and expand–contract (M35) so mixed states are valid.

  #text(fill: red, weight: "bold")[Shared cache key collision.] A cache key of `user:42` without
  a tenant prefix serves tenant A's data to tenant B.
  #text(fill: green)[Fix:] tenant id in every cache key, enforced by the cache client wrapper
  rather than by convention.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Pool or silo?]
  #linebreak()
  Both, by tier: pooled for self-serve and the long tail, siloed for enterprise and regulated
  tenants, with a migration path between them. #note[Testing: do you treat it as a product
  segmentation decision rather than a purely technical one? The answer should mention price tiers.]

  #text(fill: green, weight: "bold")[Q: How do you stop one tenant degrading everyone?]
  #linebreak()
  Per-tenant rate limits and concurrency caps, statement timeouts, bulkheaded connection pools,
  and promotion to a dedicated silo past a threshold. #note[Testing: whether you name
  #underline(stroke: 1pt + green)[per-tenant] limits — a global limit does not prevent one tenant
  consuming all of it.]

  #text(fill: green, weight: "bold")[Q: How do you guarantee no cross-tenant access?]
  #linebreak()
  Enforce below the application — row-level security or a repository layer that cannot emit an
  unscoped query — and prove it with an adversarial test.
  #note[Testing: distrust of discipline as a control. "Developers will remember" is not an
  isolation mechanism.]
]
#v(2mm)

#anti("tenant isolation enforced only in application code")[
  Every query is written with `WHERE tenant_id = ?`, and code review is expected to catch
  omissions. It works for two years. Then someone adds an admin endpoint, a reporting join, or a
  new ORM path that builds the query differently --- and one tenant can read another's data. The
  bug is invisible in testing because test fixtures usually contain
  #underline(stroke: 1pt + red)[one tenant]. It surfaces as a customer reporting a stranger's
  records in their export, which is a breach notification, not a bug ticket.
  #text(fill: green)[Fix:] row-level security enforced by the database, a repository layer that
  requires a tenant scope to compile, and a permanent test that asserts tenant A cannot read
  tenant B by primary key.
]
