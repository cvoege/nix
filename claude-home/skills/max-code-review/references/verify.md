# Verification ladders

Two ladders. The precision ladder is the base definition of each verdict; the
recall-biased ladder is layered on top at high effort and above, and it is what
makes the difference between "a careful review" and a max review — it forbids
the verifier from killing a finding merely because the trigger is uncertain.

## Verdict ladder (3-state)

- **CONFIRMED** — can name the inputs/state that trigger it and the wrong
  output or crash. Quote the line.
- **PLAUSIBLE** — mechanism is real, trigger is uncertain (timing, env,
  config). State what would confirm it.
- **REFUTED** — factually wrong (code doesn't say that) or guarded elsewhere.
  Quote the line that proves it.

Keep candidates where the vote is CONFIRMED or PLAUSIBLE. Drop REFUTED.

## Recall-biased overlay (high / xhigh / max / ultra)

**PLAUSIBLE by default** — do not refute a candidate for being "speculative" or
"depends on runtime state" when the state is realistic: concurrency races,
nil/undefined on a rare-but-reachable path (error handler, cold cache, missing
optional field), falsy-zero treated as missing, off-by-one on a boundary the
code does not exclude, retry storms / partial failures, regex/allowlist that
lost an anchor. These are PLAUSIBLE.

**REFUTED** only when constructible from the code: factually wrong (quote the
actual line); provably impossible (type/constant/invariant — show it); already
handled in this diff (cite the guard); or pure style with no observable effect.

## Voting rules by level

| Level | Votes per candidate | Kill rule |
|---|---|---|
| `low` | none (no verify pass) | n/a |
| `medium` | 1 | REFUTED drops it |
| `high` | 1, recall-biased | REFUTED drops it |
| `xhigh` | 1, recall-biased | REFUTED drops it — a single non-REFUTED vote carries the finding; do NOT drop on uncertainty |
| `max` | 1, recall-biased | same as xhigh |
| `ultra` | 3 independent, perspective-diverse | needs **2 of 3 refutes** to kill |

## Batching

Verification runs on the output of the pooling pass (SKILL.md Phase 1.5), which
has already clustered candidates by **root cause** and grouped the clusters into
**themed batches** of about four. One verifier agent per batch, returning one
verdict per distinct defect in it.

Theme, not location. Batching by `(file, line)` looks equivalent and is not: it
merges two different defects that share a line, splits one defect that two
finders spelled with different paths, and — the real cost — hands every verifier a
single isolated claim, so nothing in the pipeline can settle a disagreement
between two finders. Batching by theme buys both: the verifier reads the
subsystem once for every claim about it, and it can be told which contradiction
to resolve.

Three rules that survive from the old grouping note:

- **Clustering is dedup; batching is not.** Every distinct defect in a batch
  keeps its own verdict.
- **Judge the defect, not the wording.** A candidate annotated with other
  finders' framings of the same root cause is confirmed if *any* of those
  framings is the correct account of what goes wrong.
- **A defect no verifier rendered a verdict on is dropped**, so an unverified
  candidate never reaches the report labelled PLAUSIBLE — but the drop is counted
  and reported, never silent.

## Contradictions

A batch may carry a list of disagreements the pooling pass found: two finders
reaching opposite conclusions about the same code. Settling those is the reason
those candidates were batched together. Do not average the readings, do not
hedge, and do not return PLAUSIBLE for both sides — read the code, decide, and
quote the deciding line. An unsettled contradiction becomes either a false
finding in the report or a real bug dropped from it.
