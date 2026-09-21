---
name: create-pr-stack
description: Create a single stacked pull request targeting its `git stack` parent as base, following Aleph conventions, with a skeleton body for the human to fill in. Use when opening one PR for a branch in a `git stack` stack.
---

# Create Pull Request

Follow these conventions when creating pull requests for Aleph repositories.

**Requires**: GitHub CLI (`gh`) authenticated and available.

## Scope

This skill works out an accurate title for the branch's changes and opens the PR with an empty skeleton body. That's it.

**Do NOT:**

- Write the PR description — the body is the unfilled skeleton below (issue line aside), and the human fills it in
- Run a code review, security review, or any review skill/subagent (e.g. `/code-review`, `/security-review`, `/simplify`)
- Run type checks, linters, formatters, builds, or tests
- Critique the code, or fix, refactor, or otherwise modify any code
- Block on, or wait for, any of the above

Those steps run separately and are not this skill's job. Read the diff only to write an accurate title, then create the PR.

## PR Title Format (CI Enforced)

```
type(scope): description (LINEAR-ISSUE)
```

- **Type**: Required (feat, fix, chore, etc.)
- **Scope**: Required (server, web-ui, ui, addin, etc.)
- **Linear Issue**: Required (CORE-1234, APPS-5678, etc.)

Multiple issues: `feat(ui): Add dashboard (APPS-1234) (APPS-567)`

## Allowed Types

| Type       | Purpose                          |
| ---------- | -------------------------------- |
| `feat`     | New feature                      |
| `fix`      | Bug fix                          |
| `refactor` | Refactoring (no behavior change) |
| `docs`     | Documentation only               |
| `test`     | Test additions or corrections    |
| `build`    | Build system or dependencies     |
| `ci`       | CI configuration                 |
| `chore`    | Maintenance tasks                |
| `revert`   | Reverting previous changes       |
| `release`  | Release-related changes          |
| `hot`      | Hotfixes                         |
| `backport` | Backporting changes              |

## Allowed Scopes (Required)

| Scope                  | Purpose                     |
| ---------------------- | --------------------------- |
| `slides`               | Google Slides add-in        |
| `addin`                | Office add-in components    |
| `workbook`             | Workbook functionality      |
| `web-ui`               | Web UI dashboard            |
| `ui`                   | Shared UI components        |
| `server`               | Node.js API server          |
| `temporal`             | Temporal workflows          |
| `workbook-automations` | Workbook automation service |
| `image-generation`     | Image generation service    |
| `deps`                 | Dependencies updates        |
| `monorepo`             | Monorepo configuration      |
| `url-service`          | URL service                 |

Multiple scopes allowed: `fix(addin, web-ui): Fix bug (CORE-1234)`

## Title Wording Rules

These govern the `description` part of the title, not the PR body.

- Use imperative, present tense: "Add feature" not "Added feature"
- Capitalize the first letter
- No period at the end
- Keep it concise and descriptive

## PR Body: Skeleton Only

Do not write a description. Open every PR with exactly this skeleton — headings and placeholders left unfilled, with one exception: the issue line is real.

```markdown
## Context

<!-- What does this PR accomplish, and why? -->

## QA

<!-- Step-by-step testing instructions: navigation paths and expected behavior -->

Loom:

Closes CORE-1234
```

Fill in the issue line with the same Linear issue(s) as the title — `Closes CORE-1234`, one line per issue, never the literal `<LINEAR-ISSUE>`. It's the line that actually moves the issue to Done (see [Issue References](#issue-references)), and it's mechanical: the ID is already in the title, so there's nothing to invent. Use `Refs`, not `Closes`, for a `-0000` placeholder.

Everything else stays untouched. Don't summarize the diff, don't guess at QA steps, don't add a Loom link — a half-written description reads as finished and ships unreviewed.

## Prerequisites

Before creating a PR, verify all changes are committed:

```bash
git status --porcelain
```

If there's output, commit or stash changes first using the `/commit` skill.

## Process

### Step 1: Verify Branch State

Before creating a PR:

- All changes are committed
- Branch is pushed to remote
- Branch is rebased on $(git stack parent) (if needed)

```bash
git status
git log $(git stack parent)..HEAD --oneline
```

