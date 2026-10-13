# Sandbox provider interface

Map: ../map.md
Type: grilling
Status: open
Blocked by: 04, 13

## Question

What is the common interface every sandbox provider implements? Define lifecycle operations, how project source enters the sandbox and changes leave it, what filesystem and network controls the interface exposes, and how an agent process runs inside and reports back.

Also decide, carried from [Server scope: host or project](01-server-scope.md): are sandboxes created detached so they survive a server restart and are reconnected by name on startup, or does server death mean sandbox death, with the server reconciling against the backend's sandbox list when it starts? The microsandbox findings state local sandboxes die with their creating process unless created detached.

## Context

Carried from [Workflow model: brief to pull request](02-workflow-model.md): the server runs each gate's automated checks (the project's configured commands) inside the workspace's sandbox and reads the exit status, with no agent involved. After an unexpected server death the server restarts each running stage on startup, so the sandbox must either survive the crash or be rebuilt.
