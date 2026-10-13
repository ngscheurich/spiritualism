# Spiritualism v1 spec

Labels: wayfinder:map

## Destination

A v1 spec for Spiritualism: architecture decisions locked, provider interfaces and the server's public API shaped, tech stacks chosen, ready to hand to `/to-spec` and `/to-tickets` for implementation.

## Notes

- `docs/concept.md` is historical and never edited. `GLOSSARY.md` and `docs/adrs/` are normative.
- Planning only: tickets produce decisions, not code. Task tickets may do work only to unblock a decision.
- Consult the `grilling` and `domain-modeling` skills on every ticket. Update `GLOSSARY.md` the moment a term is resolved.
- Weigh every stack, transport, and backend option equally; no option is pre-chosen.
- Communicate per `AGENTS.md`: wire-reporter style, inferences marked, no invented specifics.
- Tickets live at `.tracker/v1-spec/issues/`. Refer to them by title in prose.

## Decisions so far

<!-- one line per resolved ticket: [title](issues/NN-slug.md): gist -->
- [Server scope: host or project](issues/01-server-scope.md): host-scoped, one server per OS user, provisional pending a re-weigh at the end of the map; owns all processes and user-level state; projects are explicitly registered directories with optional config; explicit stop guarded while agents run; comparison page linked from the ticket.
- [Workflow model: brief to pull request](issues/02-workflow-model.md): fixed sequence Plan → Build → Review → Ship → Done, one run per workspace, ends at merge; a gate on every transition holds automated checks (run in the sandbox) and an optional per-project human approval; only Review→Build and Ship→Build go backward; the server touches the forge only on a human command; human can stop, retry, send back, abandon, publish, and force past.
- [Research: microsandbox surface](issues/04-research-microsandbox.md): daemonless microVM runtime, sandboxes are child processes of the caller; CLI plus TS/Rust/Python/Go/Ruby SDKs; needs KVM, Apple Silicon, or Windows Hypervisor Platform; exec streaming and PTY attach; Apache-2.0, self-described beta.
- [Research: Pi agent surface](issues/05-research-pi.md): Node harness with TypeScript-only SDK; headless print/JSON/RPC modes over stdio JSONL; JSONL sessions grouped by cwd; no built-in permission system; MIT.
- [Research: Claude Code integration surface](issues/06-research-claude-code.md): `claude -p` with json/stream-json over stdio; TS and Python Agent SDK supervise the CLI as a subprocess; JSONL sessions keyed by cwd; sandbox off by default.
- [Research: client-server IPC options](issues/07-research-ipc-options.md): survey, no pick: JSON-RPC lacks framing and binary, gRPC is Unix-socket-only off Windows, WebSocket carries PTY bytes; Node `net` covers Unix sockets and Windows pipes in one API.

## Not yet specified

- Revisit Ship: whether publishing stays a human command or gains an automatic setting; the user accepted the current shape provisionally. Same for automatic rebuild when a pull request has changes requested.
- Re-weigh server scope (host-level vs per-project vs git-like) against the explorer linked from [Server scope: host or project](issues/01-server-scope.md) once the other decisions are in. Last step before the destination.
- Artifacts and memory file: what they are, where they live, who reads and writes them. Three Artifacts are known from [Workflow model: brief to pull request](issues/02-workflow-model.md): the plan, the review findings, and the pull request description; humans edit the first and last.
- Public API: the method and event surface the server exposes, including the live event stream, the workflow commands (start, stop, retry, send back, abandon, publish, force past), gate approvals, and the workflow event history.
- Configuration schema: global and project levels (project file optional, project values win, server is the only reader), how providers are configured and selected. Workflow settings: per-gate human approvals and their defaults, check commands per gate, attempt and round limits, agent provider per stage.
- CLI command surface, including `spirit init`, project add/remove, `spirit server stop [--force]`, socket and state path overrides.
- TUI layout and interaction (likely a prototype ticket once the brief model and API exist).
- Accessibility requirements for the TUI.
- Direct agent-to-user interaction: PTY attach and how it coexists with the workflow, including how a human answers an attention request.

## Out of scope

- Windows hosts. macOS is the primary target; Linux rides along. (Decided while resolving [Server scope: host or project](issues/01-server-scope.md).)
- Web and GUI clients.
- Third-party brief providers (Shortcut, Linear, GitHub Issues).
- Sandbox backends other than microsandbox.
- Agent harnesses other than Pi and Claude Code.
