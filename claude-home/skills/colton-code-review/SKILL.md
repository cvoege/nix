---
name: colton-code-review
description: Runs a multi-agent code review of a diff, branch, PR, or file — a fleet of specialized subagents each review the change from a different angle (security, correctness, performance, style, test coverage, architecture, dependencies, docs drift), findings are deduplicated and ranked by severity. Use whenever the user asks to "review my code/changes/branch/PR", "code review", "check this diff", or invokes it explicitly as /colton-code-review. Supports effort levels (quick, standard, max) to trade speed for thoroughness.
---

# Code Review Max

A tunable, multi-angle code review skill you fully own. It replicates the useful shape of a fleet-of-subagents review — parallel specialists, severity tagging, a verification pass — as plain files you can edit.

## Effort levels

Pick based on user request or default to `standard`. The user can ask for a level by name ("quick review", "max review", "review at max") or you can infer it from context (small typo fix → quick; pre-merge PR → standard or max).

| Level | Agents run | Verification pass | Best for |
|---|---|---|---|
| `quick` | security, correctness | No | Fast sanity check, small diffs, WIP |
| `standard` | security, correctness, performance, style, test-coverage | No | Default — most PRs |
| `max` | all 8: security, correctness, performance, style, test-coverage, architecture, dependency, docs-drift | Yes — finding-verifier pass at the end | Pre-merge, high-stakes changes, when you want the most thorough pass |

If the user just says "review this" with no level, use `standard`. If they say "quick" use `quick`. If they say "max", "thorough", or "everything", use `max`.

## Step 1: Determine the review target

Figure out what to review, in this priority order:
1. Explicit target the user gave (file path, branch name, PR number, `main...feature` ref range)
2. If none given: compare the changes to the stack parent, `git stack parent`. If this PR is not part of a stack, use `git stack trunk` to find the main branch. 
3. If not in a git repo or no changes found, ask the user what to review — don't guess.

Run `git diff` (or the appropriate scoped diff for the target) yourself first, so you know the size of the review before spawning agents. If the diff is empty, tell the user and stop.

## Step 2: Read project-specific config

Before spawning any agents, check for and read (if present):
- `REVIEW.md` at repo root — review-specific instructions, highest priority, overrides default agent behavior below
- `CLAUDE.md` at repo root and relevant subdirectories — general project conventions

If `REVIEW.md` exists, its content should be prepended to every agent's task prompt as the highest-priority instruction, exactly the way the real product's REVIEW.md works — see `references/review-md-format.md` for the format users write these in.

## Step 3: Spawn the review agents

Based on the effort level, spawn the corresponding agents from `agents/` **in parallel** (single message, multiple Task tool calls). Each agent is a self-contained reviewer — give it:
- The diff (or a pointer to get it themselves via git commands, for large diffs)
- Any `REVIEW.md` content, prepended
- Relevant `CLAUDE.md` content

Agent files:
- `agents/security-reviewer.md`
- `agents/correctness-reviewer.md`
- `agents/performance-reviewer.md`
- `agents/style-reviewer.md`
- `agents/test-coverage-reviewer.md`
- `agents/architecture-reviewer.md` (standard/max only)
- `agents/dependency-reviewer.md` (standard/max only)
- `agents/docs-drift-reviewer.md` (max only)

Each returns a JSON array of findings (see individual agent files for schema). Collect all arrays.

## Step 4: Verify (max effort only)

At `max` effort, pass the full combined findings list to `agents/finding-verifier.md` as a single task. It reads the actual code for each finding, confirms/rejects/merges, and returns the filtered list plus a tally. Use its output as the final findings list.

At `quick`/`standard` effort, skip this — use the raw combined findings, but still deduplicate trivially yourself (drop exact file+line+category duplicates across agents).

## Step 5: Rank and present

1. Sort findings by severity: critical → high → medium → low.
2. Apply any `REVIEW.md` nit-cap or severity-redefinition rules if present.
3. Present as a list, grouped by severity, each entry showing: file:line, one-line summary, brief reasoning, suggested fix. Use the severity markers below for a quick scan.

| Marker | Severity | Meaning |
|---|---|---|
| 🔴 | Critical/High | Should be fixed before merging |
| 🟡 | Medium | Worth fixing, not blocking |
| ⚪ | Low/Nit | Minor, optional |

Open with a one-line tally, e.g. `4 findings: 1 critical, 2 medium, 1 nit` or `No issues found` if empty — don't bury that in the middle.

If nothing was found across all agents, say so plainly and briefly — don't pad the response.

## Step 6: Offer to act

After presenting findings, offer (don't do automatically unless asked): fix the findings, or fix just the critical/high ones. If the user says fix, edit the actual files — don't just describe the fix.

## Tuning this skill

This whole thing is yours to edit:
- **Add/remove angles**: add a new file to `agents/`, following the existing schema (severity/category/subcategory/file/line/summary/reasoning/suggested_fix JSON), then reference it in the effort table above.
- **Change what counts as `quick`/`standard`/`max`**: edit the table in Step 1.
- **Change severity calibration globally**: edit the individual agent files' "What to check" sections.
- **Per-repo tuning without touching this skill**: use `REVIEW.md`, see `references/review-md-format.md`.
