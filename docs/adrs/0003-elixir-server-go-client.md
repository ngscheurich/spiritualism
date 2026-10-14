---
status: accepted
---

# An Elixir server and a Go client

Spiritualism's server and its client executable use different languages. The server is Elixir on the Erlang VM; the `spirit` executable, which holds both the CLI and the TUI, is Go with Bubble Tea v2. We accepted a second toolchain and two sets of protocol types because no one language suited both roles for the project's single maintainer.

The server's job is owning many long-lived external processes: sandboxes, agent sessions, PTY relays, client connections, and one workflow run per workspace. Elixir gives each an owning process, contains a failure to the workspace it happened in, and declares restart policy in supervisors. The maintainer's fluency in Elixir is high, and fluency was a weighted criterion that could outweigh a technical disadvantage short of a disqualifier. Go was chosen for the client because Bubble Tea is in production use, Go compiles to a native executable that starts without a runtime, and the maintainer wants to build the TUI in it.

Two things here are deliberate and easy to mistake for oversights.

**The server holds no native code.** microsandbox has no Elixir SDK. Wrapping its Rust SDK in a native extension was set aside because a crashing native function takes down the whole VM, supervision included. The server reaches microsandbox through a separate OS process: either the `msb` command or a purpose-built Go helper over the microsandbox Go SDK.

**The BEAM does not protect the sandboxes.** Sandboxes are OS processes. Supervision restarts the Elixir process that owns one, not the microVM's state, and cleanup of orphaned OS processes comes from a helper program, not from the VM.

## Considered options

- **Elixir for both roles**: one toolchain and shared protocol types. Rejected: the active Elixir TUI libraries are under a year old, every `spirit` command would boot the Erlang VM, and the maintainer does not want to build a TUI in Elixir.
- **TypeScript client**: the maintainer's fluency is moderate, higher than in Go, and Ink is the one surveyed full-screen library that documents screen-reader support. Passed over for Bubble Tea's maturity and the maintainer's wish to learn Go.
- **Rust or Python client**: low fluency in both. Ratatui is pre-1.0; Python's terminal widget is unmaintained and needs an interpreter on the user's machine.
- **Go, Rust, TypeScript, or Python server**: each has a microsandbox SDK, which Elixir lacks. Rejected on fluency and the process model's fit.

## Consequences

- The server's choice is conditional on a real-machine test confirming PTY attach and child-process cleanup; both rest on documentation nobody on the project has run.
- Bubble Tea documents no screen-reader support. Accessibility requirements are unwritten, so this is an open risk, and the TUI library is provisional until the TUI prototype.
- The client-server protocol has an Elixir endpoint and a Go endpoint, so a protocol with definitions both can share is worth more than it would be in a single-language stack.
- Server and client ship as two artifacts that must reach a user as one install. How is undecided.
