# Research: Pi agent surface

Ticket: `.tracker/v1-spec/issues/05-research-pi.md`
Researched: 2026-10-11
Sources: pi.dev (fetched 2026-10-11), the `earendil-works/pi` repository at commit `78a3c10ba7f99a12015d6100be264c847abdba53` (main, dated 2026-10-11), the npm registry, and the GitHub REST API. Source paths below are relative to the repository root at that commit. Nothing here was run; all claims come from reading docs and source.

## Identity: which project "pi.dev" is

- pi.dev is the site for **Pi**, described there as "a minimal agent harness", built by "Earendil Inc. & Contributors". The site links to `https://github.com/earendil-works/pi` and npm package `@earendil-works/pi-coding-agent`. [pi.dev front page]
- The repository `earendil-works/pi` describes itself as "AI agent toolkit: unified LLM API, agent loop, TUI, coding agent CLI". GitHub reports `created_at` 2025-08-09, license `MIT`, default branch `main`, not archived. [GitHub API `/repos/earendil-works/pi`, 2026-10-11]
- `LICENSE` is the MIT License with copyright "2025 Mario Zechner". The coding-agent `package.json` lists `"author": "Mario Zechner"`. [`LICENSE`; `packages/coding-agent/package.json`]
- The former npm package `@mariozechner/pi-coding-agent` (latest 0.73.1) is marked deprecated with the message "please use @earendil-works/pi-coding-agent instead going forward". [npm registry, 2026-10-11]
- Inferred, not stated by any single source: Pi started as Mario Zechner's `pi-mono` and moved under the Earendil organization. The root README still refers to "my `pi-mono` work sessions", and the Earendil "Pi 1.0" post does not mention pi-mono. [`README.md` ("Share your OSS coding agent sessions"); earendil.com/posts/pi-1-0/]

## Install and run

- Install: `curl -fsSL https://pi.dev/install.sh | sh` (macOS/Linux), `powershell -c "irm https://pi.dev/install.ps1 | iex"` (Windows), or `npm install -g --ignore-scripts @earendil-works/pi-coding-agent`. The installer "pins all dependencies"; the npm install "does not pin transitive dependencies". [`README.md`]
- Nix: `nix run github:earendil-works/pi/stable`; `nix profile add github:earendil-works/pi/stable`. [`README.md`]
- Runtime requirement: Node.js 22.19 or newer (`"engines": {"node": ">=22.19.0"}`). [`README.md`; `packages/coding-agent/package.json`]
- Binary name is `pi` (`"bin": {"pi": "dist/bundle/cli.js"}`). Standalone binaries are built with `bun build --compile` (`build:binary` script). [`packages/coding-agent/package.json`]
- Run: `cd /path/to/project && pi`. The working directory "controls project configuration, resource discovery, and session grouping". [`README.md`; `docs/cli.md`]
- Docker example in the official docs: `FROM node:24-bookworm-slim`, `npm install -g --ignore-scripts @earendil-works/pi-coding-agent`, `ENTRYPOINT ["pi"]`, run with `-e ANTHROPIC_API_KEY -v "$PWD:/workspace" -v pi-agent-home:/root/.pi/agent`. [`packages/coding-agent/docs/containerization.md`]

## Library / SDK

