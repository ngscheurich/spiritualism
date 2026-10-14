# Tech stack for server and clients

Map: ../map.md
Type: grilling
Status: resolved
Blocked by: 05, 06, 07

## Question

Which language and runtime does the server use, and which do the CLI and TUI use? The two may differ. Weigh options equally against: embedding or driving the chosen agent harnesses, the chosen IPC transport, TUI library maturity and accessibility, and distribution to users.

## Answer

**Decision: a split stack. The server is Elixir; the client is Go.** ADR: `docs/adrs/0003-elixir-server-go-client.md`. No `GLOSSARY.md` change: no domain term moved.

### Server

- Elixir on the Erlang VM. Reasons: the user's fluency in Elixir is high, and the process model fits a server that owns many long-lived external processes.
- Conditional on [Task: run microsandbox on a host](13-try-microsandbox.md) confirming PTY attach and child-process cleanup on a real machine.
- The server drives both agent harnesses as processes inside the sandbox over stdio JSONL (`pi --mode rpc`, `claude -p --output-format stream-json`). In-process SDK embedding counted for nothing: an agent inside a sandbox cannot be embedded in a host process (inference).
- microsandbox has no Elixir SDK. Two routes stay live and [Sandbox provider interface](08-sandbox-provider-interface.md) picks between them: (a) spawn `msb` through erlexec; (d) a purpose-built Go helper that wraps the microsandbox Go SDK and talks to the server, possibly inside the `spirit` executable. Set aside: (b) a native extension over the Rust SDK, because a crashing native function takes down the VM; (c) a hand-written client for the relay-socket protocol.
- How the server ships (Mix release or Burrito) is not decided; the server runs undistributed during development.

### Client

- One `spirit` executable holding the CLI and the TUI, in Go.
- Bubble Tea v2 (`charm.land/bubbletea/v2`) with Lip Gloss v2 and Bubbles v2, provisional until the TUI prototype. `cobra` for command parsing.
- PTY attach requires handover only: the TUI suspends, gives the whole terminal to the PTY, and returns on a detach key. An embedded terminal pane is a bonus, not a requirement.
- Passed over: TypeScript (moderate fluency; Ink documents screen-reader support), Rust, Python, Elixir.

### Criteria the user set

- Fluency: high in Elixir, moderate in TypeScript, low in Go, Rust, and Python. Fluency is weighted and can outweigh a technical disadvantage, depending on severity.
- Disqualifiers, the only bars fluency cannot clear. Server: no PTY attach and relay through a maintained library or documented `msb` command; orphaned child processes with no documented remedy. Client: no TUI library with a release in the past twelve months.
- A runtime prerequisite on the user's machine is acceptable.
- One language for both roles was preferred in principle. It was rejected in practice: the user does not want to build a TUI in Elixir, and chose Go for Bubble Tea's track record and to learn Go.
- Minimum versions of Elixir, Erlang/OTP, and Go are left to implementation.

### Findings the decision rests on

Two research agents read docs, registries, and source on 2026-10-13. Nothing was executed. The findings were not saved to a branch; this section is the record.

Elixir, server role:
- erlexec 2.5.0 (2026-09-17, BSD-2-Clause) lists PTY support, `exec:winsz` for resize, signals, stdin EOF, and macOS. Its README says it "performs proper OS child process cleanup when the emulator exits" and calls itself stable. In PTY mode stdout and stderr cannot be separated.
- Plain Erlang Ports have no PTY, and the Elixir docs say a port program "won't be automatically terminated" when the VM crashes.
- No microsandbox package exists on hex.pm. Condukt (Tuist) wraps the Rust SDK in a private Rustler extension pinned to microsandbox 0.4.6 against a current 0.7.8; its source comments record two segfaults; it exposes exec and file calls, and no PTY or streaming function was seen.
- The Erlang docs: "A native function that crashes will crash the whole VM."
- microsandbox's `crates/protocol/VERSIONING.md` calls the relay frame "the stable wire header" with versioned generations; payload fields are not fully frozen; no statement supports third-party clients.
- `gen_tcp` accepts `{local, path}` Unix sockets. Bandit, Plug.Cowboy, and elixir-grpc each document a Unix-socket listener. No current general-purpose JSON-RPC library was found; the latest `jsonrpc2` release is 2020-06-19. Peer credentials have no documented first-class path.
- Burrito 1.6.0 (2026-07-24) builds one self-extracting file for macOS and Linux, calls its approach "still experimental", and needs a Gatekeeper exemption or code-signing on macOS. Mix releases bundle the runtime and are built per target. The Mix docs say escripts are not "a deployment mechanism".
- No current start-up figure for the Erlang VM, an escript, or Burrito was found in any source.

Client libraries (version, latest release):
- Bubble Tea 2.1.0, 2026-10-08, MIT; v2.0.0 tagged 2026-02-24; "in use in production". No screen-reader text in the repo; the forms library `huh` has `WithAccessible(true)`. No first-party terminal widget; third-party bubbleterm 0.3.5 over Charm's `x/vt`, which promises no backward compatibility.
- Ink 8.0.0, 2026-10-03: README states "basic support for screen readers" with ARIA props; names only Node; no mouse API or terminal widget found.
- OpenTUI 0.6.4, 2026-10-13, pre-1.0: first-party embedded terminal in the core API only; runs on Bun, or Node 26.4.0+ behind `--experimental-ffi`; screen-reader support is a roadmap item.
- Ratatui 0.30.2, 2026-06-19, pre-1.0: third-party tui-term 0.3.4, self-described work in progress; an open accessibility issue the maintainer cannot prioritise.
- Textual 8.2.8, 2026-06-30: third-party textual-terminal last released 2023-01-29; screen-reader integration is an unchecked roadmap item.
- Elixir: ExRatatui 0.17.1 (2026-10-12, first release 2026-02-19), TermUI 2.0.0-rc.2, Breeze 0.5.5 are active; Ratatouille's last release was 2020-03-25. No README mentions accessibility.

### Unverified

- erlexec PTY and resize behaviour on macOS; whether `msb exec -t` relays correctly under an erlexec PTY; whether a microVM started through `msb` dies with the server.
- Route (d): that a helper exiting on stdin close removes the orphan problem, and that the Go SDK's FFI dependency forces native linking into the `spirit` build. Both are inferences.
- Start-up cost of any candidate.
- How strict the Mix release rule on matching the build machine's OS distribution is in practice.
