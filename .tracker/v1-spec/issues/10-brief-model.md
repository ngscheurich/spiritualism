# Brief model and provider interface

Map: ../map.md
Type: grilling
Status: open
Blocked by: 02

## Question

What is a brief's lifecycle and status set? Define the statuses the dashboard's kanban columns reflect, the filesystem brief format for the initial provider, how a brief is assigned to a workspace, and the brief provider interface (list, filter, update, workspace naming).

## Context

Carried from [Workflow model: brief to pull request](02-workflow-model.md): a workflow has a stage (Plan, Build, Review, Ship, Done) and a status (running, waiting, stopped, abandoned); the kanban columns can draw on both. A human starts each workflow explicitly. An abandoned workflow keeps its workspace as history and frees its brief for a new workspace, so "a brief is assigned to at most one workspace" needs restating as a rule about active workspaces.
