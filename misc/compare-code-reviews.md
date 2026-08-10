I built my code-review-low skill to be as much like the built in claude code code-review command as possible. I ran both and asked each to take notes of everything they did. The notes are this format:

In each of the following folders is a detailed description of how the agentic code review went. It's process, it's findings, etc. This review was of the changes in the branch `colton/preview-environments` compared against `b1` in the repo `/Users/colton/code/monorepo`. Below is a description of the folder structure describing the review:

README.md - Index of every file. Headline numbers table (agents, duration, tokens, tool calls, findings, confirmed-real, line-number accuracy). One-line summary of each finding.
summary.json - Machine-readable version of the headline numbers, for cross-level diffing. Same keys in every folder, null where unavailable.
findings.md - Every finding, most-severe first, with a suggested fix for each. Re-rank if the agent's ordering contradicts its own severity reasoning, and say that you did. Second section: findings beyond this level's cap. Use the ACTUAL cap for this level, not an assumed number. If nothing overflowed, say so plainly, then list what the effort level structurally excluded instead (skipped paths with line counts, forbidden categories, skipped passes). Third section: verification. Check every finding against the real files. Mark each confirmed / false positive, correct any wrong file paths or line numbers in a table, and list the commands used.
stats.md - Tokens per request (uncached in, cache create, cache read, out) plus column totals and cache hit rate. Timing with per-event deltas and phase attribution. Tool-call counts by tool, latencies, failures, parallelism. Tools NOT used and why. Diff scope. Outcome quality: findings vs cap, confirmed rate, false positives, line-number accuracy, tokens per finding. Main-thread work counted separately from subagent cost. Label every number as reported-by-harness or derived-by-you. When they disagree, show the arithmetic and say the mapping is inferred.
agents/ 
  agent-{step-name}-{agent-name}.md - per agent. If only one agent ran, one file, and say why there was only one. If more than three, add agents/README.md indexing them. Each: verbatim prompt received; data received from other agents (say "none" explicitly); every tool call in order with exact arguments, latency, rationale, and outcome; what it found; notes it made; behavior assessment split into did-well / did-poorly / limits imposed by the prompt rather than agent failure.
misc/ - Anything else you think would be useful.
  raw/ - verbatim copies of the transcript, agent metadata, and the exact input the agent reviewed. Do not edit these. The verbatim effort-level prompt, annotated with which constraints held and which were violated. What the reviewed change does, file-by-file scope, and the risk surface this effort level did NOT examine. Source context around each finding at CORRECT line numbers. Full timeline, agent and main thread.

Those notes are in:
1. /Users/colton/code/preview-reviews-claude/low for the built in claude review
2. /Users/colton/code/preview-reviews-opencode/low for my custom built code-review-low skill

I want you to deeply compare the two, the findings they made and the process they took to see how good of an emulation of the built in code-review skill mine is, how it compares in terms of output, performance, token use, and evaluate any gaps.

My skill is is located at /Users/colton/.config/home-manager/agent-nonclaude-shared/skills/code-review-low/SKILL.md 

Tell me how you would iterate on my skill based on the comparison.
