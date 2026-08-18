---
name: create-pr-stack
description: Create a single stacked pull request targeting its `git stack` parent as base, following Aleph conventions. Use when opening one PR for a branch in a `git stack` stack or writing its description.
---

# Create Pull Request

Follow these conventions when creating pull requests for Aleph repositories.

**Requires**: GitHub CLI (`gh`) authenticated and available.

## Scope

This skill only gathers information about the branch's changes and opens the PR. That's it.

**Do NOT:**

- Run a code review, security review, or any review skill/subagent (e.g. `/code-review`, `/security-review`, `/simplify`)
- Run type checks, linters, formatters, builds, or tests
- Critique the code, or fix, refactor, or otherwise modify any code
- Block on, or wait for, any of the above

Those steps run separately and are not this skill's job. Read the diff only to write an accurate title and description, then create the PR.

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

## Description Rules

- Use imperative, present tense: "Add feature" not "Added feature"
- Capitalize the first letter
- No period at the end
- Keep it concise and descriptive

## PR Description Structure

The `Closes` line — not the title ID — is what moves the issue to Done on merge. The title ID alone only links the PR.

```markdown
## Context

Brief explanation of what the PR accomplishes and why.

## QA

1. Step-by-step testing instructions
2. Include specific navigation paths
3. Describe expected behavior

Loom:

Closes <LINEAR-ISSUE>
```

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

Read the diff of every commit that will be included, purely to understand what the PR does:

```bash
git diff $(git stack parent)...HEAD
```

This is information gathering for the description only — don't evaluate the code, run checks, or make changes.

### Step 3: Write the Description

**Do include:**

- Clear explanation of what and why
- Links to relevant Linear issues
- Context that isn't obvious from the code
- Loom recordings for UI changes

**Do NOT include:**

- Redundant summaries of the diff
- Generic testing instructions

### Step 4: Create the PR

Always target the stack parent as the base branch with `--base "$(git stack parent)"`. Without an explicit `--base`, `gh pr create` targets the repository's default branch (e.g. `main`), which would break the stack.

```bash
gh pr create --draft --base "$(git stack parent)" --title "type(scope): description (LINEAR-ISSUE)" --body "..."
```

**Note:** PRs are created as drafts so humans can review before marking ready.

### Step 5: Add Reviewers

```bash
gh pr edit --add-reviewer username1,username2
```

Limit to 1-3 reviewers to maintain clear ownership.

## Examples

### Feature PR

**Title:** `feat(web-ui): Add custom label editing for chart configurations (APPS-13353)`

```markdown
## Context

Adds ability to customize display labels for charts. In some cases, the
label names from the data source are not the ones we want to display.

Changes:

- New EditableLabel component with popover UI
- Support for rowAliases in bar/line/waterfall charts
- Labels preserved when switching between chart types

## QA

1. Navigate to any dashboard with a chart
2. Click on a series label in the legend
3. Edit the label text
4. Verify label updates in legend, tooltip, and axes

Loom:

Closes APPS-13353
```

### Bug Fix PR

**Title:** `fix(server): Handle null response in user endpoint (CORE-1234)`

```markdown
## Context

The user API could return null for deleted accounts, causing a crash
in the dashboard. Add null check before accessing user properties.

## QA

1. Create a test user
2. Delete the user via admin
3. Attempt to load dashboard that references deleted user
4. Verify no crash occurs and appropriate fallback is shown

Loom:

Closes CORE-1234
```

### Simple Change PR

**Title:** `chore(deps): Update React to v18 (APPS-0000)`

```markdown
## Context

Updates React from v17 to v18 for performance improvements and
new concurrent features.

## QA

1. Run the test suite: `pnpm run test`
2. Start the app: `pnpm dev web-ui`
3. Navigate through main flows and verify no regressions

Loom:

Refs APPS-0000
```

(`-0000` is a placeholder for "no Linear issue" — there's nothing to close, so use `Refs`, not `Closes`.)

## Issue References

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
- **Explain the why** - Code shows what; description explains why
- **Mark WIP early** - Use draft PRs for early feedback
- **Include Loom** - Record UI changes for easier review
- **Always print the PR URL** - Always pring the PR URL in your final response.
