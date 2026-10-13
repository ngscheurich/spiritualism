# Server scope: host or project

Map: ../map.md
Type: grilling
Status: resolved
Blocked by:

## Question

Is a Spiritualism server scoped to one project or to the whole host? Define what a host-scoped and a project-scoped server would each own (state, sockets, config, processes), and whether a host-level UI across projects is a server concern or a client concern. The concept doc originally chose project scope; that choice was withdrawn and is open.

## Answer

**Decision: host-scoped server, provisional.** One Spiritualism server per OS user per host owns every registered project. The user chose this after weighing three options and asked to re-weigh once the rest of the map is worked. Record of the comparison: [Spiritualism Server Scope explorer](https://claude.ai/artifact/Dbz1YCV4M3YWwGCeMrVoFa) (weighted ratings, sourced per cell, with the alternatives: a server per project, and a git-like design with no daemon).

### What the server owns

- **Processes.** Every sandbox, agent session, and PTY. Sandboxes are child processes of their creator (microsandbox research finding), so the server must stay up while agents run.
- **State.** All runtime state at user level under `$XDG_STATE_HOME/spirit`: project registry, workspaces, sandboxes, agent sessions, event history. Per-project state in `.spirit/` was considered and rejected (Q18). Project directories hold configuration only; artifacts and the memory file remain fog.
- **Socket.** One, under `$XDG_RUNTIME_DIR/spirit`, falling back into the state directory when the runtime directory is unset. Socket and state paths are overridable by flag and environment variable so a development server can run alongside the real one.
- **Configuration.** The server is the sole reader of configuration: global config under `$XDG_CONFIG_HOME/spirit`, optional project config in the project directory, project values winning. Read on demand per operation, no file watching, no reload command. Clients read only what they need to find the socket.

### Lifecycle

- Any client that finds no socket starts the server. The server outlives its clients and stops only on explicit `spirit server stop` or host shutdown. A system-service unit is a later convenience.
- Client and server exchange versions on connect. A mismatch is a refusal with a hint to restart the server. No automatic restart or upgrade in v1.
- An explicit stop is refused while any agent session is active unless forced. A forced stop kills the sandboxes and marks those workspaces interrupted.

### Projects

- **A project is a registered directory.** Registration is explicit (`spirit init` in the directory, or a project command with a path); nothing is registered implicitly. The server generates the project id and keys the registry entry to the directory's resolved real path. Two clones of one repository are two projects.
- **The project config file is optional** and carries no identity. Absent, global config applies in full. Present, it overrides global values.
- **cwd resolution is the server's job.** A client sends its cwd; the server returns the id of the longest registered ancestor. Nesting is permitted and not special-cased.
- **Stale entries are kept.** A registered path that no longer exists is marked unavailable, its workspace history preserved; removal is explicit. A moved project is re-registered as a new project.

### Scope

- One server per OS user, socket in a user-private directory; never a system-wide shared server.
- Clients on another machine are out of scope for v1.
- Windows hosts are out of scope for the project; macOS is the primary target, Linux secondary. microsandbox on macOS requires Apple Silicon (research finding).
- Cross-project views: the server exposes project-qualified methods plus cross-project listings; choosing a scope is the client's concern. CLI defaults to the cwd project.

### Carried to other tickets

- Sandbox provider interface: whether sandboxes are created detached so they survive a server restart, versus server death meaning sandbox death with reconciliation on startup.
- Client-server transport and protocol: version exchange on connect; Windows named pipes need not be considered.
- Configuration schema (fog): optional project file, project overrides global, server-only reader.
- CLI command surface (fog): `spirit init`, project add/remove, `spirit server stop [--force]`, socket and state path overrides.
- Final step on the map: re-weigh server scope against the explorer once the other decisions are in.

ADR: `docs/adrs/0001-host-scoped-server.md` (status: provisional).
