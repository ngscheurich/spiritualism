# Research: microsandbox surface

Ticket: `.tracker/v1-spec/issues/04-research-microsandbox.md`
Date researched: 2026-10-11

## Sources

All claims below cite one of these primary sources. Repo file paths refer to
the `main` branch of the source repository at commit
`18b07f2ea17557dcd0d637e9d28326fabcb1d618` (committed 2026-10-10), cloned
during this research. The docs site at https://docs.microsandbox.dev is built
from `docs/` in the same repo (the `.mdx` files there carry the same text as
the rendered pages).

- [README] `README.md`
- [Cargo] `Cargo.toml`
- [LICENSE] `LICENSE`
- [SECURITY] `SECURITY.md`
- [COMPAT] `COMPATIBILITY.md`
- [quickstart] `docs/getting-started/quickstart.mdx` = https://docs.microsandbox.dev/getting-started/quickstart
- [sb-overview] `docs/sandboxes/overview.mdx` = https://docs.microsandbox.dev/sandboxes/overview
- [lifecycle] `docs/sandboxes/lifecycle.mdx` = https://docs.microsandbox.dev/sandboxes/lifecycle
- [commands] `docs/sandboxes/commands.mdx` = https://docs.microsandbox.dev/sandboxes/commands
- [filesystem] `docs/sandboxes/filesystem.mdx` = https://docs.microsandbox.dev/sandboxes/filesystem
- [volumes] `docs/sandboxes/volumes.mdx` = https://docs.microsandbox.dev/sandboxes/volumes
- [net] `docs/networking/overview.mdx` = https://docs.microsandbox.dev/networking/overview
- [isolation] `docs/security/isolation.mdx` = https://docs.microsandbox.dev/security/isolation
- [net-sec] `docs/security/network.mdx` = https://docs.microsandbox.dev/security/network
- [sdk] `docs/sdk/overview.mdx` = https://docs.microsandbox.dev/sdk/overview
- [setup] `docs/sdk/setup.mdx` = https://docs.microsandbox.dev/sdk/setup
- [backends] `docs/operations/backends.mdx` = https://docs.microsandbox.dev/operations/backends
- [cli-sbx] `docs/cli/sandbox-commands.mdx` = https://docs.microsandbox.dev/cli/sandbox-commands
- [api] `docs/api-reference/overview.mdx` = https://docs.microsandbox.dev/api-reference/overview
- [cloud] `docs/cloud/overview.mdx` = https://docs.microsandbox.dev/cloud/overview
- [docker] `docs/how-to/docker/docker.mdx` = https://docs.microsandbox.dev/how-to/docker/docker
- [ts-linux] `docs/troubleshooting/linux.mdx`; [ts-mac] `docs/troubleshooting/macos.mdx`; [ts-win] `docs/troubleshooting/windows.mdx`
- [changelog-0.7.8] `docs/changelog/v0.7.8.mdx` = https://docs.microsandbox.dev/changelog/v0.7.8
- [proto-versioning] `crates/protocol/VERSIONING.md`
- [rust-exec] `sdk/rust/lib/sandbox/exec.rs`
- [releases] https://github.com/superradcompany/microsandbox/releases (fetched 2026-10-11)
- SDK manifests: `sdk/python/pyproject.toml`, `sdk/node-ts/package.json`, `sdk/go/go.mod`, `sdk/ruby/README.md`

## Summary

microsandbox is a local-first microVM runtime. Each sandbox is a VM with its
own Linux kernel, filesystem, and network stack, booted as a child process of
the caller; there is no daemon [sb-overview][sdk]. It is driven by the `msb`
CLI or by SDKs in TypeScript, Rust, Python, Go, and Ruby [README][sdk]. It is
Apache-2.0 licensed [LICENSE][Cargo] and self-described as beta software
[README]. Current release is v0.7.8, published 2026-10-09 [changelog-0.7.8][releases].

## Identity, maturity, license

- Repository: `github.com/superradcompany/microsandbox`. The URL
  `github.com/microsandbox/microsandbox` redirects there (observed during the
  clone; the releases page breadcrumb shows `superradcompany / microsandbox`)
  [releases].
- License: Apache License 2.0 [LICENSE]; workspace `license = "Apache-2.0"`
  [Cargo].
- Workspace version `0.7.8`, Rust edition 2024 [Cargo]. The Node package is
  also `0.7.8` [`sdk/node-ts/package.json`].
- Latest tagged release v0.7.8 dated 2026-10-09; the releases page lists ten
  releases between 2026-09-09 (v0.6.18) and 2026-10-09, none marked
  pre-release [releases][changelog-0.7.8].
