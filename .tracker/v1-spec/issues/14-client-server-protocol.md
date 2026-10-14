# Client-server transport and protocol

Map: ../map.md
Type: grilling
Status: open
Blocked by: 03, 07

## Question

Which transport and protocol do clients and the server use? JSON-RPC 2.0 over a Unix socket was the concept doc's proposal and is open. Decide the transport, the message protocol, how the live event stream is delivered, and how a client attaches to a PTY.

## Context

Resolved upstream: [Server scope: host or project](01-server-scope.md) chose one host-scoped server per OS user, so a client talks to exactly one server. Carried here: client and server exchange versions on connect and a mismatch is a refusal; Windows hosts are out of scope, so named pipes need not be considered; socket path is overridable by flag and environment variable.

Carried from [Tech stack for server and clients](03-tech-stack.md): the endpoints are an Elixir server and a Go client, so no protocol types are shared by language; a schema both sides generate from is worth weighing. Elixir facts from that ticket's research (docs only, nothing run): `gen_tcp` accepts `{local, path}` Unix sockets; Bandit, Plug.Cowboy, and elixir-grpc each document a Unix-socket listener; no current general-purpose JSON-RPC library was found (latest `jsonrpc2` release 2020-06-19); peer credentials have no documented first-class path. PTY attach in the TUI requires handover only (the TUI suspends and gives the terminal to the PTY), so the protocol must carry raw PTY bytes and resize, not feed an embedded widget.
