Write the full output of this review to ~/code/preview-reviews-claude/{effort-level}/.

Folders must be comparable across effort levels: identical metric definitions,
identical file names, same section order. I will diff them.

README.md - Index of every file. Headline numbers table (agents, duration, tokens, tool calls, findings, confirmed-real, line-number accuracy). One-line summary of each finding.
summary.json - Machine-readable version of the headline numbers, for cross-level diffing. Same keys in every folder, null where unavailable.
findings.md - Every finding, most-severe first, with a suggested fix for each. Re-rank if the agent's ordering contradicts its own severity reasoning, and say that you did. Second section: findings beyond this level's cap. Use the ACTUAL cap for this level, not an assumed number. If nothing overflowed, say so plainly, then list what the effort level structurally excluded instead (skipped paths with line counts, forbidden categories, skipped passes). Third section: verification. Check every finding against the real files. Mark each confirmed / false positive, correct any wrong file paths or line numbers in a table, and list the commands used.
stats.md - Tokens per request (uncached in, cache create, cache read, out) plus column totals and cache hit rate. Timing with per-event deltas and phase attribution. Tool-call counts by tool, latencies, failures, parallelism. Tools NOT used and why. Diff scope. Outcome quality: findings vs cap, confirmed rate, false positives, line-number accuracy, tokens per finding. Main-thread work counted separately from subagent cost. Label every number as reported-by-harness or derived-by-you. When they disagree, show the arithmetic and say the mapping is inferred.
agents/ 
  agent-{step-name}-{agent-name}.md - per agent. If only one agent ran, one file, and say why there was only one. If more than three, add agents/README.md indexing them. Each: verbatim prompt received; data received from other agents (say "none" explicitly); every tool call in order with exact arguments, latency, rationale, and outcome; what it found; notes it made; behavior assessment split into did-well / did-poorly / limits imposed by the prompt rather than agent failure.
misc/ - Anything else you think would be useful.
  raw/ - verbatim copies of the transcript, agent metadata, and the exact input the agent reviewed. Do not edit these. The verbatim effort-level prompt, annotated with which constraints held and which were violated. What the reviewed change does, file-by-file scope, and the risk surface this effort level did NOT examine. Source context around each finding at CORRECT line numbers. Full timeline, agent and main thread.

Rules:
- Never silently omit unavailable data. Write down that it's missing and why (empty thinking blocks, truncated token counts, unrecorded timings).
- Distinguish "the agent found nothing here" from "the agent never looked here."
- Pull from the persisted transcript, not from memory of the conversation.
- Be detailed and thorough.
