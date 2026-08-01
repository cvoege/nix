# Review angles

The finder angles used by `cv-code-review`. These are the shared prompt
fragments — every effort level draws from the same pool, it only varies how
many angles run, how many candidates each may surface, and whether they run as
subagents or inline.

**Correctness angles**: A, B, C at medium/high; A–F at xhigh/max/ultra.
**Cleanup angles**: Reuse, Simplification, Efficiency (always).
**Plus**: Altitude and Conventions (always).

---

## Phase 0 — Gather the diff

Resolve the diff base in this order, first one that resolves winning:

1. the target passed as an argument (PR number, branch, ref range, file path) —
   review that instead;
2. `git stack parent`, when it names a branch that exists (it exits 0 printing
   `(no parent recorded for '<branch>')` on an untracked branch, so verify with
   `git rev-parse --verify --quiet refs/heads/<parent>`) — that is the PR base;
3. `git stack trunk`, which always resolves (defaulting to `main`).

With `git stack` unavailable, fall back to `@{upstream}`, then `main`, then
`HEAD~1`. Run `git diff "$base"...HEAD` for the unified diff under review. If
there are uncommitted changes, or the range diff is empty, also run
`git diff HEAD` and include the working-tree changes in scope — the review often
runs before the commit. Treat this diff as the review scope.

Also capture the change's **stated intent** — `gh pr view … --json title,body`
when there's a PR, plus `git log --format='%s%n%b' "$base"..HEAD` — and carry it
in the scope block. Angle B audits the diff against it. Omit it rather than pad
it when there's nothing meaningful to quote.

Where a **Linear** ticket is referenced (PR title `(CORE-1234)`, a `Closes`
line, a linear.app URL, or the branch name), read it via the Linear MCP
`get_issue` tool — load it with `ToolSearch` first, skip `-0000` placeholders,
and skip entirely when no Linear tool is available. Carry its requirements as a
section separate from stated intent: the ticket is what was *requested*, and an
uncovered requirement is usually a sibling PR's job, not a defect.

---

## Correctness angles

### Angle A — line-by-line diff scan

Read every hunk in the diff, line by line. Then Read the enclosing function for
each hunk — bugs in unchanged lines of a touched function are in scope (the PR
re-exposes or fails to fix them). For every line ask: what input, state, timing,
or platform makes this line wrong? Look for inverted/wrong conditions,
off-by-one, null/undefined deref, missing `await`, falsy-zero checks,
wrong-variable copy-paste, error swallowed in catch, unescaped regex metachars.

### Angle B — removed-behavior & unfinished-work auditor

Your lens is the thing that should be there and isn't. Two passes:

**Removed behavior.** For every line the diff DELETES or replaces, name the
invariant or behavior it enforced, then search the new code for where that
invariant is re-established. If you can't find it, that's a candidate: a
removed guard, a dropped error path, a narrowed validation, a deleted test that
was covering a real case.

**Unfinished work.** Audit the diff against the "Stated intent" section of the
review scope, when one is present. For every behavior the author says the
change delivers, find where the diff actually delivers it. The incomplete
change is the finding: one of N call sites updated, a helper added but never
wired in, a TODO/FIXME/stub left on the new path, a flag or option added but
never read, a promised guard/migration/cleanup missing, a stated scope boundary
("does not touch X") that the diff crosses. Name which part of the intent is
unmet and where it should have landed. If the scope carries no stated intent,
skip this pass — do not invent an intent to audit against.

**Wrong requirement.** When the scope carries a "Tracking ticket" section, check
the diff against what was actually asked for: a threshold, default, ordering,
error message, or edge case specified one way and implemented another is a
finding even when the code is internally consistent. Quote the requirement and
the line that departs from it. Do NOT report a ticket requirement this diff
simply doesn't cover — one ticket often spans several stacked PRs, so that is a
later PR's job unless this change claims to deliver it or contradicts it.

### Angle C — cross-file tracer

For each function the diff changes, find its callers (Grep for the symbol) and
check whether the change breaks any call site: a new precondition, a changed
return shape, a new exception, a timing/ordering dependency. Also check callees:
does a parallel change in the same PR make a call unsafe?

### Angle D — language-pitfall specialist

Scan for the classic pitfalls of the diff's language/framework — for example:
JS falsy-zero, `==` coercion, closure-captured loop var; Python mutable default
args, late-binding closures; Go nil-map write, range-var capture; SQL injection;
timezone/DST drift; float equality. Flag any instance the diff introduces.