- Maturity statement from the project: "Microsandbox is still **beta
  software**. Expect breaking changes, missing features, and rough edges."
  [README].
- Windows support is "currently in preview" [ts-win].
- microsandbox cloud (hosted backend) is in private beta; access is by
  request [cloud][api].
- `COMPATIBILITY.md` states that "Public SDK, CLI, and HTTP API
  compatibility is intentionally outside this map" and that the document
  covers internal protocols, durable formats, and runtime ABIs [COMPAT]. I
  read this as: the project does not currently promise public-API stability.
  (My inference; the file does not say that in those words.)
- The README describes the project as "BACKED BY Y COMBINATOR" [README].
- Security reports go to GitHub private vulnerability reporting or
  `security@superrad.company`; in-scope SDKs are listed as "Python and Node"
  [SECURITY]. The Rust, Go, and Ruby SDKs are not named in that scope list.
- Built on `libkrun` (VMM) and `smoltcp` (network stack) [README]. The guest
  kernel comes from the project's fork of `libkrunfw`, vendored at
  `vendor/libkrunfw` [setup][isolation].

## Host requirements and install

Requirements [README][quickstart]:

| Host | Requirement |
|---|---|
| Linux | KVM enabled (`/dev/kvm` readable and writable by the user); glibc 2.28+ on x64 and ARM64; musl-only hosts (bare Alpine) cannot run the local runtime [ts-linux] |
| macOS | Apple Silicon only; Intel Macs unsupported, Rosetta does not help; uses Hypervisor.framework [ts-mac][isolation] |
| Windows | Windows 10+, x64 or ARM64, Windows Hypervisor Platform (`HypervisorPlatform` feature) enabled; preview [ts-win] |

- The per-sandbox host process runs as the launching user; on Linux it needs
  `/dev/kvm` access (typically `kvm` group), no root, no setuid [isolation].
- Nested virtualization: running inside another VM, container, or CI runner
  requires the outer environment to expose `/dev/kvm` [ts-linux]. The Docker
  how-to runs `msb` from `ghcr.io/superradcompany/microsandbox:latest` with
  `--device /dev/kvm`; `--privileged` does not create a KVM device that is
  absent [docker].
- `msb doctor` checks local virtualization support [quickstart][ts-linux].

Install methods [README][quickstart][sdk]:

- CLI: `curl -fsSL https://install.microsandbox.dev | sh` (macOS/Linux);
  `irm https://install.microsandbox.dev/windows | iex` (Windows);
  `brew install superradcompany/tap/microsandbox`; `npm i -g microsandbox`;
  `uv tool install microsandbox`; `cargo install microsandbox`;
  `npx microsandbox run debian`.
- SDKs: `npm install microsandbox`; `cargo add microsandbox`;
  `pip install microsandbox` / `uv add microsandbox`;
  `go get github.com/superradcompany/microsandbox/sdk/go`;
  `gem install microsandbox`.
- Local sandboxes need two runtime files: the `msb` executable and the
  `libkrunfw` library, installed by default under `~/.microsandbox`
  (`%USERPROFILE%\.microsandbox` on Windows). SDKs expose
  `ensure_runtime` / `ensureRuntime` / `EnsureRuntime` to install them on
  first run; "Sandbox creation does not download it automatically" [setup].
  Override via `MSB_PATH`, `MSB_LIBKRUNFW_PATH`, `MSB_AGENTD_PATH` [setup].
- Language floors from manifests: Python `>=3.10`
  [`sdk/python/pyproject.toml`]; Node `>= 22` [`sdk/node-ts/package.json`];
  Go `1.22` [`sdk/go/go.mod`]; Ruby 3.3+ and, today, a Rust toolchain (1.85+)
  because platform gems are "built and validated in CI but not yet published
  to RubyGems" [`sdk/ruby/README.md`].
- Binding mechanisms: the Python SDK is a pyo3/maturin extension
  [`sdk/python/pyproject.toml`]; the Node SDK ships a napi-rs native addon via
  per-platform optional dependencies (`darwin-arm64`, `linux-arm64-gnu`,
  `linux-x64-gnu`, among others) [`sdk/node-ts/package.json`]; the Go SDK
  calls an internal FFI library [`sdk/go/agent.go`, setup].

## Backends: local vs cloud