- `@earendil-works/pi-coding-agent` "embeds Pi in a Node.js or Bun process" and gives "direct TypeScript access to the agent, sessions, tools, models, and resources used by the command-line application". [`docs/sdk.md`]
- Entry point: `createAgentSession()` returns `{ session }`; `session.prompt(text)` resolves "when the run finishes"; `session.getLastAssistantText()`; `session.subscribe(event => ...)` for streamed events; `session.dispose()`. [`docs/sdk.md`; `examples/sdk/01-minimal.ts`]
- Configurable boundaries on `createAgentSession`: `modelRuntime`, `model`, `thinkingLevel`, `scopedModels`, `settingsManager`, `sessionManager`, `resourceLoader`, `tools`, `noTools`, `excludeTools`, `customTools`. [`docs/sdk.md` "Configuring a session"]
- The CLI's `codemode`, `tool_search`, and MCP built-in extensions are **not** loaded by SDK sessions by default; add `createCodemodeExtension()`, `createToolSearchExtension()`, `createMcpExtension()` to `DefaultResourceLoader`'s `extensionFactories`. [`docs/sdk.md` "codemode-mcp"]
- Queueing while a run is active: `steer()` and `followUp()`; `prompt()` during streaming "rejects rather than guessing" unless told which to do. `abort()` and `waitForIdle()` exist. [`docs/sdk.md` "Prompting"]
- Events: `message_update` (deltas), `message_end` (authoritative message), `agent_end` (one low-level run), `agent_settled` ("Pi will not continue automatically"). [`docs/sdk.md` "Subscribing to events"]
- The package's `exports` map has `"."`, `"./rpc-entry"`, `"./client"` (source only), and `"./experimental/plugin"` (source only). The `files` list excludes `dist/client` and `dist/experimental` from the published package. [`packages/coding-agent/package.json`]
- Supporting libraries in the monorepo: `@earendil-works/pi-ai` ("Unified multi-provider LLM API"), `@earendil-works/pi-agent-core` ("Agent runtime with tool calling and state management"), `@earendil-works/pi-tui`, `@earendil-works/chord`, `@earendil-works/pi-telemetry`, `@earendil-works/pi-durable`. [`README.md` "Packages"]
- `@earendil-works/pi-durable` is labelled "**Experimental.** The API changes without notice between releases." It commits "conversations, model turns, tool calls, and your own state ... to storage before anything is shown" and resumes after a crash. [`packages/durable/README.md`]
- The SDK is TypeScript/JavaScript only. No Python or other-language SDK was found in the repository. For other languages the docs point to RPC mode. [`docs/rpc.md` table; `docs/cli-integration.md`]
- Unverified: the SDK's exact method signatures. The docs defer to "the exported TypeScript declarations or `session-manager.ts`"; I did not read those files in full. [`docs/sdk.md`]

## Headless / non-interactive modes

Four CLI modes share "the same agent, sessions, resources, and tools". [`docs/cli-integration.md`]

| Mode | Invocation | Output | Lifetime |
|---|---|---|---|
| Interactive | `pi` | terminal UI | until exit |
| Print | `pi --print "..."` / `-p` | final assistant text on stdout | one invocation |
| JSON | `pi --mode json "..."` | JSONL session events on stdout | one invocation |
| RPC | `pi --mode rpc --no-session` | JSONL commands in / responses and events out | long-lived |

[`docs/cli.md` "Invocation and output"; `docs/cli-integration.md`]

- Mode auto-selection: "When either stream is redirected and neither JSON nor RPC mode is selected, Pi uses print mode." [`docs/cli.md`]
- Piped stdin is prepended to the first prompt; `@path` includes a file or image. RPC mode rejects `@file` arguments. [`docs/cli.md`]
- Print mode: "A final assistant response with an `error` or `aborted` stop reason produces a nonzero exit status." Errors go to stderr. [`docs/cli-integration.md`]
- JSON mode: "A failed or aborted assistant response appears in the event stream but does not by itself produce a nonzero exit status." All prompts are supplied at start; the process "does not accept later commands". [`docs/cli-integration.md`]
- RPC mode: "strict JSONL framing" on stdin/stdout; commands carry an optional `id` echoed in the response; close stdin for orderly shutdown; stdout is reserved for protocol records, diagnostics go to stderr. The docs warn that Node `readline` is unsuitable because it splits on U+2028/U+2029. [`docs/rpc.md`]
- RPC commands (33 listed): `prompt`, `steer`, `follow_up`, `abort`, `clear_queue`, `new_session`, `get_state`, `get_messages`, `set_model`, `cycle_model`, `get_available_models`, `set_thinking_level`, `cycle_thinking_level`, `get_available_thinking_levels`, `set_steering_mode`, `set_follow_up_mode`, `compact`, `set_auto_compaction`, `set_auto_retry`, `abort_retry`, `bash`, `abort_bash`, `get_session_stats`, `export_html`, `switch_session`, `fork`, `clone`, `get_fork_messages`, `get_entries`, `get_tree`, `get_last_assistant_text`, `set_session_name`, `get_commands`. [`docs/rpc-commands.md` headings]
- A `prompt` response's `data.disposition` is `"started"`, `"queued"`, or `"handled"`; `success: true` "does not mean model work completed". Completion is signalled by the `agent_settled` event. [`docs/rpc.md` "Run lifecycle"; `docs/rpc-commands.md` "prompt"]
- `get_state` returns `model`, `thinkingLevel`, `isStreaming`, `isCompacting`, `sessionFile`, `sessionId`, `sessionName`, `messageCount`, `pendingMessageCount`, and queue modes. [`docs/rpc-commands.md` "get_state"]
- A typed subprocess client, `RpcClient` (with `promptAndWait(message, images?, timeout = 60000)`), is exported from `@earendil-works/pi-coding-agent`. It "requires a path to a runnable Pi CLI". [`src/modes/rpc/rpc-client.ts` lines 56, 513; `src/index.ts` line 421; `docs/cli-integration.md`]
- Extension UI dialogs (confirm, select, etc.) are forwarded over RPC via a separate "RPC Extension UI" subprotocol; "JSON and print modes have no UI". [`docs/extensions.md` "UI and modes"; `docs/rpc.md`]
- Project trust in headless modes: "Print, JSON, and RPC modes cannot show the built-in trust prompt." Without `--approve`/`--no-approve`, an extension decision, or a saved decision, `defaultProjectTrust: "always"` loads project resources and `"ask"` (the default) or `"never"` skips them. [`docs/security.md` "Project trust without an interactive prompt"; `docs/settings.md`]

