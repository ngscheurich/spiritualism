# Agent provider interface

Map: ../map.md
Type: grilling
Status: open
Blocked by: 02, 05, 06

## Question

What is the common interface every agent provider implements? Define start, stop, structured output, session persistence, and how an agent is pointed at a workspace and a brief. Resolve the concept doc's open question: does the built-in Pi agent use the same interface as Claude Code, or is it a special case?

## Context

Related: [Sandbox provider interface](08-sandbox-provider-interface.md) decides how the agent process runs inside the sandbox; this ticket decides the contract above it.

Carried from [Workflow model: brief to pull request](02-workflow-model.md): four stages run agents (Plan, Build, Review, Ship) and each starts a fresh session, possibly with a different provider per stage; Artifacts are the only handoff. Decide here: whether re-entering Build after a failed check or a "changes needed" verdict resumes the earlier Build session; whether a restart after a server crash resumes or starts over; how an agent raises an attention request; and how the Review agent returns its structured verdict (pass or changes needed).