- One CLI/SDK surface runs against the local runtime (default) or
  microsandbox cloud. Cloud is selected by `MSB_BACKEND=cloud` plus
  `MSB_API_KEY`, by an SDK call (`set_default_backend` and equivalents), or by
  a named profile in `~/.microsandbox/config.json`. `MSB_API_KEY` alone does
  not select cloud [backends].
- The cloud REST API (base `https://api.microsandbox.dev`, bearer API keys
  `msb_...`) covers sandbox lifecycle, snapshots, volumes, billing, and
  org admin. It does not cover exec, streaming, PTY, or file transfer; those go
  over the sandbox command channel via SDK or CLI only [api].
- Cloud is private beta [cloud]. A compatibility table lists local-only
  features: published ports, custom nameservers, rate limiters, TLS
  interception, `modify` (live reconfiguration), resource metrics, force
  kill, drain, ping, touch, live/full snapshots and forks [cloud].

## Creating, listing, stopping sandboxes

### CLI (`msb`)

- Create and start: `msb create <image> --name <name>` (boots immediately)
  [sb-overview][lifecycle]. `msb run <image> -- <cmd>` creates and runs a
  command; `msb run -d` creates detached [lifecycle][README].
- List: `msb ls` (flags `--running`, `--stopped`, `--label K=V`,
  `--format json`, `-q`); status: `msb ps [name] [-a] [--format json]`;
  `msb inspect <name> [--format json]` [cli-sbx].
- Stop: `msb stop <name>`; force: `msb stop --force <name>`; restart:
  `msb restart`; pause/resume: `msb pause` / `msb resume`; remove:
  `msb rm <name>`; wait: `msb wait <name> [--timeout] [--format json]`
  [lifecycle][cli-sbx].
- Config file: `msb run --conf sandbox.yaml` with `image`, `memory`,
  `network.allow`, `scripts` keys shown in the README example [README].

### SDKs

Lifecycle API is parallel across languages [lifecycle]:

| Operation | TypeScript | Rust | Python | Go | Ruby |
|---|---|---|---|---|---|
| create | `Sandbox.builder(name).image(..).create()` | `Sandbox::builder(name).image(..).create().await` | `Sandbox.create(name, image=..)` | `CreateSandbox(ctx, name, WithImage(..))` | `Microsandbox::Sandbox.create(name, image: ..)` |
| list | `Sandbox.list()` → `page.sandboxes` | `Sandbox::list().await?.sandboxes` | `await Sandbox.list()` | `ListSandboxes(ctx)` | `Microsandbox::Sandbox.list` |
| get | `Sandbox.get(name)` | `Sandbox::get(name)` | `Sandbox.get(name)` | `GetSandbox(ctx, name)` | `Microsandbox::Sandbox.get(name)` |
| stop | `sb.stop()` | `sb.stop().await` | `await sb.stop()` | `sb.Stop(ctx)` | `sb.stop` |
| start | `Sandbox.start(name)` | `Sandbox::start(name)` | `Sandbox.start(name)` | `StartSandbox(ctx, name)` | `Microsandbox::Sandbox.start(name)` |
| kill | `sb.kill()` | `sb.kill()` | `sb.kill()` | `sb.Kill(ctx)` | `sb.kill` |
| destroy / remove | `sb.destroy()`, `Sandbox.remove(name)` | same | same | `sb.Destroy(ctx)`, `RemoveSandbox` | same |

- Defaults at create: 1 vCPU, 512 MiB memory, public-only networking,
  `/bin/sh` shell; `cpus` and `memory` are limits, not reservations
  [sb-overview].
- Creating "starts it and waits until it is ready for commands" [lifecycle].
- Local SDK sandboxes stop when the application exits unless created with
  `detached(true)` / `detached=True` / `WithDetached()`; detached sandboxes
  can be reconnected by name [lifecycle].
- `connect_or_create` reuses a running sandbox, starts a stopped one, or
  creates it; concurrent callers wait on a starting sandbox rather than boot
  a second VM [lifecycle].
- `stop()` waits for graceful shutdown with no default timeout; a
  stop-with-timeout variant returns an error without force-killing
  [lifecycle].
- Lifecycle policies: `max_duration` (seconds) and `idle_timeout`
  [lifecycle].
- States: Created, Starting, Running, Paused, Draining, Stopped, Crashed
  [lifecycle]. `wait_until_stopped` and `wait_for_status` block on
  transitions; `wait_for_status` has no built-in timeout [lifecycle].
- Names: non-empty, at most 128 UTF-8 bytes; create fails on a name clash
  unless `replace()` is used [sb-overview].
- Removal deletes the sandbox record, managed writable root disk, logs, and
  staging files; it keeps cached images, named volumes, snapshots, and
  bind-mounted host files [lifecycle].

