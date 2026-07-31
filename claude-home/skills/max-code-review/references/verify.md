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

Grouping note (workflow path): verifiers are batched **one agent per distinct
`(file, line)` location**, returning one verdict per candidate at that location
— not one agent per candidate. Grouping is not dedup: every candidate keeps its
own verdict. A candidate the verifier rendered no verdict on is dropped, so an
unverified candidate never reaches the report labelled PLAUSIBLE.
