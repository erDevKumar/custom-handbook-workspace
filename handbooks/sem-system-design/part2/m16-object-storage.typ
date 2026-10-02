#import "/shared/lib/template.typ": *
#reg(1, "M16", "Object Storage & Media Pipelines")
#chapterhead("Part 2 · Modules", "M16 · Object Storage & Transcoding")
#ix("Presigned URL")
#ix("Resumable upload")
#ix("ABR ladder")

#h1("M16 · Object Storage & Media Pipelines", c: purple)

#text[
  The rule that shapes every media system: #underline(stroke: 1pt + red)[bytes never pass
  through your API servers]. Clients upload straight to object storage and download straight
  from a CDN. Your services handle metadata, authorisation and orchestration --- never the
  payload.
]
#v(2mm)

#h2("1 · Upload and transcode pipeline", c: blue)

#align(center, cetz.canvas(length: 0.82cm, {
  import cetz.draw: *
  swimlane(-0.4, -2.0, 18.4, 2.4, "UPLOAD → PROCESS → SERVE", purple, rgb("#f5eefa"))
  rnode(2.4, 1.3, "cl", "client", "chunked · resumable", purple, w: 3.4, h: 0.9)
  rnode(7.2, 1.3, "api", "API", "issues presigned URL", blue, w: 3.6, h: 0.9)
  line("cl.east", "api.west", mark: (end: ">"), stroke: hot); badge(4.8, 1.85, "1", green)
  content((7.2, 0.45), dlbl("authz + quota check only", sz: 6.2pt, c: blue))

  cylinder(12.6, 1.3, "s3", "S3 / GCS", orange, w: 3.6, h: 1.1)
  line("cl.north", (2.4, 2.1), (12.6, 2.1), "s3.north", mark: (end: ">"), stroke: hot)
  badge(7.5, 2.1, "2", green)
  content((7.5, 2.6), dlbl("bytes go DIRECT — never through the API", sz: 6.4pt, c: green))

  rnode(16.2, 1.3, "ev", "event", "ObjectCreated", green, w: 2.8, h: 0.85)
  line("s3.east", "ev.west", mark: (end: ">"), stroke: async); badge(15.0, 1.75, "3", purple)

  rnode(3.6, -1.0, "q", "job queue", "SQS · priority", green, w: 3.4, h: 0.9)
  line("ev.south", (16.2, -1.0), "q.east", mark: (end: ">"), stroke: async)
  badge(9.8, -1.0, "4", purple)
  rnode(8.4, -1.0, "w", "FFmpeg workers", "spot · autoscaled", green, w: 4.0, h: 0.9)
  line("q.east", "w.west", mark: (end: ">"), stroke: hot)
  rnode(13.6, -1.0, "cdn", "CDN", "HLS / DASH ladder", blue, w: 4.0, h: 0.9)
  line("w.east", "cdn.west", mark: (end: ">"), stroke: hot); badge(11.0, -0.55, "5", green)
  bracket(0.6, 17.4, -2.6, "API touches metadata only — it never sees a byte of media", purple)
}))
#v(2mm)

#text(size: 9pt)[
  #text(fill: green, weight: "bold")[Presigned URLs] let the client write directly to a bucket
  with a short-lived, scope-limited credential. The API's job is authorisation and quota, which
  takes milliseconds, rather than proxying gigabytes.
  #note[Scope the signature tightly: specific key, content-type, maximum size, and an expiry of
  minutes. A presigned PUT with a wildcard prefix and a 24-hour expiry is a
  #text(fill: red)[write credential to your bucket] that will end up in a log or a mobile app
  bundle.]

  #text(fill: purple, weight: "bold")[Resumable upload (tus).] A 2 GB video on a mobile network
  will be interrupted. The tus protocol negotiates an upload URL, then accepts `PATCH` requests
  with a byte offset, so the client resumes from where it stopped rather than restarting. S3
  multipart upload solves the same problem with a part-number abstraction.
]
#v(2mm)

#h2("2 · Storage classes and the real cost", c: orange)

#table(
  columns: (auto, auto, auto, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#fff3e8") } else { none },
  text(font: headfont, size: 8.5pt, fill: orange)[Class],
  text(font: headfont, size: 8.5pt, fill: orange)[\$/TB/mo],
  text(font: headfont, size: 8.5pt, fill: orange)[Retrieval],
  text(font: headfont, size: 8.5pt, fill: orange)[Use],

  text(size: 8.3pt)[Standard], text(size: 8.3pt)[~\$23], text(size: 8.3pt, fill: green)[instant],
  text(size: 8pt)[Active media, anything a user may open today],
  text(size: 8.3pt)[Infrequent access], text(size: 8.3pt)[~\$12.50], text(size: 8.3pt, fill: orange)[instant + fee],
  text(size: 8pt)[Older content; retrieval fee punishes surprise popularity],
  text(size: 8.3pt)[Glacier Instant], text(size: 8.3pt)[~\$4], text(size: 8.3pt, fill: orange)[ms, higher fee],
  text(size: 8pt)[Archives with rare but latency-sensitive reads],
  text(size: 8.3pt)[Glacier Deep], text(size: 8.3pt, fill: green)[~\$1], text(size: 8.3pt, fill: red)[up to 12 h],
  text(size: 8pt)[Compliance retention you hope never to read],
)
#v(1.5mm)

