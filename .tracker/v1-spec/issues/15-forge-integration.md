# Forge integration: observing pull requests

Map: ../map.md
Type: grilling
Status: open
Blocked by: 11

## Question

How does the server learn the state of a workflow's pull request, and which forges does v1 support? Decide: the mechanism for observing merged, closed without merging, and changes requested (polling, webhooks, or a client command that asks); how often and at what cost; how the server authenticates to the forge; whether forges sit behind a provider interface like sandboxes, agents, and briefs; and what the workflow does when the forge is unreachable.

## Context

Surfaced by [Workflow model: brief to pull request](02-workflow-model.md): the workflow ends at merge, a pull request closed without merging abandons the workflow, and the server pushes and opens or updates the pull request on a human publish command. [Workspace and git model](11-workspace-git-model.md) decides the push and pull request creation mechanics; this ticket decides the observation side and forge scope. Forge credentials overlap with [Safety model beyond the sandbox](12-safety-model.md).
