# Part 2 module template — the 7 parts

The original spec says "this exact 7-part template" but never lists the seven parts.
This file fixes them so all 36 modules are consistent. Derived from what worked in Part 1
plus the interview-guide section absorbed from the alternate spec (see memory:
`sem-handbook-scope`).

Each module is **2 A4 pages**, in this order:

1. **Core Mechanics** — one paragraph framing the problem, then how the thing actually works
   internally. No definitions-only prose.
2. **Architecture Diagram** — CeTZ, using `rnode` (title + tech/capacity subtitle), `badge`
   (numbered steps), `swimlane`, `bracket`. Must carry real technologies and real numbers,
   at the standard set by `samples/sample-detailed.typ`.
3. **Trade-off Matrix** — a table of competing options with the decisive column being
   *when to use which*, never "X is better".
4. **Capacity / Arithmetic** — a `formula` block with step-by-step numbers
   (spec checklist rule 2). Every figure shows its working.
5. **Failure Modes** — what breaks, the mechanism, and the named fix.
6. **Interview Guide** — 3–4 Q&A: the question, a short answer, what the interviewer is
   actually testing, and the common wrong answer.
7. **Anti-Pattern** — one `anti()` block (spec checklist rule 3, mandatory).

Plus a `key()` callout wherever the single takeaway deserves to be unmissable.

## Verification checklist per module (spec Section 0)

- [ ] 1. Canonical sources named where one exists (paper, author, year)
- [ ] 2. All arithmetic shown step by step
- [ ] 3. At least one explicit anti-pattern
- [ ] 4. Current standards (OTel, HTTP/3, K8s, eBPF, CNCF)
- [ ] 5. ~~Monochrome ASCII~~ — **retired**, colour vector diagrams instead

## Build

```
./build.sh                 # everything + merges
./build.sh part2-mod01.typ # one file
```
