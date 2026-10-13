---
status: provisional
---

# One host-scoped server per OS user

Spiritualism needs a process that stays alive with no client open, so deterministic workflow steps run outside the agent's reach and sandboxes, which are child processes of their creator under microsandbox, keep running. We chose a single host-scoped server per OS user over a server per project and over a git-like design with no daemon. The server owns all runtime state at user level and every sandbox, agent session, and PTY; projects are explicitly registered directories.

## Considered options

- **Server per project**: removes the project registry and gives per-project failure domains and git-like state locality, but cross-project views need discovery and client fan-out, and host-wide limits have no single enforcer.
- **Git-like, no daemon**: removes transport, lifecycle, and registry entirely, but leaves no host process to run workflow steps after the agent exits; the orchestrator would live inside the sandbox the agent controls, or wait for a human.

## Status

Provisional. The user asked to re-weigh the three options once the rest of the v1 spec map is worked. Comparison record: https://claude.ai/artifact/Dbz1YCV4M3YWwGCeMrVoFa
