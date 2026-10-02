#import "/shared/lib/template.typ": *
#reg(1, "M15", "Geospatial Indexing & Ingestion")
#chapterhead("Part 2 · Modules", "M15 · Geospatial Indexing")
#ix("Geohash")
#ix("H3")
#ix("S2 cells")

#h1("M15 · Geospatial Indexing & Ingestion", c: green)

#text[
  Databases index one dimension well. Location is two, and "find everything within 5 km" has no
  efficient answer in a B-tree over `(lat, lng)`. Every scheme here does the same trick: project
  2-D space onto a #underline(stroke: 1pt + green)[1-D ordered key] that preserves locality, so
  a range scan becomes a spatial query.
]
#v(2mm)

#h2("1 · The three encodings", c: blue)

#align(center, cetz.canvas(length: 0.82cm, {
  import cetz.draw: *
  // geohash grid
  content((2.6, 2.9), dlbl("GEOHASH — rectangles", sz: 7.5pt, c: blue))
  for i in range(4) { for j in range(4) {
    rect((0.8 + i * 0.9, 0.2 + j * 0.6), (1.7 + i * 0.9, 0.8 + j * 0.6),
      stroke: 0.7pt + luma(160))
  }}
  rect((2.6, 1.4), (3.5, 2.0), stroke: 1.4pt + blue, fill: rgb("#dbe9f7"))
  content((2.6, -0.4), dlbl("prefix = containment", sz: 6.3pt, c: blue))
  content((2.6, -1.0), dlbl("but cells distort near poles", sz: 6.3pt, c: red))

  // S2 cells
  content((8.6, 2.9), dlbl("S2 — cube-projected quadtree", sz: 7.5pt, c: orange))
  circle((8.6, 1.2), radius: 1.5, stroke: 1.2pt + luma(150))
  for (a, b) in ((7.4, 1.0), (8.0, 1.6), (8.8, 0.8), (9.3, 1.5)) {
    rect((a, b), (a + 0.55, b + 0.45), stroke: 1pt + orange)
  }
  content((8.6, -0.4), dlbl("64-bit cell id, 31 levels", sz: 6.3pt, c: orange))
  content((8.6, -1.0), dlbl("near-uniform area globally", sz: 6.3pt, c: green))

  // H3 hexagons
  content((14.6, 2.9), dlbl("H3 — hexagons", sz: 7.5pt, c: green))
  let hex(cx, cy, r, c) = {
    let pts = ()
    for k in range(6) {
      pts.push((cx + r * calc.cos(k * 60deg), cy + r * calc.sin(k * 60deg)))
    }
    line(..pts, close: true, stroke: 1pt + c)
  }
  hex(14.6, 1.2, 0.55, green)
  for k in range(6) {
    hex(14.6 + 0.95 * calc.cos(k * 60deg + 30deg), 1.2 + 0.95 * calc.sin(k * 60deg + 30deg), 0.55, luma(150))
  }
  content((14.6, -0.4), dlbl("all neighbours equidistant", sz: 6.3pt, c: green))
  content((14.6, -1.0), dlbl("best for flow / aggregation", sz: 6.3pt, c: green))
}))
#v(2mm)

#text(size: 9pt)[
  #text(fill: blue, weight: "bold")[Geohash] interleaves latitude and longitude bits into a
  base32 string. A shared prefix means spatial proximity, so `LIKE 'u4pru%'` is a bounding-box
  query in any ordinary index. The weaknesses are real: cells are
  #text(fill: red)[rectangular and distort toward the poles], and two points either side of a
  cell boundary share no prefix despite being metres apart --- so you must always query the
  #underline(stroke: 1pt + red)[8 neighbouring cells] too.

  #text(fill: orange, weight: "bold")[S2] (Google) projects the sphere onto a cube and applies a
  Hilbert-curve quadtree, giving 64-bit cell ids with far better area uniformity and excellent
  1-D locality. #text(fill: green, weight: "bold")[H3] (Uber) uses hexagons, whose decisive
  property is that #underline(stroke: 1pt + green)[all six neighbours are equidistant] --- with
  squares, diagonal neighbours are 1.41× further, which quietly corrupts any flow, diffusion or
  nearest-neighbour calculation built on them.
]
#v(2mm)

#h2("2 · Choosing", c: purple)