## Filesystem access

Three mechanisms, all documented in [filesystem] and [volumes]:

1. **Filesystem API over the control channel** (no mount, no network):
   `sb.fs().write/read/list/readStream/copyFromHost` and equivalents in every
   SDK; chunks of about 3 MiB for streaming. The docs recommend bind mounts
   for bulk transfer because the API moves files individually [filesystem].
   CLI: `msb copy host:path sandbox:path` in either direction, including
   sandbox-to-sandbox [cli-sbx].
2. **Bind mounts** of a host directory or single file, via virtio-fs
   [isolation][volumes]. SDK: `.volume("/guest", v => v.bind("./host").readonly().noexec())`;
   CLI: `--mount-dir ./src:/app/src:ro,noexec`, `--mount-file`. Options:
   `ro`/`rw`, `noexec`, `nosuid`, `nodev`, `stat-virt`, `host-perms`,
   `quota=<size>`, paired `uid=,gid=`. Changes are bidirectional. Relative
   host paths are resolved at create time and saved as absolute [volumes].
3. **Named volumes** (persist independently under
   `~/.microsandbox/volumes/<name>/`, directory-backed via virtio-fs or
   disk-backed raw ext4 via virtio-blk), **owned volumes** (local-only, die
   with the sandbox), **disk-image volumes** (`.qcow2`/`.raw`/`.vmdk`), and
   **tmpfs** [volumes].

Defaults in-guest are permissive: mounts are writable, executable, suid- and
dev-enabled unless flagged; workload commands run as root; the opt-in
`restricted` security profile sets `no_new_privs`, drops mount-admin, and
forces `nosuid,nodev` on user mounts but breaks `sudo` and Docker-in-Docker
[isolation][volumes].

Root filesystem: OCI image (copy-on-write overlay over cached layers), a host
directory, or a disk image; the latter two are local-only [sb-overview].

## Network policy

- All guest traffic terminates in a host-side user-space network stack; every
  packet is checked against policy; no host kernel routing or NAT in the path
  [net-sec].
- Default: egress to the public internet plus DNS via the gateway is allowed;
  private ranges (RFC 1918, CGNAT, ULA), loopback, link-local, cloud metadata
  `169.254.169.254`, and the host are denied; ingress only on published
  ports, which bind to `127.0.0.1` by default [net][net-sec].
- Disable: `.disableNetwork()` (TS), `n.enabled(false)` (Rust) remove the
  device; `Network.none()` (Python), `NetworkPolicy.None()` (Go), `--no-net`
  (CLI) keep the device but deny both directions [net].
- Profiles: `public`, `private`, `host` composable; `none` and `all` are
  whole-policy choices. CLI `--net "public,host"` [net].
- Low-level policy: `default_egress`/`default_ingress` allow|deny plus an
  ordered first-match rule list targeting groups, IPs, CIDRs, domains, and
  port ranges. CLI `--net-default-egress deny --net-rule "allow@public:tcp:443,allow@dns"`
  [net]. YAML `network.allow: [host...]` shorthand appears in the README
  example [README].
- Hostname rules: strict mode is default; hostname allowlists fail closed for
  HTTPS unless TLS interception lets the gateway see the request authority;
  opt out with `--net-strict=false` [net]. Domain rules are pinned to DNS
  answers observed from that sandbox (TOCTOU/SNI-spoof defenses) [net-sec].
- Host reachability: `host.microsandbox.internal` resolves to the host; the
  `host` group must be allowed explicitly; in-guest `localhost` is the
  guest's own loopback [net][net-sec].
- Port publishing (`-p 8080:80`, `.port(8080, 80)`), rate limits, HTTP 403
  denial responses, TLS interception with an auto-generated CA, outbound
  SOCKS proxy, and DNS controls are documented; several are local-only
  [net][cloud].
- Deployment profiles `single-tenant` (default) and `multi-tenant` (adds a
  host-side isolation floor, disables published ports and host-CA import)
  [net].

## Running processes; I/O and exit status