### Step 2: Collect the Changes

Read the diff of every commit that will be included, purely to work out what the PR does:

```bash
git diff $(git stack parent)...HEAD
```

This is information gathering for the title only — don't evaluate the code, run checks, or make changes.

### Step 3: Create the PR

Title: accurate, per the format above. Body: the skeleton, with only the issue line filled in.

Always target the stack parent as the base branch with `--base "$(git stack parent)"`. Without an explicit `--base`, `gh pr create` targets the repository's default branch (e.g. `main`), which would break the stack.

```bash
gh pr create --draft --base "$(git stack parent)" \
  --title "fix(server): Handle null response in user endpoint (CORE-1234)" \
  --body "$(cat <<'EOF'
## Context

<!-- What does this PR accomplish, and why? -->

## QA

<!-- Step-by-step testing instructions: navigation paths and expected behavior -->

Loom:

Closes CORE-1234
EOF
)"
```

**Note:** PRs are created as drafts so humans can review before marking ready.

### Step 4: Add Reviewers

```bash
gh pr edit --add-reviewer username1,username2
```

Limit to 1-3 reviewers to maintain clear ownership.

### Step 5: Tell the User to Fill In the Description

End by saying, plainly, that the PR body is an unfilled skeleton and the user needs to edit it before marking the PR ready — filling in Context, QA, and any Loom link. The issue line is already set. Print the PR URL alongside it so they can click straight through.

## Title Examples

The body for each of these is the same skeleton, with its issue line matching the title's ID — only the title changes.

| Kind          | Title                                                                                 |
| ------------- | ------------------------------------------------------------------------------------- |
| Feature       | `feat(web-ui): Add custom label editing for chart configurations (APPS-13353)`          |
| Bug fix       | `fix(server): Handle null response in user endpoint (CORE-1234)`                        |
| Simple change | `chore(deps): Update React to v18 (APPS-0000)`                                          |
| Multi-scope   | `fix(addin, web-ui): Preserve selection across sheet switches (CORE-1234)`              |

(`-0000` is a placeholder for "no Linear issue" — there's nothing to close, so the body gets `Refs APPS-0000`, not `Closes`.)

## Issue References

The issue line is the one part of the body the skill fills in, so get it right.

Every PR that resolves an issue MUST include a `Closes <ISSUE>` line in the body. The title ID alone only _links_ the PR to the issue — it does not close it, so the merge automation never fires and the issue bounces back to In Progress instead of moving to Done.

```
Closes CORE-1234
Refs APPS-5678
```

- `Closes` (or `Fixes` / `Resolves`) - Closes the issue when the PR merges. Use this for the issue the PR resolves.
- `Refs` - Links without closing. Use only for related-but-not-closed issues.

Multiple issues resolved → one `Closes` line each.

GitHub only honors `Closes`/`Fixes`/`Resolves` keywords when the PR merges into the repository's **default branch** (e.g. `main`). For a stacked PR whose base is `$(git stack parent)`, this means:

- **Bottom of the stack** (parent is the default branch): the keyword works — the issue auto-closes on merge.
- **Mid-stack** (parent is another feature branch, i.e. a non-default base): GitHub ignores the keyword, so the issue won't auto-close on merge. It only fires once that branch is re-parented onto the default branch and merged there.

Keep the `Closes` line in the body regardless — it still links the PR to the issue, and it takes effect automatically as the stack lands on the default branch.

**Linear Prefixes:** `CORE`, `APPS`, `URG`, `PLAT`, `CHAT`, `AI`

**No issue?** Use `PREFIX-0000` (e.g., `APPS-0000`) as a placeholder when no Linear issue exists. This satisfies CI requirements while indicating no tracking issue.

## Guidelines

- **One PR per feature/fix** - Don't bundle unrelated changes
- **Keep PRs reviewable** - Smaller PRs get faster, better reviews
- **Never write the description** - Ship the skeleton unfilled every time; only the `Closes`/`Refs` issue line is set
- **Mark WIP early** - Use draft PRs for early feedback
- **Always print the PR URL** - Always print the PR URL in your final response.
- **Always say the description needs editing** - The PR isn't done until the human fills in the skeleton
