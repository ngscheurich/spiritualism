# Task: run microsandbox on a host

Map: ../map.md
Type: task
Status: open
Blocked by: 04

## Question

Install microsandbox on a real host and the project's dev container (its install line is commented out in the Dockerfile), create and stop one sandbox, and run a process inside it. Record what worked, what failed, and the host requirements observed. Unblocks the sandbox provider interface decision with facts rather than docs.

## Context

Carried from [Tech stack for server and clients](03-tech-stack.md): the server is Elixir, conditional on this task. Try both routes to microsandbox and record what each does. Route (a): spawn `msb` under an erlexec PTY; confirm `msb exec -t` relays bytes and a resize (`exec:winsz`) on macOS and Linux. Route (d): a minimal Go program on the microsandbox Go SDK that execs a streaming process and attaches a PTY; record whether the build links native code. For both: kill the server process abruptly and record whether the sandbox and its children die or are orphaned.
