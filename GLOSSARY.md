# Spiritualism

A user-configurable system in which AI coding agents perform pre-planned software development tasks in a safe, repeatable way. Terms here are normative; `docs/concept.md` is historical.

## Language

**Spiritualism**:
The system as a whole. The name evokes coding agents as apparitions operating within your computer.
_Avoid_: Spirit (that is the command name, not the system)

**Host**:
The computer system running Spiritualism.

**Server**:
The single long-lived Spiritualism process on a host, one per OS user, that owns every registered project, its workspaces, sandboxes, agent sessions, and PTYs.
_Avoid_: Daemon, backend, engine

**Client**:
A program that drives the server through its public API; the CLI and TUI are clients.
_Avoid_: Front end, UI (the TUI is one client, not the client)

**Agent**:
An AI model running in a software harness that lets it reason about its environment, use tools, and work iteratively toward a goal.

**Agent provider**:
The integration between Spiritualism and one agent harness, exposing a common interface.
_Avoid_: Harness provider

**Project**:
A directory of source code on the host that has been registered with the server. Registration is explicit; a project configuration file is optional.
_Avoid_: Repo, repository (a project may be one, but is defined by registration)

**Project registry**:
The server's record of every project it knows: identity, location, and availability.
_Avoid_: Project list, index

**Brief**:
A description of desired changes to a project: a feature, a bug fix, a refactor. Briefs are how users manage work and communicate it to agents.
_Avoid_: Ticket, issue, task

**Brief provider**:
The integration between Spiritualism and one source of briefs, exposing a common interface.

**Workspace**:
The environment in which a user and agent collaborate on one brief in the context of a project. A project has many workspaces; a workspace has exactly one brief.

**Sandbox**:
An isolated environment an agent works in without compromising the host, such as a microVM or container. Every workspace runs in a sandbox.

**Sandbox provider**:
The integration between Spiritualism and one sandbox backend, exposing a common interface.

**Artifact**:
_Undefined._ Used in the concept doc for things agents write that persist on the host and are shared within a workspace. Awaiting a decision.

**Memory file**:
_Undefined._ Used in the concept doc for the file an agent maintains so later sessions know prior work and decisions. Awaiting a decision.
