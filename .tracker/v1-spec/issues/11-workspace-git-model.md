# Workspace and git model

Map: ../map.md
Type: grilling
Status: open
Blocked by: 02, 08

## Question

How does a workspace map onto git? Decide: branch or worktree per workspace; how the project's source gets into the sandbox and how commits get back out; how a pull request is created and by whom; what happens to the workspace when the brief is done.

## Context

Carried from [Workflow model: brief to pull request](02-workflow-model.md): "how a pull request is created and by whom" is partly settled. The server pushes the branch and opens the pull request only on a human publish command, taking title and body from the pull request description Artifact, and updates the existing pull request after a Ship→Build kickback. A human always merges on the forge. Still open here: the push mechanics and credentials path, and what happens to the workspace and its branch on Done and on abandonment. Observation of pull request state belongs to [Forge integration: observing pull requests](15-forge-integration.md).