## Structured output

- JSON and RPC modes emit a typed event stream (`agent_start`, `turn_start`, `message_start`, `message_update`, `message_end`, `turn_end`, `agent_end`, `agent_settled`, `tool_execution_start/update/end`, `queue_update`, `compaction_*`, `auto_retry_*`, and others). JSON mode's first record is the session header `{"type":"session","version":3,...}`. [`docs/json.md`]
- `message_update` records are delta-only; `message_end.message` is authoritative. `tool_execution_end` carries `result`, `isError`, `durationMs`. [`docs/json.md`]
- The exported TypeScript type is `JsonAgentSessionEvent`. [`docs/json.md` "TypeScript types"]
- JSON mode is "structured event output, not a single JSON result or a constraint on the format of the model's response". [`docs/cli-integration.md`]
- Pattern for a final structured answer: a custom tool whose `execute()` returns `terminate: true` so the run ends on the tool call; the repo ships `examples/extensions/structured-output.ts` demonstrating this. Tools may declare `outputSchema` and return `structuredContent`. [`examples/extensions/structured-output.ts`; `docs/extensions.md` "Tools"]
- Not found: a CLI flag that constrains the model's final answer to a JSON schema. Unverified whether one exists under another name; `pi --help` is documented as authoritative for the installed version. [`docs/cli.md`]

## Sessions: persistence and resume

- Sessions persist by default as JSONL under `~/.pi/agent/sessions/--<path>--/<timestamp>_<session-id>.jsonl`, grouped by working directory; `<session-id>` is a UUID unless supplied. Override the directory with `--session-dir`, `PI_CODING_AGENT_SESSION_DIR`, or the `sessionDir` setting (CLI flag wins). [`docs/session-format.md`; `docs/sessions.md`]
- Entries form a tree via `id`/`parentId`; the "leaf" is the current position; branching keeps abandoned branches in the same file. Current format version is 3; v1 and v2 files auto-migrate on load. [`docs/session-format.md`]
- Entry types: `session` header, `message`, `model_change`, `thinking_level_change`, `usage`, `compaction`, `context_edit`, `branch_summary`, `custom`, `custom_message`, `label`, `session_info`. [`docs/session-format.md`]
- Resume flags: `-c/--continue` (most recent for cwd), `-r/--resume` (picker), `--session <path|id>`, `--session-id <id>` (opens or creates that exact ID; IDs allow letters, numbers, `.`, `_`, `-`, must start and end alphanumeric), `--fork <path|id>`, `--no-session` (in-memory, not resumable), `-n/--name`. [`docs/cli.md` "Sessions"]
- Constraints: `--fork` cannot combine with `--session`, `--continue`, `--resume`, or `--no-session`; `--session-id` cannot combine with `--session`, `--continue`, or `--resume`. [`docs/cli.md`]
- SDK: `SessionManager.inMemory()`, `.create(cwd)`, `.continueRecent(cwd)`, `.list(cwd)`, `.open(path)`; an optional second argument sets a custom session directory. `AgentSessionRuntime` adds `newSession()`, `switchSession()`, `fork()`, `importFromJsonl()`. [`examples/sdk/11-sessions.ts`; `docs/sdk.md`]
- RPC: `new_session`, `switch_session`, `fork`, `clone`, `get_entries`, `get_tree`, `export_html`. [`docs/rpc-commands.md`]
- "A session records model and thinking-level changes. Resuming the session restores them without changing defaults for new sessions." [`docs/models.md`]
- Compaction: automatic near the context limit (`compaction.enabled` default `true`, `reserveTokens` 16384, `keepRecentTokens` 20000); original entries are kept. [`docs/sessions.md`; `docs/settings.md`]
- Shell tools receive `PI_SESSION_ID`, `PI_SESSION_FILE`, `PI_PROVIDER`, `PI_MODEL`, `PI_REASONING_LEVEL` in their environment. [`docs/environment-variables.md`]

