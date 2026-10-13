# Client-server transport and protocol

Map: ../map.md
Type: grilling
Status: open
Blocked by: 03, 07

## Question

Which transport and protocol do clients and the server use? JSON-RPC 2.0 over a Unix socket was the concept doc's proposal and is open. Decide the transport, the message protocol, how the live event stream is delivered, and how a client attaches to a PTY.

## Context

Resolved upstream: [Server scope: host or project](01-server-scope.md) chose one host-scoped server per OS user, so a client talks to exactly one server. Carried here: client and server exchange versions on connect and a mismatch is a refusal; Windows hosts are out of scope, so named pipes need not be considered; socket path is overridable by flag and environment variable.
