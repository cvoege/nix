---
name: collapse-pr-stack
description: Collapse a git branch stack into a single PR. Use when asked to collapse a stack of pull requests into a single one.
---

# Collapse a stack of git to a single PR

**Requires**: `gh` authenticated, and the stack's parent pointers recorded (via
`git stack new` / `git stack parent`). The `git stack` utilities
must be on PATH.

If any command in this series errors, or requires user intervention, pass control back to the user.

## Process

1. Run this command to get an overview of the current stack and all the PRs attached:

  ```bash 
  git stack prs list
  ```
  
  Take special note of every linear ticket (e.g. ACT-323) of every PR in the stack. In the end, when we create a final PR with everything, we will want to include each one in both the title and the description.

2. Run the following command to ensure the entire stack is up to date and ready to be fast forwarded. If this command errors, stop and tell the user.
  
  ```bash
  git stack restack
  ```

3. Run the following to collapse the stack into a single branch. It will handle merging all the changes into the closest branch to the main/trunk branch. If this command errors, stop and tell the user.


  ```bash
  git stack collapse
  ```

4. We should now be on the single collapsed branch. It should already have a PR on Github, but we need to update that PR now that it has all the changes. Run the create-pr-stack-single skill to create a PR, or update the existing PR with all the new changes. Make sure the description and title are updated to encompass the full changeset. Remove the draft status from the PR.