## Tools and permissions

- Default enabled tools: `read`, `bash`, `edit`, `write`. Other built-ins: `powershell`, `grep`, `find`, `ls`. Built-in extensions add `codemode` and `tool_search`, off by default. [`docs/cli.md` "Tools"; `docs/settings.md`]
- Selection flags: `-t/--tools <list>` (allowlist, `*` patterns, or `+name`/`-name` adjustments), `-xt/--exclude-tools`, `-nbt/--no-builtin-tools`, `-nt/--no-tools`, `--no-mcp`. Setting: `defaultTools` in `~/.pi/agent/settings.json` or `.pi/settings.json`. [`docs/cli.md`; `docs/settings.md`]
- **No built-in permission system.** "Pi does not include a built-in permission system for restricting filesystem, process, network, or credential access. By default, it runs with the permissions of the user and process that launched it." [`README.md` "Permissions & Containerization"]
- "Pi ... does not ask for approval before every tool call." "Watching the transcript, using project trust, and reviewing changes do not create a security boundary." [`docs/security.md`]
- pi.dev lists "permission popups" among things that are "Not built in". [pi.dev front page]
- Gating is done by extensions: a `tool_call` handler "can mutate input or block execution" by returning `{ block: true, reason }`. A handler failure "blocks the tool as a fail-safe". Tool `annotations` (`readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint`) are available to such handlers. [`docs/extensions.md` "Events and concurrency", "Tool exposure", "Errors and cleanup"]
- Shipped examples: `examples/extensions/permission-gate.ts` (regex check of bash commands; in non-interactive mode, "block by default" when `!ctx.hasUI`), `protected-paths.ts`, `confirm-destructive.ts`, `sandbox/`, `gondolin/`. [`examples/extensions/` listing; `examples/extensions/permission-gate.ts`]
- Extensions run in-process "with the same operating-system permissions"; they can "inspect prompts, tool calls, files, credentials, and session history". [`docs/extensions.md`]
- Project trust gates loading of `.pi/settings.json`, `.pi/mcp.json`, `.pi/extensions`, `.pi/skills`, `.pi/prompts`, `.pi/themes`, `.pi/SYSTEM.md`, `.pi/APPEND_SYSTEM.md`, and `.agents/skills`. Context files (`AGENTS.md`, `CLAUDE.md`, `AGENTS.override.md`) load regardless of trust. Saved decisions live in `~/.pi/agent/trust.json`. [`docs/security.md`]
- Isolation patterns documented by the project: plain Docker (whole process), Docker Sandboxes (`sbx run --kit "docker.io/sbx/pi-kit:latest" pi`; `sbx exec <name> -- pi -p "..."`), NVIDIA OpenShell, and the Gondolin micro-VM extension (routes `read`, `write`, `edit`, `bash`, `grep`, `find`, `ls` into a VM while Pi stays on the host). [`docs/containerization.md`]
- MCP is built in (`builtin:mcp`): servers configured in `~/.pi/agent/mcp.json` or `.pi/mcp.json`, or via `pi mcp add`. [`docs/mcp.md`; `docs/settings.md` "Resources"]
- System prompt: `--system-prompt <text|path>` replaces, `--append-system-prompt` appends; `SYSTEM.md`/`APPEND_SYSTEM.md` in the agent dir or `.pi/`. `-nc/--no-context-files` disables `AGENTS.md`/`CLAUDE.md` discovery. [`docs/cli.md`; `docs/configuration.md`]

## Model providers