#key[
  Storage is rarely the bill. #text(fill: red, weight: "bold")[Egress is.] At roughly
  \$85/TB out to the internet, serving 100 TB/month costs
  #text(fill: red, weight: "bold")[~\$8,500] while storing it costs ~\$2,300. A CDN in front
  is not a performance optimisation --- it is the
  #underline(stroke: 1pt + green)[primary cost control], because origin egress collapses to
  cache misses only.
]
#v(2mm)

#h2("3 · Capacity arithmetic", c: orange)

#formula("A video platform, sized")[
  #text(size: 8.6pt)[
    100,000 uploads/day, 10 min average, 1080p source ≈ 500 MB #sym.arrow.r
    #text(fill: orange, weight: "bold")[50 TB/day] ingested.
    #linebreak()
    An ABR ladder (240p/480p/720p/1080p) adds ~1.6× the source
    #sym.arrow.r #text(fill: orange, weight: "bold")[80 TB/day] of renditions, so ~130 TB/day
    total, ≈ #text(fill: red, weight: "bold")[3.9 PB/month] of new storage.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Transcode compute:] 10 min of 1080p ≈ 5 min of CPU per rendition × 4 =
    20 CPU-minutes per upload. 100,000 × 20 = #text(weight: "bold")[2M CPU-minutes/day] =
    #text(fill: orange, weight: "bold")[1,389 CPU-hours/day] ≈ 58 cores running flat out.
    Provision ~100 cores on #text(fill: green)[spot instances] — transcoding is interruptible and
    re-runnable, the ideal spot workload.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Lifecycle saving:] move to Infrequent Access after 30 days and Glacier
    after 180. A 3.9 PB/month inflow costs ~\$90k/month at Standard;
    tiered it approaches #text(fill: green, weight: "bold")[\$20k]. Lifecycle rules are three
    lines of config and the largest single cost lever you have.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Orphaned objects.] An upload completes but the metadata write
  fails, so bytes sit in the bucket that no row references and nothing will ever delete.
  #text(fill: green)[Fix:] write a `pending` metadata row #underline(stroke: 1pt + green)[first],
  confirm on the storage event, and sweep anything still pending after 24 hours.

  #text(fill: red, weight: "bold")[Transcode poison.] A malformed file hangs FFmpeg forever and
  the worker never acknowledges, so the job is redelivered and hangs the next worker too, until
  the fleet is consumed. #text(fill: green)[Fix:] hard timeouts per job, bounded attempts, then a
  dead-letter queue — plus resource limits, because a crafted file can also exhaust memory.

  #text(fill: red, weight: "bold")[Presigned URL leakage.] A long-lived upload URL is logged,
  cached by a proxy, or shipped in an app binary, giving an attacker write access to the bucket.
  #text(fill: green)[Fix:] minutes-long expiry, exact-key scope, content-length and content-type
  constraints.

  #text(fill: red, weight: "bold")[Thumbnail stampede.] A video goes viral before its renditions
  exist, so a million viewers all trigger on-the-fly transcoding of the same asset.
  #text(fill: green)[Fix:] a per-asset lock around generation (the stampede pattern from M5), and
  serve a placeholder until the real rendition lands.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Design a video upload service.]
  #linebreak()
  Presigned resumable upload straight to object storage, a storage event enqueuing transcode
  jobs, FFmpeg workers on spot producing an ABR ladder, HLS/DASH served via CDN, lifecycle rules
  tiering cold renditions. #note[Testing: do bytes ever touch your API? If yes, you have designed
  a bandwidth bill and a scaling bottleneck in one.]

  #text(fill: green, weight: "bold")[Q: How do you handle a 2 GB upload on a phone?]
  #linebreak()
  Chunked and resumable (tus or S3 multipart), with the client tracking offsets and resuming
  across network changes. #note[Testing: awareness that mobile uploads are interrupted as a
  matter of course, not as an exception.]

  #text(fill: green, weight: "bold")[Q: Where does the money go?]
  #linebreak()
  Egress, then transcode compute, then storage. CDN caching and lifecycle tiering attack the
  first and third; spot instances the second. #note[Testing: cost literacy — a senior signal.
  Most candidates optimise storage, which is the cheapest part.]
]
#v(2mm)

#anti("proxying uploads through the API tier")[
  `POST /upload` streams a 2 GB file through an API pod into object storage. The pod holds the
  connection for minutes, consuming a worker and ~2 GB of buffer; autoscaling reacts to CPU,
  which is #text(fill: red)[idle while blocked on I/O], so it never scales. A hundred concurrent
  uploads exhaust the pool and #underline(stroke: 1pt + red)[every unrelated API request starts
  timing out]. You also pay ingress twice and double the failure surface.
  #text(fill: green)[Fix:] presigned direct-to-storage uploads. The API issues a credential and
  returns in milliseconds.
]
