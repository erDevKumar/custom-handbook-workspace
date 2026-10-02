// =============================================================================
// SEM HANDBOOK — master document
//
// This is the ONLY file that is compiled. Chapters are fragments included from
// part1/ and part2/; they do not set their own page geometry or numbering.
//
// WHY: compiling chapters separately and merging the PDFs made every chapter
// restart its page count at 1, so the assembled book had eight pages numbered
// "1" and a table of contents whose references pointed at nothing. A book is a
// single document. Page numbers, running heads and the TOC all depend on
// knowing where a chapter actually falls in the whole.
//
// Build:  ./build.sh      (from the project root)
// =============================================================================

#import "/shared/lib/template.typ": *

#set document(
  title: "Senior Engineering Manager: System Design & Infrastructure Handbook",
  author: "Devender Kumar",
)

#set text(font: bodyfont, size: 9.5pt, fill: ink)
#set par(leading: 0.62em, justify: true)
// Margins are MIRRORED and asymmetric: a wide outer margin on every page is
// deliberate note-taking space for a printed copy, and because it is outer it
// never falls in the gutter where a bound book makes writing impossible.
// 32mm outer still leaves 164mm of text = 85 monospace columns (widest
// diagram in the book is 69), so no figure was narrowed to buy the margin.
#set page(
  paper: "a4",
  margin: (inside: 14mm, outside: 32mm, top: 14mm, bottom: 16mm),
  fill: paper,
)

// ---------------------------------------------------------------------------
// Running head state. A chapter fragment calls `chapterhead(part, chapter)` as
// its first line; the page header reads these back. `set page(header: ..)`
// inside a function does not escape that function, so the header is configured
// ONCE here and pulls from state instead.
// ---------------------------------------------------------------------------
#set page(header: context {
  let p = counter(page).get().first()
  let inbody = bodystart.get()
  if not inbody { return }           // front matter carries no running head
  if partname.get() == "" { return } // part-title pages carry none either
  set text(font: bodyfont, size: 7.5pt, fill: luma(115))
  block(width: 100%)[
    #if calc.even(p) {
      align(left, partname.get())
    } else {
      align(right, chaptername.get())
    }
    #v(-0.55em)
    #line(length: 100%, stroke: 0.4pt + luma(205))
  ]
})

// =============================== FRONT MATTER ==============================
// Roman numerals, no running heads.
#set page(numbering: "i", number-align: center)
#include "/handbooks/sem-system-design/frontmatter/front.typ"

// =================================== BODY ==================================
// Arabic numerals restarting at 1 — standard book convention.
#counter(page).update(1)
#set page(numbering: "1", number-align: center)
#bodystart.update(true)

#include "/handbooks/sem-system-design/part1/00-part-title.typ"
#include "/handbooks/sem-system-design/part1/ch01-scalability.typ"
#include "/handbooks/sem-system-design/part1/ch02-availability.typ"
#include "/handbooks/sem-system-design/part1/ch03-consistency.typ"
#include "/handbooks/sem-system-design/part1/ch04-latency.typ"
#include "/handbooks/sem-system-design/part1/ch05-sre.typ"
#include "/handbooks/sem-system-design/part1/ch06-fault-tolerance.typ"