#table(
  columns: (auto, 1fr, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#f5eefa") } else { none },
  text(font: headfont, size: 8.5pt, fill: purple)[Need],
  text(font: headfont, size: 8.5pt, fill: purple)[Use],
  text(font: headfont, size: 8.5pt, fill: purple)[Why],

  text(size: 8.3pt)[Proximity search in an existing SQL DB],
  text(size: 8pt)[Geohash prefix, or PostGIS `GIST`],
  text(size: 8.3pt)[no new infra],

  text(size: 8.3pt)[Supply/demand aggregation by area],
  text(size: 8pt)[H3 at a fixed resolution],
  text(size: 8.3pt)[uniform cells],

  text(size: 8.3pt)[Global coverage, varied density],
  text(size: 8pt)[S2 with mixed levels],
  text(size: 8.3pt)[adaptive],

  text(size: 8.3pt)[Exact polygon containment],
  text(size: 8pt)[PostGIS / a real geometry engine],
  text(size: 8.3pt)[cells approximate],

  text(size: 8.3pt)[Ephemeral "who is near me now"],
  text(size: 8pt)[Redis `GEOADD` / `GEOSEARCH`],
  text(size: 8.3pt)[in-memory, TTL],
)
#v(2mm)

#h2("3 · High-frequency ingestion arithmetic", c: orange)

#formula("1M drivers reporting position")[
  #text(size: 8.6pt)[
    Naive: 1 ping/driver/second #sym.arrow.r
    #text(fill: red, weight: "bold")[1,000,000 writes/s]. At 100 B each that is 100 MB/s, 8.6 TB
    a day, and no ordinary database will accept it.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Adaptive batching:] ping every 4 s while moving, every 30 s while
    idle. If 30% are moving: (300,000/4) + (700,000/30) =
    75,000 + 23,333 = #text(fill: green, weight: "bold")[98,333 writes/s] — a
    #text(weight: "bold")[10×] reduction with no loss of useful fidelity.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Store current state, stream the history:] latest position in Redis
    (1M × 100 B = #text(fill: green, weight: "bold")[100 MB], trivially cacheable), full track to
    Kafka #sym.arrow.r columnar storage for analytics. Never keep a hot table of every historical
    ping in your operational database.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Battery:] the radio dominates, not the GPS fix. 1 ping/s keeps the
    modem awake continuously; batching 10 fixes into one transmission every 40 s cuts radio-on
    time by #text(fill: green, weight: "bold")[~90%] for the same information.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[The boundary problem.] A query cell returns nothing while a
  match sits 10 m away in the adjacent cell. #text(fill: green)[Fix:] always query the target
  cell #underline(stroke: 1pt + green)[plus its neighbours] (`kRing` in H3, `GetAllNeighbors` in
  S2), then filter by true distance. Candidates who forget this ship a search that misses the
  nearest result.

  #text(fill: red, weight: "bold")[Hot cell in a dense city.] One H3 cell covering a stadium
  holds 50,000 users while rural cells hold none, so the shard owning it saturates.
  #text(fill: green)[Fix:] mixed resolutions — subdivide dense cells — or shard by
  `(cell, bucket)` with a salt.

  #text(fill: red, weight: "bold")[GPS noise and tunnels.] Raw fixes jitter by tens of metres and
  vanish in tunnels and urban canyons, so a stationary vehicle appears to wander.
  #text(fill: green)[Fix:] smooth client-side (Kalman filter or the platform's fused provider),
  and #text(fill: purple)[dead-reckon] through gaps from last known heading and speed, marking
  such points as estimated.

  #text(fill: red, weight: "bold")[Unbounded history.] Every ping kept forever at 8.6 TB/day.
  #text(fill: green)[Fix:] tiered retention — full resolution for days, downsampled for months,
  aggregates thereafter.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Find all drivers within 2 km.]
  #linebreak()
  Index by cell id (H3/S2/geohash), look up the rider's cell and its ring of neighbours, fetch
  candidates, then filter by exact haversine distance. #note[Testing: do you include the
  neighbour ring? Omitting it is the single most common error, and it produces a bug that only
  shows up near boundaries.]

  #text(fill: green, weight: "bold")[Q: Why hexagons rather than squares?]
  #linebreak()
  Equidistant neighbours. With squares, diagonal neighbours are 1.41× further, which distorts
  any flow or diffusion model. #note[Testing: whether you know H3's actual justification rather
  than that Uber uses it.]

  #text(fill: green, weight: "bold")[Q: 1M drivers pinging every second — how do you cope?]
  #linebreak()
  Do not accept that rate. Adapt the interval to movement, batch on-device, keep current state
  in Redis and stream history to a log. #note[Testing: challenging the premise. The strong answer
  reduces the load before designing for it.]
]
#v(2mm)

#anti("storing raw lat/lng and computing distance in SQL")[
  `SELECT * FROM drivers WHERE SQRT(POW(lat-?,2)+POW(lng-?,2)) < 0.02` is a
  #text(fill: red, weight: "bold")[full table scan] — no index can serve a computed expression
  over two columns — and the maths is wrong anyway, because a degree of longitude is 111 km at
  the equator and near zero at the poles. It appears to work in a city-scale test and fails at
  scale and at latitude. #text(fill: green)[Fix:] an indexed cell id for the candidate set,
  haversine (or PostGIS `ST_DWithin`) only for the final filter over a handful of rows.
]