- pi.dev claims "15+ providers (including Anthropic, OpenAI, Google, and Ollama)". [pi.dev front page]
- Provider modules present in `packages/ai/src/providers/` at the researched commit: `amazon-bedrock`, `ant-ling`, `anthropic`, `azure`, `baseten`, `cerebras`, `cloudflare-ai-gateway`, `cloudflare-workers-ai`, `deepseek`, `fireworks`, `github-copilot`, `google`, `google-vertex`, `groq`, `huggingface`, `kimi-coding`, `meta`, `minimax`, `minimax-cn`, `mistral`, `moonshotai`, `moonshotai-cn`, `nvidia`, `openai`, `openai-codex`, `opencode`, `opencode-go`, `openrouter`, `qwen-token-plan`, `qwen-token-plan-cn`, `qwen-token-plan-individual`, `radius`, `together`, `typesafe`, `vercel-ai-gateway`, plus `faux` (my read: a test provider; AGENTS.md says the test suite uses "the faux provider"). [directory listing of `packages/ai/src/providers/`; `AGENTS.md`]
- Credential sources, in precedence order: `--api-key`, `auth.json` (`/login`), `apiKey` in `models.json`, then provider environment variables or ambient cloud credentials. [`docs/models.md` "Authenticate"]
- Environment variables include `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`, `OPENROUTER_API_KEY`, `COPILOT_GITHUB_TOKEN`, and others; Anthropic also accepts `ANTHROPIC_OAUTH_TOKEN` and `ANTHROPIC_AUTH_TOKEN`. Bedrock uses the AWS credential chain; Vertex uses `GOOGLE_CLOUD_API_KEY` or ADC. [`docs/providers.md`]
- OAuth/subscription sign-in is via `/login`; `/login` "guides you through its OAuth or API-key flow". On headless machines, paste the redirect URL or code. [`docs/providers.md`]
- OpenAI-, Anthropic-, or Google-compatible endpoints (Ollama, LM Studio, vLLM, SGLang, proxies) are added via `~/.pi/agent/models.json` with `baseUrl`, `api` (for example `openai-completions`), and a `models` list. llama.cpp has a dedicated integration (`/llama`). [`docs/models.md`]
- `--model <pattern>` with optional `:<thinking>` suffix; `--provider`; `--thinking off|minimal|low|medium|high|xhigh|max`; `--models` scope; `--list-models`. [`docs/cli.md` "Models"]
- `pi auth check --provider <p> --json` prints `ready`/`not_ready`/`invalid` with exit codes 0/1/2. [`docs/cli.md` "Credential commands"]
- `--offline` / `PI_OFFLINE=1` disables catalog refreshes and other automatic network activity. [`docs/cli.md`; `docs/environment-variables.md`]

## License and maturity

- License: MIT (repo `LICENSE`, `package.json`, GitHub API, npm registry). [`LICENSE`; `packages/coding-agent/package.json`; GitHub API; npm registry]
- Current release: `@earendil-works/pi-coding-agent` 1.1.0, published to npm 2026-10-07; GitHub release `v1.1.0` published 2026-10-07. `1.0.0` was published to npm 2026-10-01. The `legacy-node20` npm dist-tag points at 0.74.2. [npm registry; GitHub API releases]
- The Earendil "Pi 1.0" post is dated 2026-10-01 and describes 1.0 as "a hardened, minimal, extensible agent harness"; the post "makes no formal stability or compatibility promises" beyond that (WebFetch summary of the post). [earendil.com/posts/pi-1-0/, fetched 2026-10-11]
- Release cadence observed: 1.0.0 (2026-10-01), 1.0.3 and 1.0.4 (2026-10-05), 1.1.0 (2026-10-07). The `[Unreleased]` changelog section already lists a breaking change (published config schemas, theme `$schema` move). [GitHub API releases; `packages/coding-agent/CHANGELOG.md`]
- GitHub metrics on 2026-10-11: 114302 stars, 14553 forks, 322 open issues; last push 2026-10-11. [GitHub API]
- Contribution policy: "All issues and PRs from new contributors are auto-closed by default"; maintainers reopen via `lgtmi`/`lgtm` replies. [`CONTRIBUTING.md`]
- Security stance: "Pi treats the local user account and files writable by that account as inside the same trust boundary as the Pi process itself." Prompt injection via `AGENTS.md` or comments "cannot be protected against". Report to `security@earendil.com`. [`SECURITY.md`]
- Supply chain: direct deps pinned to exact versions; installer uses an install lock; CI runs `npm ci --ignore-scripts` and scheduled `npm audit`. [`README.md` "Supply-chain hardening"]
- Telemetry: `enableInstallTelemetry` defaults to `true` ("anonymous install/update reporting and selected provider attribution headers"); `PI_TELEMETRY=0` overrides. `PI_SKIP_VERSION_CHECK` disables the pi.dev version request. [`docs/settings.md`; `docs/environment-variables.md`]
- Named real-world integration: OpenClaw (`github.com/OpenClaw/OpenClaw`). Not inspected. [`README.md`]

## Not verified

- No command was executed; install, `pi --help`, and runtime behavior are unverified.
- SDK method signatures beyond what the docs and `examples/sdk/*.ts` show.
- Whether any flag constrains the final model answer to a JSON schema.
- The exact set of providers exposed at runtime (the directory listing is the proxy used above).
- The "Pi 1.0" post content is known only through a WebFetch summary, not the raw page.
