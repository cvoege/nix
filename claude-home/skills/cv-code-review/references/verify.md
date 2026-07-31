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

## Re-derive, do not inherit

A finder wrote each candidate, and every factual claim in it is a **hypothesis**
— including the ones stated as settled fact. Wherever a candidate turns on what
some code, runtime, library, tool schema or binary *does* ("`agent()` throws
rather than returning null", "this helper already guards it", "the enum rejects
that value"), the verifier goes to that source and derives it itself. It does not
carry the finder's reading forward.

Finders work fast across a whole diff, and a confidently-worded claim with an
executed-looking justification is exactly what a wrong one looks like — the false
positives that survive into a report are never the tentative ones. So the
verifier returns `rederived` alongside each verdict: which claim it checked,
where, and whether it survived. A candidate whose mechanism was confirmed while
its load-bearing premise was taken on trust has not been verified, it has been
forwarded.

The field is required rather than encouraged for a measured reason. A verify pass
told only to "judge each candidate independently" refuted 1 of 52 candidates,
while an orchestrator that named the specific claim to re-derive refuted 2 of 26
and corrected the framing it had been handed on four batches besides. The
instruction gets skimmed; a required field does not.

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

**"It depends on the runtime" is a research task, not a verdict.** When a
candidate turns on something outside the diff — what a framework, harness,
tool schema, installed binary or third-party library actually does — go find
out before settling for PLAUSIBLE. That evidence is usually on this machine:
read the installed package or vendored source, `strings` the binary, check the
lockfile version's behavior, execute the suspect code path with the input you
claim breaks it, or find an artifact of a real previous run (logs, run records,
caches, CI output). Stay PLAUSIBLE only when you actually tried and the
evidence is not obtainable — and then say what you tried and what would settle
it.

This is the difference between a review that reports "the mechanism is real but
the trigger depends on the harness" and one that reports "I read the harness;
it validates the schema first, so this is unreachable." Both are honest; only
the second one is finished.

## Severity

Score every candidate you do not refute: **high / medium / low**, the size of
the consequence times the reachability of the trigger.

- **high** — data loss, silently wrong output, or a crash on a path most runs take.
- **medium** — real, but behind a condition most runs miss.
- **low** — narrow, loud, or trivially recoverable.
- For a cleanup finding, score the cost actually incurred, not the line count.

You are the only agent that both read this code and judged the claim, so this
is the only place a severity score can come from evidence rather than from the
wording of a summary. It seeds the report's ranking and decides which findings
the cap cuts; the synthesizer can overrule it, but it cannot invent it.

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
**themed batches** of about six (`BATCH_MAX` in the workflow). One verifier agent
per batch, returning one verdict per distinct defect in it.

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
