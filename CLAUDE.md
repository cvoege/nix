# Nix Home

This is my nix home manager setup. My primary config is in @home.nix.,

## git-stack (git stack)

This is a set of utilities for managing stacks of git PRs. See `git stack help` and @bin/git-stack for more info.

## cw

This is a set of utilities for quickly starting up git worktrees to do work in parallel, usually with an AI agent.

## cnotify

This is a quick tool for sending a desktop notification, primarily on macs.

# Tests 

This repo has tests, which can be run with `just test`. Currently there are only tests for `cw` and `git-stack`, it should stay that way. All tests should pass for whatever you are working on before you call it complete. New features to `cw` and `git-stack` should have tests.