### Angle E — wrapper/proxy correctness

When the PR adds or modifies a type that wraps another (cache, proxy, decorator,
adapter): check that every method routes to the wrapped instance and not back
through a registry/session/global — e.g. a caching provider holding a
`delegate` field that resolves IDs via `session.get(...)` instead of
`delegate.get(...)` will re-enter the cache or recurse. Also check that the
wrapper forwards all the methods the callers actually use.

### Angle F — untrusted input & injection surfaces

Trace every value the diff lets in from outside the program — CLI args, HTTP
request fields, file contents, environment variables, a database row, a PR body
or commit message, a ticket description, a model's output, another service's
response — from where it enters to where it is finally used. The defect is a
value that crosses from data into control: interpolated into SQL, a shell
command, a path, a URL, HTML, a regex, a format string, or into a prompt whose
surrounding instructions the value can then forge. At each boundary name the
escape / parameterize / allowlist / fence step that is missing, and check
whether anything downstream trusts the value because it "already came from us".
Also flag unbounded untrusted input: no length cap, no depth or recursion
limit, no timeout on work an outsider controls.

---

## Cleanup angles

The angles above hunt for bugs; the five below hunt for cleanup in the changed
code. Each gets its own finder, exactly like a correctness angle — one lens per
agent, never one agent covering the set.

### Reuse

Flag new code that re-implements something the codebase already has — Grep
shared/utility modules and files adjacent to the change, and name the existing
helper to call instead.

### Simplification

Flag unnecessary complexity the diff adds: redundant or derivable state,
copy-paste with slight variation, deep nesting, dead code left behind. Name
the simpler form that does the same job.

### Efficiency

Flag wasted work the diff introduces: redundant computation or repeated I/O,
independent operations run sequentially, blocking work added to startup or
hot paths. Also flag long-lived objects built from closures or captured
environments — they keep the entire enclosing scope alive for the object's
lifetime (a memory leak when that scope holds large values); prefer a
class/struct that copies only the fields it needs. Name the cheaper
alternative.

### Altitude

Check that each change is implemented at the right depth, not as a fragile
bandaid. Special cases layered on shared infrastructure are a sign the fix
isn't deep enough — prefer generalizing the underlying mechanism over adding
special cases.

### Conventions (CLAUDE.md)

Find the CLAUDE.md files that govern the changed code: the user-level
~/.claude/CLAUDE.md, the repo-root CLAUDE.md, plus any CLAUDE.md or
CLAUDE.local.md in a directory that is an ancestor of a changed file (a
directory's CLAUDE.md only applies to files at or below it). Read each one
that exists, then check the diff for clear violations of the rules they state.

Only flag a violation when you can quote the exact rule and the exact line
that breaks it — no style preferences, no vague "spirit of the doc"
inferences. In the finding, name the CLAUDE.md path and quote the rule so the
report can cite it. If no CLAUDE.md applies, return nothing for this angle.

---

## Cleanup precedence

Cleanup, altitude, and conventions candidates use the same
`file`/`line`/`summary` shape; in `failure_scenario`, state the concrete
cost (what is duplicated, wasted, harder to maintain, or which CLAUDE.md rule
is broken) instead of a crash. Correctness bugs always outrank cleanup,
altitude, and conventions findings when the output cap forces a cut.

---

## Sweep gap focus (xhigh / max / ultra only)

Before any of the below: the sweeper gets a **computed coverage table** — the
changed files no candidate has been raised against. Those come first, because a
changed file with zero candidates is usually a file nobody opened. Only then work
the list of things the first pass tends to miss.

The sweep runs **concurrently with verification** and is **sharded** across
several sweepers, each owning a disjoint slice of the uncovered files. So the
"already found" list a sweeper sees is mostly candidates *pending* a verdict, and
each sweeper is told which files its siblings own.

What the first pass tends to miss (quoted verbatim into the sweep prompt — keep
this block byte-identical to `SWEEP_GAP_FOCUS` in the workflow, no blockquote
markers):

moved/extracted code that dropped a guard
or anchor; second-tier footguns (dataclass default evaluated once, `hash()`
non-determinism, lock-scope shrink, predicate methods with side effects);
setup/teardown asymmetry in tests; config defaults flipped; pieces of the
stated intent the diff promises but never delivers.