#include "/handbooks/sem-system-design/part2/00-part-title.typ"
#include "/handbooks/sem-system-design/part2/m01-storage-engines.typ"
#include "/handbooks/sem-system-design/part2/m02-sharding.typ"
#include "/handbooks/sem-system-design/part2/m03-consensus.typ"
#include "/handbooks/sem-system-design/part2/m04-transactions.typ"
#include "/handbooks/sem-system-design/part2/m05-caching.typ"
#include "/handbooks/sem-system-design/part2/m06-gateway.typ"
#include "/handbooks/sem-system-design/part2/m07-api-evolution.typ"
#include "/handbooks/sem-system-design/part2/m08-event-streaming.typ"
#include "/handbooks/sem-system-design/part2/m09-cdc-outbox.typ"
#include "/handbooks/sem-system-design/part2/m10-realtime.typ"
#include "/handbooks/sem-system-design/part2/m11-push.typ"
#include "/handbooks/sem-system-design/part2/m12-offline-sync.typ"
#include "/handbooks/sem-system-design/part2/m13-rate-limiting.typ"
#include "/handbooks/sem-system-design/part2/m14-id-generation.typ"
#include "/handbooks/sem-system-design/part2/m15-geospatial.typ"
#include "/handbooks/sem-system-design/part2/m16-object-storage.typ"
#include "/handbooks/sem-system-design/part2/m17-search.typ"
#include "/handbooks/sem-system-design/part2/m18-auth.typ"
#include "/handbooks/sem-system-design/part2/m19-observability.typ"
#include "/handbooks/sem-system-design/part2/m20-load-shedding.typ"
#include "/handbooks/sem-system-design/part2/m21-network.typ"
#include "/handbooks/sem-system-design/part2/m22-concurrency-control.typ"
#include "/handbooks/sem-system-design/part2/m23-coordination.typ"
#include "/handbooks/sem-system-design/part2/m24-config-flags.typ"
#include "/handbooks/sem-system-design/part2/m25-autoscaling.typ"
#include "/handbooks/sem-system-design/part2/m26-release-strategies.typ"
#include "/handbooks/sem-system-design/part2/m27-multi-region.typ"
#include "/handbooks/sem-system-design/part2/m28-multi-tenancy.typ"
#include "/handbooks/sem-system-design/part2/m29-k8s-lifecycle.typ"
#include "/handbooks/sem-system-design/part2/m30-finops.typ"
#include "/handbooks/sem-system-design/part2/m31-privacy.typ"
#include "/handbooks/sem-system-design/part2/m32-feed.typ"
#include "/handbooks/sem-system-design/part2/m33-workflow.typ"
#include "/handbooks/sem-system-design/part2/m34-zero-trust.typ"
#include "/handbooks/sem-system-design/part2/m35-zero-downtime-migration.typ"
#include "/handbooks/sem-system-design/part2/m36-telemetry.typ"

#include "/handbooks/sem-system-design/part3/00-part-title.typ"
#include "/handbooks/sem-system-design/part3/s01-traffic-spike.typ"
#include "/handbooks/sem-system-design/part3/s02-cache-failure.typ"
#include "/handbooks/sem-system-design/part3/s03-db-migration.typ"
#include "/handbooks/sem-system-design/part3/s04-idempotency.typ"
#include "/handbooks/sem-system-design/part3/s05-split-brain.typ"
#include "/handbooks/sem-system-design/part3/s06-api-sunset.typ"
#include "/handbooks/sem-system-design/part3/s07-presence.typ"
#include "/handbooks/sem-system-design/part3/s08-p99-gc.typ"
#include "/handbooks/sem-system-design/part3/s09-webhooks.typ"
#include "/handbooks/sem-system-design/part3/s10-region-outage.typ"
#include "/handbooks/sem-system-design/part3/s11-hot-partition.typ"
#include "/handbooks/sem-system-design/part3/s12-canary.typ"
#include "/handbooks/sem-system-design/part3/s13-scheduler.typ"
#include "/handbooks/sem-system-design/part3/s14-typeahead.typ"
#include "/handbooks/sem-system-design/part3/s15-postmortem.typ"

#include "/handbooks/sem-system-design/part4/00-part-title.typ"
#include "/handbooks/sem-system-design/part4/cs1-ridehailing.typ"
#include "/handbooks/sem-system-design/part4/cs2-collaboration.typ"
#include "/handbooks/sem-system-design/part4/cs3-flash-sale.typ"
#include "/handbooks/sem-system-design/part4/cs4-food-delivery.typ"

// ================================ BACK MATTER ==============================
#include "/handbooks/sem-system-design/backmatter/back.typ"
#include "/handbooks/sem-system-design/backmatter/appendix-f-playbook.typ"
#include "/handbooks/sem-system-design/backmatter/appendix-g-mocks.typ"
#include "/handbooks/sem-system-design/backmatter/back-reference.typ"
