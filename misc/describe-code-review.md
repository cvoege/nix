Write as much output as you can from this review (including output from the individual agents, organized in folders) to a folder in `~/code/preview-reviews-claude` named after the effort level of the review (e.g. `~/code/preview-reviews-claude/max`).

Here's what I want you to write down, in a folder structure:

findings.md - All the findings, in an easy to read list. Inlcude findings outside the 15 finding limit in a second section. Include the summary of a suggested fix for each finding.
stats.md - Detailed stats on the run. Tokens used (input, output, cached, etc). Time stats, user time, total time across all agents. Tool call statistics. Anything else you can think of.
agents/
  agent-{step-name}-{agent-name}.md - Write one of these for every agent that runs. Be very detailed. Have a section for the original prompt the agent was given, what data it receieved from other agents, what tools it called, what it found, any notes it made, and anything else that might be good to know.
misc/ - Store anything else you think would be useful.

Be detailed and thorough.