- Transport: a single host-driven control channel over `virtio-console`,
  spoken by `agentd`, which runs as PID 1 (root) inside the guest. The host
  sends requests (run command, read file, open TCP); the guest answers and
  streams. The guest cannot initiate requests to the host over this channel
  [isolation]. The kernel command line sets `console=hvc0
  microsandbox.agent_transport=dual-port-v1` [`crates/agentd/lib/agent.rs`
  line 5057]. On the host side, SDK and CLI connect to a per-sandbox relay
  socket (`agent.sock` under the sandbox's runtime directory) that forwards
  framed messages to agentd [proto-versioning][`crates/runtime/lib/client/maintenance.rs`].
- Wire format: `[length u32 BE][id u32 BE][flags u8][CBOR envelope {v, t, p}]`,
  4 MiB ordinary frame limit; two independently versioned protocols (agent
  and control) [proto-versioning].
- Execution works with networking disabled because it does not use the
  sandbox network [commands][quickstart].
- `exec(cmd, args)` returns exit code, stdout, stderr. Rust `ExecOutput`
  holds `status: ExitStatus { code: i32, success: bool }`, `stdout: Bytes`,
  `stderr: Bytes` [rust-exec]. Python exposes `exit_code`, `success`,
  `stdout_text`; Go `ExitCode()`, `Success()`, `Stdout()`; TS `output.code`,
  `output.stdout()`; Ruby `exit_code`, `success?`, `stdout` [commands].
- Per-exec options: `cwd`, `env`, `timeout`, `rlimit`, `user`; `shell(...)`
  runs through the configured shell [commands][cli-sbx].
- Streaming: `exec_stream` yields `Started{pid}`, `Stdout`, `Stderr`,
  `Exited{code}` events (Rust `ExecEvent`) with a session ID; stdin can be
  piped (`stdin_pipe`) and a TTY requested (`tty: true`). Ruby does not
  expose streaming, attach, or session IDs [commands][rust-exec].
- Interactive PTY attach: `attach_shell`, `attach_with`; CLI `msb exec -t`;
  `Ctrl+]` detaches without killing [commands].
- Default workload: creation is boot-only; `exec_default` /
  `execDefault` runs the image's effective `ENTRYPOINT + CMD`; plain `exec`
  ignores them [commands].
- Detached background jobs (new in v0.7.8, local-only): `msb exec -d` returns
  a job ID; `msb jobs`, `msb logs --job`, `msb attach --job`, `msb wait --job`,
  `msb signal --job`, `msb kill --job`, `msb eof --job`. Limits: 32 active jobs
  and 256 retained histories per sandbox, two 512 KiB output segments per
  job. Stopping the sandbox stops its jobs; restart does not rerun them
  [commands][changelog-0.7.8].
- CLI exit code: when `msb` runs a command inside Docker, "The command's
  output and exit code pass through both layers to the host" [docker]. I did
  not find an explicit statement that `msb exec` sets its own process exit
  status to the guest command's exit code outside that Docker example;
  unverified.
- Input backpressure: if the guest input queue is full for 60 seconds, new
  connections are refused until input drains; the sandbox keeps running
  [lifecycle].
- Logs: `msb logs` and SDK `logs()` read sandbox output after stop or crash
  [lifecycle].
- Health: `ping` (local-only) checks agentd reachability; `touch` resets the
  idle timer [lifecycle].

## Other capabilities noted (not in the ticket's question)

- Fork a running sandbox and full/disk snapshots with restore (`msb fork`,
  `msb snap create/restore`) [README][lifecycle].
- Live `modify` of cpus/memory/labels/env/secrets (local-only) [lifecycle][cloud].
- Secrets injected at the network layer by hostname so credential values
  never enter the VM [README][net].
- SSH/SFTP into sandboxes; `vsock` channels; an MCP server
  (`superradcompany/microsandbox-mcp`) and Agent Skills package [README].
- Metrics (`msb metrics`, local-only) and labels for bulk selection [cli-sbx][cloud].

## Gaps and unverified items

- GitHub API metadata (stars, open issue count, creation date) returned no
  data from this environment; the README render fetched via the web tool
  reported 8.6k stars, 472 forks, 64 open issues. Those three figures come
  from a rendered page summary, not from the repo files; treat as
  approximate and unverified against the API.
- Release dates on the releases page show day and month only; the year 2026
  is inferred from the changelog page, which says "October 9, 2026" for
  v0.7.8 [changelog-0.7.8].
- I did not run `msb` or any SDK; every behavioral claim is from docs and
  source text, not from execution.
- Whether the host process spawned per sandbox is the SDK's own process
  (via the embedded `libkrun` library) or a separate `msb` child: the docs say
  creation "spawns a VM as a child process" [sdk] and that SDKs require the
  `msb` executable [setup]; I did not trace the spawn path in source to
  confirm which binary hosts the VMM. Unverified.
- Performance figure: README claims "average boot times under 100
  milliseconds", footnoted as guest boot on an M1 machine [README]. Not
  independently verified.
