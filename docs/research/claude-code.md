# Research: Claude Code integration surface

Ticket: `.tracker/v1-spec/issues/06-research-claude-code.md`
Date fetched: 2026-10-11
Sources: official docs at `https://code.claude.com/docs/` only. `docs.claude.com/en/api/agent-sdk/overview` redirects to `code.claude.com/docs/en/agent-sdk/overview`, so every Agent SDK citation below is on `code.claude.com`.

Every claim cites the page it was read on. Quotes are copied from the page text as the fetch tool returned it. Items the docs do not state are listed under "Unverified" at the end and marked inline.

## Summary

1. `claude -p` (`--print`) is the non-interactive mode. It reads the prompt from the argument or stdin, exits 0 on success and non-zero on failure, and emits `text`, `json`, or `stream-json`. `--bare` is "the recommended mode for scripted and SDK calls" and will become the `-p` default. [headless]
2. The Agent SDK (TypeScript `@anthropic-ai/claude-agent-sdk`, Python `claude-agent-sdk`) "spawns and supervises a `claude` CLI subprocess" and "talks to it over stdio". It bundles the native binary. It adds a `canUseTool` permission callback, in-process MCP tools, hook callbacks, `SessionStore` transcript mirroring, and a `spawnClaudeCodeProcess` option "to run Claude Code in VMs, containers, or remote environments". [hosting, typescript]
3. Sessions are JSONL transcripts at `~/.claude/projects/<project>/<session-id>.jsonl`. `--resume <id>` finds the ID in "every other project on this machine"; cross-machine resume needs the SDK's `SessionStore`. The transcript entry format "is internal to Claude Code and changes between versions". [sessions, hosting]
4. For unattended runs the docs give three levers: `--permission-mode dontAsk` plus `--allowedTools` (deny anything that would prompt), `--permission-mode auto` (classifier), or `--dangerously-skip-permissions`, which the docs say to run only inside a container, VM, or sandbox runtime and which "refuses to start ... when running as root or under `sudo`" on Linux and macOS. [permission-modes, sandbox-environments]
5. The built-in Bash sandbox uses Seatbelt on macOS and `bubblewrap` plus `socat` on Linux, is "off by default", covers shell commands only, and needs `enableWeakerNestedSandbox` inside an unprivileged container. The docs name Firecracker microVMs and gVisor as stronger isolation choices but do not describe Claude Code behaviour specific to a microVM. [sandboxing, secure-deployment]

## 1. Headless / non-interactive mode

Page: https://code.claude.com/docs/en/headless ("Run Claude Code programmatically")

- "Add the `-p` (or `--print`) flag to any `claude` command to run it non-interactively." [headless, "Basic usage"]
- "Claude Code exits with code 0 on success and a non-zero code when the run fails ... If you pass an invalid flag, Claude Code reports the error to stderr before the run starts. When a failure happens inside the run, such as missing authentication, Claude Code prints the failure as the result on stdout." [headless, "Basic usage"]
- `-p` rejects `--bg`; `--cloud` with a session ID and `-p` queues a message into a cloud session. [headless, "Basic usage"; errors, "Conflict between `--bg` and `--print`"]
- SIGTERM: "Claude Code exits with code 143. Claude Code leaves the turn that was in progress unfinished and records no result for it. To end the turn instead, send SIGINT, or call the Agent SDK's `interrupt()`." SIGTERM also "terminates the process tree of any Bash command that is still running" and runs `SessionEnd` hooks. [headless, "Stop a run with SIGTERM"]
- A `-p` run can stay open after the final turn to wait for background work; the default idle ceiling is 10 minutes, set by `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS` (default `600000`; `0` waits indefinitely). [headless, "Background tasks at exit"; env-vars]
- If the working directory is deleted mid-session, "the session keeps running" and shell commands fail until it exists again. [headless, "If the working directory is deleted"]
- Trust: "A `-p` session shows no workspace trust dialog and no per-server approval prompt." Without `--bare`, a `-p` run "runs the hooks in a project's `.claude/settings.json` and connects the servers in its `.mcp.json`, even in a folder you've never trusted." [headless, "Start faster with bare mode"]

### Bare mode

- `--bare`: "skip auto-discovery of hooks, skills, custom commands, subagents, installed plugins, MCP servers, auto memory, and CLAUDE.md so scripted calls start faster." Sets `CLAUDE_CODE_SIMPLE`. [cli-reference, "CLI flags"]
- "In bare mode, Claude Code never reads OAuth credentials or the system keychain. For the Anthropic API, set `ANTHROPIC_API_KEY` in the environment ... or supply an `apiKeyHelper` in the `--settings` JSON." Bedrock, Google Cloud's Agent Platform, and Microsoft Foundry credentials still work. [headless, "Start faster with bare mode"]
- "In bare mode Claude has access to the Bash, file read, and file edit tools." Context is loaded by flag: `--append-system-prompt(-file)`, `--settings`, `--mcp-config`, `--agents`, `--plugin-dir`, `--plugin-url`. No system reminders, no background tasks. [headless, "Start faster with bare mode"]
- "`--bare` is the recommended mode for scripted and SDK calls, and will become the default for `-p` in a future release." [headless, Note]

### Flags relevant to driving the CLI (all from https://code.claude.com/docs/en/cli-reference, "CLI flags" table, unless noted)

| Flag | Documented description (abridged quote) |
| - | - |
| `--print`, `-p` | "Print response without interactive mode" |
| `--output-format` | "Specify output format for print mode (options: `text`, `json`, `stream-json`)" |
| `--input-format` | "Specify input format for print mode (options: `text`, `stream-json`)" |
| `--json-schema` | "Get validated JSON output matching a JSON Schema after the agent completes its workflow (print mode only)" |
| `--verbose` | "Enable verbose logging, shows full turn-by-turn output" |
| `--include-partial-messages` | "Include partial streaming events in output. Requires `--print` and `--output-format stream-json`" |
| `--replay-user-messages` | "Re-emit user messages from stdin back on stdout for acknowledgment. Requires `--input-format stream-json` and `--output-format stream-json`" |
| `--include-hook-events` | "Include hook lifecycle events in the output stream ... Requires `--output-format stream-json`" |
| `--forward-subagent-text` | subagent text/thinking blocks in the stream with `parent_tool_use_id`; "Requires `--print` and `--output-format stream-json`"; v2.1.211+ |
| `--max-turns` | "Limit the number of agentic turns (print mode only). Exits with an error when the limit is reached. No limit by default." |
| `--max-budget-usd` | "Stop the run once estimated spend on API calls reaches this amount (print mode only)." Client-side estimate; subagent spend counts; "Spend can pass the cap" |
| `--allowedTools` / `--allowed-tools` | "Tools that execute without prompting for permission, apart from reads from network paths." Uses permission rule syntax |
| `--disallowedTools` / `--disallowed-tools` | "Deny rules. A bare tool name removes the matching tools from Claude's context ... A scoped rule such as `Bash(rm *)` leaves the tool available and denies only calls that match" |
| `--tools` | "Restrict which built-in tools Claude can use. Use `""` to disable all, `"default"` for the default set, or tool names like `"Bash,Edit,Read"`." Does not affect MCP tools |
| `--permission-mode` | "Accepts `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`, or `manual` as an alias for `default`" |
| `--dangerously-skip-permissions` | "Skip permission prompts. Equivalent to `--permission-mode bypassPermissions`" |
| `--allow-dangerously-skip-permissions` | adds `bypassPermissions` to the mode cycle without starting in it |
| `--permission-prompt-tool` | "Specify an MCP tool to handle permission prompts in non-interactive mode." Waits for that server up to `MCP_TIMEOUT` (30 s default) |
| `--permission-prompts` | `host` (default) routes prompts to the SDK host or prompt tool; `none` denies them. v2.1.259+ |
| `--restricted` | for "an evaluation harness" on a shared machine: removes command-running tools and WebFetch unless named in `--tools`, confines file tools to working directories, loads only managed settings and `--settings`, "refuses `bypassPermissions`". v2.1.248+ |
| `--system-prompt`, `--system-prompt-file` | replace the default system prompt |
| `--append-system-prompt`, `--append-system-prompt-file` | append to the default system prompt |
| `--append-subagent-system-prompt(-file)` | append to every subagent's prompt; "Only applies in non-interactive mode with `-p`" |
| `--system-prompt-snapshot off` | rebuild the system prompt each request instead of reusing the one recorded on the first request |
| `--exclude-dynamic-system-prompt-sections` | move per-user context out of the system prompt "to improve prompt-cache reuse across different users and machines running the same task. Use with `-p`" |
| `--model`, `--fallback-model`, `--effort` | model alias or full name; comma-separated fallback chain; effort level |
| `--mcp-config`, `--strict-mcp-config` | load MCP servers from JSON files/strings; with `-p` waits for pending servers up to `MCP_TIMEOUT`; `--strict-mcp-config` ignores all other MCP config |
| `--agents` | define subagents via JSON; with `--print` may be a path to a JSON file (v2.1.281+) |
| `--settings` | settings JSON file or inline JSON; overrides same keys for the session; file must be a regular file no larger than 2 MiB |
| `--setting-sources` | comma-separated `user`, `project`, `local` |
| `--add-dir` | additional working directories; "doesn't discover most `.claude/` configuration from these directories" |
| `--plugin-dir`, `--plugin-url` | load plugins for the session |
| `--continue` / `-c`, `--resume` / `-r`, `--fork-session`, `--session-id`, `--name` / `-n`, `--no-session-persistence` | see section 3 |
| `--init`, `--maintenance`, `--init-only` | run `Setup` hooks before the session (print mode only) or run Setup/SessionStart hooks and exit |
| `--debug`, `--debug-file <path>` | debug logging; debug output goes to `~/.claude/debug/<session-id>.txt` by default [network-config, "Verify your configuration"] |
| `--worktree` / `-w` | start in a git worktree at `<repo>/.claude/worktrees/<name>` |
| `--bg` | background session; "Can't be combined with `-p`/`--print`" |
| `--environment <ccpool_...>` | create a cloud session on a self-hosted environment |

"`claude --help` does not list every flag, so a flag's absence from `--help` does not mean it is unavailable." [cli-reference, "CLI flags"]

### Stdin

- "Non-interactive mode reads stdin, so you can pipe data in and redirect the response out like any other command-line tool." Example: `cat build-error.txt | claude -p '...' > output.txt`. [headless, "Pipe data through Claude"]
- "Piped stdin is capped at 10MB. If you exceed the cap, Claude Code exits with a clear error and a non-zero status." [headless, Note]
- "If Claude Code can't read stdin ... Claude Code prints a warning to stderr and continues with the prompt from the command line." [headless]
- `-p` with no prompt and nothing on stdin: `Error: Input must be provided either through stdin or as a prompt argument when using --print`. [errors, "Input must be provided when using `--print`"]

### Slash commands under `-p`

User-invoked skills and custom commands work when included in the prompt string. Built-in terminal-only commands such as `/login` are unavailable. `/model`, `/effort`, `/fast`, `/color`, `/rename` accept an argument (v2.1.205+); `/config key=value` changes a setting. [headless, Note under "Create a commit"]

## 2. Structured output formats

Page: https://code.claude.com/docs/en/headless ("Get structured output", "Stream responses")

- `text` (default): plain text. `json`: "structured JSON with result, session ID, and metadata". `stream-json`: "newline-delimited JSON for real-time streaming". [headless]
- `json` payload: text in `result`; `session_id` (the docs' example is `jq -r '.session_id'`); "includes `total_cost_usd` and a per-model cost breakdown". With `--continue`/`--resume` the cost is "the conversation's whole total, earlier runs' spend included. Both figures are client-side estimates and can differ from your actual bill." [headless, "Pipe data through Claude", "Continue conversations"]
- The CLI pages do not list the `json` object field by field. The Agent SDK's `SDKResultMessage` is the fullest documented schema (success arm: `type: "result"`, `subtype: "success"`, `uuid`, `session_id`, `duration_ms`, `duration_api_ms`, `is_error`, `num_turns`, `result`, `stop_reason`, `total_cost_usd`, `usage`, `modelUsage`, `permission_denials`, `structured_output?`; error arm: `subtype` in `error_max_turns`, `error_during_execution`, `error_max_budget_usd`, `error_max_structured_output_retries`, with `errors: string[]` and no `result`). [agent-sdk/typescript, "SDKResultMessage"] UNVERIFIED: that the CLI `--output-format json` object equals `SDKResultMessage` field for field. The docs do not state the equivalence.
- Python `ResultMessage` carries the same fields plus `api_error_status`, `terminal_reason`, `uuid`, `origin`; "`is_error` can be `True` on `subtype="success"` when the final model request failed, so check `is_error` and `terminal_reason` rather than `subtype` alone." [agent-sdk/python, "ResultMessage"]

### `--json-schema`

- "To get output conforming to a specific schema, use `--output-format json` with `--json-schema` and a JSON Schema definition. The response includes metadata about the request (session ID, usage, etc.) with the structured output in the `structured_output` field." Invalid schema exits with `Error: --json-schema is not a valid JSON Schema`. The `format` keyword is accepted as an annotation but not enforced (v2.1.205+). [headless, "Get structured output"; cli-reference]

### `stream-json` output

- "Use `--output-format stream-json` with `--verbose` and `--include-partial-messages` to receive tokens as they're generated. Each line is a JSON object representing an event ... The last line of the stream is a `result` message with the final response text, cost, and session metadata." [headless, "Stream responses"] UNVERIFIED: whether `--verbose` is strictly required for `stream-json`; the docs always pair them in examples and the `--prompt-suggestions` flag lists `--verbose` as a requirement, but no page states the general rule.
- Partial token events: `type: "stream_event"` with `event` (raw API stream event); the docs' jq filter is `select(.type == "stream_event" and .event.delta.type? == "text_delta") | .event.delta.text`. [headless, "Stream responses"]
- Slow consumer: "Claude Code waits for the queued output to drain before exiting ... capped at 30 seconds" (v2.1.214+). [headless]
- `system/init`: "reports session metadata including the model, tools, MCP servers, and loaded plugins. It is the first event in the stream unless startup events precede it" (`plugin_install`, and `hook_started`/`hook_progress`/`hook_response` for `SessionStart`/`Setup` hooks). It carries an optional `capabilities` array for feature detection (v2.1.205+), `plugins`, `plugin_errors`, `mcp_servers`, `mcp_server_errors` (key omitted when there are no errors, "so a CI gate can fail on a non-empty array"). [headless, "Read session metadata", "Fail CI when a plugin or MCP server doesn't load"]
- `SDKSystemMessage` (init) fields: `session_id`, `tools`, `mcp_servers`, `model`, `permissionMode`, `claude_code_version`, `cwd`, `apiKeySource`, `agents?`, `skills`, `plugins`, `slash_commands`, `output_style`, and more. [agent-sdk/typescript, "SDKSystemMessage (init)"]
- `system/api_retry`: fields `attempt`, `max_retries`, `retry_delay_ms`, `error_status`, `no_response?`, `error` (categories such as `authentication_failed`, `rate_limit`, `overloaded`, `billing_error`, `max_output_tokens`), `uuid`, `session_id`. [headless, "Handle API retries"]
- `system/plugin_install` (only with `CLAUDE_CODE_SYNC_PLUGIN_INSTALL`): `status` in `started`, `installed`, `failed`, `completed`. [headless, "Track plugin installs"]
- `system/permission_denied` and `permission_denials` on the result message when `--permission-prompts none` denies a call. [headless, "Turn off permission prompts in unattended runs"]
- Subagent and forked-skill messages appear as `assistant` and `user` messages whose `parent_tool_use_id` is the ID of the `Agent` or `Skill` tool call (or a `forked-command-` value); main-conversation messages carry `null`. [headless, "Follow subagent messages"]
- `--include-hook-events` adds `hook_started`/`hook_progress`/`hook_response`; `--prompt-suggestions` adds `prompt_suggestion`. [cli-reference]
- The SDK `SDKMessage` union also lists `compact_boundary`, `status`, `tool_progress`, task messages, `rate_limit_event`, `mirror_error`, `informational`, `worker_shutting_down`. [agent-sdk/typescript, "SDKMessage"] UNVERIFIED: exact field lists for these and for CLI `user` messages.
- Cost warning: "The `total_cost_usd` and `costUSD` fields are client-side estimates, not authoritative billing data." [agent-sdk/cost-tracking]

### `stream-json` input

- `--input-format stream-json` exists (print mode). With it, "a message still queued when the limit ends a turn stays queued and starts a new turn with its own limit" (`--max-turns`). [cli-reference]
- Wire format constraint: "Each stream-json message must be a single newline-terminated JSON line"; a line over 268,435,456 characters with no newline exits with code 1 (v2.1.257+). [errors, "stream-json input carried over 256M characters with no newline"]
- Message shape documented for the SDK's streaming input: `{"type":"user","message":{"role":"user","content":"..."},"parent_tool_use_id":null}`; `content` may be an array with `text` and base64 `image` blocks. [agent-sdk/streaming-input, "Streaming Input Mode"] UNVERIFIED: that the CLI accepts exactly this line shape on stdin. The hosting page says the SDK "talks to it over stdio", and the TypeScript reference refers to `initialize` and `interrupt` control requests sent "over the CLI's stdin" and `control_request`/`control_response` messages, so my read is that the SDK's stream-json transport is the CLI's `--input-format stream-json` protocol, but no page states that in one place.
- "Streaming Input Mode ... is the preferred way to use the Claude Agent SDK." It enables image uploads, queued messages, interruption, and persistent context; single-message mode "does not support" images, queueing, interruption, or natural multi-turn. [agent-sdk/streaming-input]

## 3. Claude Agent SDK: what it adds beyond the CLI

Pages: https://code.claude.com/docs/en/agent-sdk/overview, /agent-sdk/hosting, /agent-sdk/typescript, /agent-sdk/python, /agent-sdk/permissions, /agent-sdk/hooks, /agent-sdk/subagents, /agent-sdk/sessions, /agent-sdk/quickstart, /agent-sdk/migration-guide

- Packages: TypeScript `@anthropic-ai/claude-agent-sdk`; Python `claude-agent-sdk` (import `claude_agent_sdk`). Formerly "Claude Code SDK" (`@anthropic-ai/claude-code`, `claude-code-sdk`); `ClaudeCodeOptions` became `ClaudeAgentOptions`. [typescript; python; migration-guide]
- Positioning: "A library that runs the Claude Code binary, with Claude Code's capabilities, such as built-in tools, permissions, sessions, and hooks." For other languages: "run the CLI as a subprocess with the `-p` flag and `--output-format json`." [overview, "Compare the Agent SDK to other Claude tools"]
- Architecture: "The Agent SDK spawns and supervises a `claude` CLI subprocess that owns a shell, a working directory, and session files on disk ... When your code calls `query()`, the SDK spawns a separate `claude` CLI process and talks to it over stdio." "One agent session maps to one subprocess." [hosting, "The subprocess model"]
- Runtime: "Python 3.10+ for the Python SDK, or Node.js 18+ for the TypeScript SDK. Both the TypeScript and Python SDKs bundle a native Claude Code binary for most installs, and the spawned CLI needs no separate Node.js install." "The bundled binary is pinned to the SDK package version, so updating the SDK is how you update the CLI." Exceptions: `npm ci --omit=optional` skips the binary (set `pathToClaudeCodeExecutable`); ARM64 Windows pip installs find `claude` on `PATH`. [hosting, "Runtime dependencies"; quickstart]
- Auth restriction: "Unless previously approved, Anthropic does not allow third party developers to offer claude.ai login or rate limits for their products, including agents built on the Claude Agent SDK. Use the API key authentication methods." [overview, Note]

### API surface

- `query({ prompt, options })` returns `Query extends AsyncGenerator<SDKMessage, void>`; `prompt` is a string or `AsyncIterable<SDKUserMessage>`. Python: `query(*, prompt, options, transport)`; `ClaudeSDKClient` holds a session open with `connect`, `query`, `receive_messages`, `receive_response`, `interrupt`, `set_permission_mode`, `set_model`, `rewind_files`, `get_mcp_status`, `disconnect`. [typescript, "query()"; python, "ClaudeSDKClient"]
- `Query` methods: `interrupt()`, `setPermissionMode()`, `setModel()`, `streamInput(stream)`, `close()` ("terminate the underlying process"), `reinitialize()`, `startup()`/`prewarm()` for pre-warming subprocesses. [typescript, "Query object"; hosting, "Long-running sessions"]
- Options beyond CLI flags (TypeScript names; Python snake_case equivalents exist unless noted) [typescript, "Options"; python, "ClaudeAgentOptions"]:
  - `canUseTool`: "Custom permission function, invoked only when the permission flow falls through to a prompt. Not invoked for calls auto-approved by `allowedTools`, allow rules, or `permissionMode`." Result is written back "as the `control_response`". In `dontAsk` mode it is never called.
  - `permissionPromptToolName`, `permissionPrompts: 'host' | 'none'`.
  - `hooks`: in-process callbacks for `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `UserPromptSubmit`, `Stop`, `SubagentStart`, `SubagentStop`, `PreCompact`, `Notification`, `PermissionRequest`; TypeScript also `SessionStart`, `SessionEnd`, `CwdChanged`, `FileChanged`. Hook output can set `permissionDecision` to `allow`/`deny`/`ask`/`defer` and `updatedInput`. [hooks]
  - `mcpServers` plus in-process servers via `createSdkMcpServer({ name, tools })` and `tool(name, description, inputSchema, handler)` (Python `@tool` and `create_sdk_mcp_server`); referenced as `mcp__<server>__<tool>`. [typescript; python]
  - `agents`: programmatic subagents (`AgentDefinition` with `description`, `prompt`, `tools`, `model`, `maxTurns`, `permissionMode`, ...). Limits via `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` (default 3) and `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` (default 20). [subagents]
  - `systemPrompt`: string, or `{ type: "preset", preset: "claude_code", append?, excludeDynamicSections?, snapshot? }`.
  - `settingSources`: "Pass `[]` to disable user, project, and local settings."
  - `cwd`, `env` ("replaces the subprocess environment instead of merging with `process.env`" in TypeScript; merged in Python), `executable: 'bun' | 'deno' | 'node'`, `executableArgs`, `pathToClaudeCodeExecutable`, `stderr` callback.
  - `spawnClaudeCodeProcess`: "Custom function to spawn the Claude Code process. Use to run Claude Code in VMs, containers, or remote environments." (TypeScript)
  - `persistSession` (default `true`; TypeScript), `sessionStore`: "Mirror session transcripts to an external backend so another host can resume them."
  - `sandbox: SandboxSettings` (`enabled` default `false`, `failIfUnavailable` default `true` in the SDK, `autoAllowBashIfSandboxed`, `allowUnsandboxedCommands`, `network`, `filesystem`, `excludedCommands`). Python `sandbox` field exists; details UNVERIFIED.
  - `maxTurns`, `maxBudgetUsd`, `abortController` (TypeScript), `includePartialMessages`, `resume`, `continue`, `forkSession`, `allowedTools`, `disallowedTools`, `permissionMode`, `plugins`.
- Permission evaluation order in the SDK: hooks, deny rules, ask rules, permission mode, allow rules, then `canUseTool`. "Auto-approved tools never reach `canUseTool`." [agent-sdk/permissions, "How permissions are evaluated"]
- Hosting guidance: "1 GiB RAM, 5 GiB disk, and 1 CPU per agent is a reasonable starting point for a freshly started instance." "No top-level session timeout": bound with `maxTurns`. "Memory growth over long sessions": recycle subprocesses. Multi-tenant isolation: `settingSources: []`, `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`, per-tenant `CLAUDE_CONFIG_DIR` (optionally `CLAUDE_CODE_PROJECT_DIR_NAME`), per-tenant `cwd`, per-tenant egress rules. [hosting, "Resources", "Known limitations", "Multi-tenant isolation"]
- "The subprocess itself does not listen on the network." Inbound auth belongs at a gateway in front of the container. [hosting, "Network", "Auth and secrets"]

## 4. Session persistence and resume

Pages: https://code.claude.com/docs/en/sessions, https://code.claude.com/docs/en/cli-reference, https://code.claude.com/docs/en/headless, https://code.claude.com/docs/en/agent-sdk/hosting

- Storage: "Claude Code stores transcripts as JSONL at `~/.claude/projects/<project>/<session-id>.jsonl`, where `<project>` is your working directory path with non-alphanumeric characters replaced by `-`." Names over 200 characters are truncated and hashed. "The entry format is internal to Claude Code and changes between versions, so scripts that parse these files directly can break on any release." [sessions, "Where transcripts are stored"]
- Relocation: `CLAUDE_CONFIG_DIR` moves storage off `~/.claude`; `CLAUDE_CODE_PROJECT_DIR_NAME` (with `CLAUDE_CONFIG_DIR`, v2.1.234+) names the `<project>` directory, "This suits a host that embeds Claude Code and gives each session its own config directory." [sessions, "Name the project directory yourself"]
- Retention: `cleanupPeriodDays` changes "the 30-day retention"; `CLAUDE_CODE_TRANSCRIPT_LOCAL_GC` limits a `-p`/SDK transcript's growth; `CLAUDE_CODE_SKIP_PROMPT_HISTORY` suppresses writes in all modes; `--no-session-persistence` suppresses writes for one `-p` run. [sessions, table under "Where transcripts are stored"]
- Obtaining the ID: `claude -p ... --output-format json | jq -r '.session_id'`; then `claude -p "..." --resume "$session_id"`. "You can run the two commands from different directories: Claude Code finds the session by its ID in any project on this machine." `--resume` also accepts the absolute path to a `.jsonl` transcript. [headless, "Continue conversations"]
- `--session-id`: "Use a specific session ID for the conversation (must be a valid UUID)". `--fork-session`: new session ID on resume. `--name`/`-n` sets a resumable display name. [cli-reference]
- ID lookup order: "1. The current project directory and its git worktrees 2. Every other project on this machine." Cross-project resolution requires exactly one match. [sessions, "Resume by session ID or name"]
- `-p` sessions are hidden from the picker and from plain `claude --continue`; `claude -p --continue` includes them. A `claude -p` run "doesn't get" a generated title. [sessions, "`/loop`, `-p`, Agent SDK, and background sessions"; "Name your sessions"]
- Resume restores conversation history, model, agent, and (for terminal resume) permission mode; "`claude -p --resume` or `claude -p --continue`. Claude Code starts the run in the permission mode a new `claude -p` run would start in," except a plan-mode session under listed conditions. Flags such as `--mcp-config`, `--settings`, `--plugin-dir`, `--add-dir` are not restored and must be passed again. [sessions, "What a resumed session restores", "Permission mode on resume"]
- Interrupted turn: on resume "Claude Code leaves the interrupted turn as it is"; `CLAUDE_CODE_RESUME_INTERRUPTED_TURN=1` makes it continue the turn. [headless, "Stop a run with SIGTERM"]
- System prompt on resume: the prompt recorded on the first request is reused until compaction unless `--system-prompt-snapshot off`; in bare mode recording stays off unless `--system-prompt-snapshot on`. [cli-reference, "System prompt flags in resumed conversations"]
- Cross-host: local transcripts "None of them survive a container restart, a scale-down, or a move to a different node. To persist transcripts across hosts, configure a `SessionStore` adapter." `SessionStore` is a mirror: "the subprocess writes to local disk first, and the SDK forwards a copy of each batch to the store"; failures emit `{ type: "system", subtype: "mirror_error" }`. [hosting, "State that lives on local disk", "Session and state persistence"] No page documents cross-machine resume of a bare CLI transcript other than copying the `.jsonl` and passing its path; the docs say the cross-project search refuses "a hand-copied duplicate" when two projects hold the same ID. [sessions]
- Scripting interfaces the docs recommend over parsing JSONL: `--output-format json|stream-json`, `claude -p --resume <id>` follow-ups, hook `transcript_path`, and the Agent SDK. [sessions, "Access conversations from scripts"]

## 5. Permission modes, rules, and sandboxing

Pages: https://code.claude.com/docs/en/permission-modes, https://code.claude.com/docs/en/permissions, https://code.claude.com/docs/en/settings-reference, https://code.claude.com/docs/en/sandboxing, https://code.claude.com/docs/en/sandbox-environments

### Modes [permission-modes, "Available modes" table]

| Mode | What runs without asking | Best for |
| - | - | - |
| `default` (UI: Manual) | Reads only | Reviewing every action yourself |
| `acceptEdits` | Reads, file edits, and common filesystem commands (`mkdir`, `touch`, `mv`, `cp`, etc.) | Iterating on code you're reviewing |
| `plan` | Reads, plus classifier-approved commands when auto mode is available | Exploring before changing |
| `auto` | Everything, with background safety checks (a classifier model reviews actions) | Long tasks |
| `dontAsk` | File reads inside working directories and pre-approved tools; anything that would prompt is denied | "Locked-down CI and scripts" |
| `bypassPermissions` | Everything | "Isolated containers and VMs only" |

- "Deny rules block in every mode, including `bypassPermissions`. ... Allow rules have no effect in `bypassPermissions`." [permission-modes]
- Starting mode for `claude -p` or the SDK: "`default` in sessions that fetch feature flags. In sessions that don't, such as on a third-party provider or with telemetry off, `auto` with Claude Code v2.1.285 or later and `default` on earlier versions." The docs advise passing a mode explicitly. [permission-modes, "Which mode a session starts in"; headless, "Auto-approve tools"]
- Common CI setups from the docs: `claude -p "run the test suite" --permission-mode dontAsk --allowedTools "Bash(npm test)" "Read"`; `claude -p "<prompt>" --dangerously-skip-permissions` "Required: a container, VM, or the sandbox runtime; on Linux and macOS, run it as a non-root user". [permission-modes, "Common setups"]
- `--permission-prompts none`: "Anything that would prompt is denied unless a `PermissionRequest` hook allows it, Claude is told that nobody can approve the request and not to retry it"; removes `AskUserQuestion`; cancels unanswered MCP elicitations. [headless, "Turn off permission prompts in unattended runs"]
- In auto mode without a terminal (`-p`, SDK) critical-path removals are "denied immediately"; a `-p` run without `--permission-prompt-tool` has no prompt to fall back to: "the action doesn't run and Claude keeps working. Claude Code doesn't stop the run." [permission-modes, "Critical paths", "When auto mode falls back"]

### `bypassPermissions` / `--dangerously-skip-permissions`

- "disables permission prompts and safety checks so tool calls execute immediately, including writes to protected paths." "You can't enter `bypassPermissions` from a session you started without it enabled." [permission-modes, "Skip all checks with bypassPermissions mode"]
- "On Linux and macOS, Claude Code refuses to start in this mode when running as root or under `sudo`: `--dangerously-skip-permissions cannot be used with root/sudo privileges for security reasons`. The check is skipped automatically inside a recognized sandbox. To run autonomously in a container, use the dev container configuration, which runs Claude Code as a non-root user." [permission-modes] UNVERIFIED: what "a recognized sandbox" means; the page does not define it.
- "In non-interactive mode no dialog is shown." Interactive first use writes `skipDangerousModePermissionPrompt: true`. [permission-modes]
- Admins block it with `permissions.disableBypassPermissionsMode: "disable"`; `--restricted` also refuses it. [permission-modes; cli-reference]
- The docs never say the flag is refused for lack of a sandbox; only the root check is documented.

### Permission rules (`settings.json`)

- Keys: `permissions.allow`, `permissions.ask`, `permissions.deny`, `permissions.defaultMode`, `permissions.disableBypassPermissionsMode`, `permissions.additionalDirectories`, `permissions.blockReadsOutsideWorkingDirectories`. [settings-reference, "Permission settings"]
- "Rules are evaluated in order: deny, then ask, then allow. The first match in that order determines the outcome." Syntax `Tool` or `Tool(specifier)`; `Bash(npm run *)`; trailing ` *` is prefix matching, and "The space before `*` is important". `Read(./.env)`, `Read(~/.zshrc)`, `WebFetch(domain:example.com)`. Commands that cannot be parsed, and constructs such as `eval`, always need approval. [permissions, "Permission rule syntax"; headless, "Create a commit"; agent-sdk/secure-deployment, "Built-in security features"]

### Built-in Bash sandbox [sandboxing]

- "The Bash sandbox is a boundary that the operating system enforces around the shell commands Claude runs ... the limits apply to Bash, PowerShell, and Monitor commands and the processes they start." "The sandbox covers shell commands only. Claude's file tools, MCP servers, and hooks run outside it." "The sandbox is off by default."
- Platforms: "macOS: sandboxing uses the built-in Seatbelt framework"; "Linux and WSL2: the sandbox relies on `bubblewrap` and `socat`"; native Windows runs unsandboxed. Ubuntu 24.04+ needs an AppArmor profile for `bwrap` user namespaces. Built on the open source `@anthropic-ai/sandbox-runtime` package.
- Defaults: writes to the working directory, a per-user temp directory, and added directories; reads to "Most of the machine, including credential files"; network "No direct route out. Connections go through a proxy on your machine that checks each host against your allowed domains, which start empty"; environment variables inherited (scrub with `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` or `credentials` masking).
- Network mechanism: the proxy runs outside the sandbox and is injected through `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`; tools that ignore those variables (plain `ssh`, most database drivers) cannot connect; by default the proxy "does not terminate or inspect TLS traffic"; hostnames resolving only to loopback or link-local addresses such as `169.254.169.254` are refused.
- Settings: `sandbox.enabled`, `autoAllowBashIfSandboxed` (default `true`), `allowUnsandboxedCommands` (default `true`; `false` is "Strict sandbox mode"), `failIfUnavailable`, `excludedCommands`, `filesystem.allowWrite|denyWrite|denyRead|disabled`, `network.allowedDomains|deniedDomains|strictAllowlist|allowManagedDomainsOnly|tlsTerminate|allowUnixSockets|allowAllUnixSockets`, `credentials`, `enableWeakerNestedSandbox`. One-shot: `claude --settings '{"sandbox": {"enabled": true, "allowUnsandboxedCommands": false}}'`.
- Relationship to modes: "`/sandbox` is not a permission mode." Auto-allow mode approves sandboxed commands without prompting; `--dangerously-skip-permissions` replaces the prompt with "Nothing".
- Inside a container: "In an unprivileged container, bubblewrap can't mount a fresh `/proc` filesystem, so sandboxed commands fail with a `bwrap` error such as `Can't mount proc on /newroot/proc: Operation not permitted`. Set `enableWeakerNestedSandbox` to `true` so the sandbox bind-mounts the container's existing `/proc` instead. Only use this setting when the outer container already provides the isolation boundary you need." `docker` is listed as incompatible with the sandbox; use `excludedCommands`.
- Killed sessions (SIGKILL) can leave 0-byte read-only placeholder files at `.claude` settings paths on Linux; `claude doctor` lists them (v2.1.257+).

### Sandbox runtime (whole-process) [sandbox-environments, "Sandbox runtime"; agent-sdk/secure-deployment]

- `npx @anthropic-ai/sandbox-runtime claude` "wraps an entire process in the same Seatbelt or bubblewrap isolation that the built-in Bash sandbox uses", covering tools, hooks, and MCP servers. "The runtime is a beta research preview." Config in `~/.srt-settings.json` or `--settings`; by default it "denies network access and confines writes to a small set of built-in runtime paths". Needs write access to the project, `~/.claude`, `~/.claude.json`, and `/tmp` (or `CLAUDE_CODE_TMPDIR`); needs `api.anthropic.com` plus `claude.ai` and `platform.claude.com` for OAuth (API-key runs can drop the last two). On Linux "the runtime applies write grants only to paths that already exist" and builds its deny list once at launch.
- Known weaknesses the docs state: shared host kernel; "No TLS inspection ... Code running inside the sandbox can potentially use domain fronting or similar techniques to reach hosts outside the allowlist."

## 6. Does it need a PTY?

- Headless `-p` runs are documented as pipe-driven: stdin is read for the prompt, stdout carries text or JSON, and "When stderr is a terminal" / "only when stdout isn't a terminal" branches exist for the background-wait notice, which shows the mode is designed for non-terminal stdio. [headless, "Pipe data through Claude", "Background tasks at exit"]
- The Agent SDK "talks to it over stdio" and the subprocess "does not listen on the network". [hosting]
- Interactive mode (no `-p`) needs a terminal: "An interactive session needs a terminal to read your keystrokes from ... macOS and Linux: Claude Code reads your keystrokes from `/dev/tty` and starts the session, with any piped text as your first prompt. You see the message when `/dev/tty` can't be opened." On Windows it "exits with code 1". Before v2.1.287 it failed with `Raw mode is not supported`. [errors, "Claude Code can't read the keyboard here"]
- "Bare `claude` needs stdout to be a terminal to start the interactive UI. When stdout is redirected, or the console isn't a real terminal ... `claude` runs non-interactively instead. That is the same mode as `claude -p`, which requires a prompt." [errors, "Input must be provided when using `--print`"]
- `claude agents` (agent view) "requires an interactive terminal". `--exec` runs shell jobs "PTY-backed". [cli-reference]
- UNVERIFIED: no page states in so many words "`-p` does not require a TTY". My read, from the stdio-driven SDK, the pipe examples, and the error pages, is that `-p` runs without a PTY and only the interactive UI needs one.

## 7. Behaviour inside containers and microVMs

Pages: https://code.claude.com/docs/en/devcontainer, https://code.claude.com/docs/en/sandbox-environments, https://code.claude.com/docs/en/agent-sdk/secure-deployment, https://code.claude.com/docs/en/agent-sdk/hosting, https://code.claude.com/docs/en/setup, https://code.claude.com/docs/en/network-config

- Isolation comparison table: Sandboxed Bash tool (Bash only, no Docker), Sandbox runtime (whole process, no Docker), Dev container (Docker), Custom container (Docker), Virtual machine, Cloud sessions. "Every other approach in the table puts the whole Claude Code process inside the isolation boundary." [sandbox-environments, "Compare sandboxing approaches"]
- Recommendation for unattended runs: "Always run `--dangerously-skip-permissions` sessions inside a container, a VM, or the sandbox runtime, so that file tools, MCP servers, and hooks are also inside the boundary. On Linux and macOS, Claude Code refuses to start with this flag when running as root, so run the container, VM, or sandbox runtime as a non-root user." Auto mode: an isolation boundary "is not required the way it is for `--dangerously-skip-permissions`" but adds defense in depth. [sandbox-environments, "How isolation relates to permission modes"]
- Custom container: "You can run Claude Code in any Docker or OCI container image with your own network policies, mounted volumes, and seccomp profiles." Layering the Bash sandbox inside needs `enableWeakerNestedSandbox`. [sandbox-environments, "Custom container"]
- Virtual machine / microVM: "Options include cloud instances, local hypervisors, and microVMs such as Firecracker." Docker Sandboxes "provides a microVM with its own Docker daemon". [sandbox-environments, "Virtual machine"] The secure-deployment page rates isolation strength (Sandbox runtime: Good; Docker: Setup dependent; gVisor: Excellent; VMs (Firecracker, QEMU): Excellent) and describes a Firecracker pattern where "the agent VM has no external network interface. Instead, it communicates through `vsock` ... to a proxy on the host". It cites Firecracker boot "in under 125ms with less than 5 MiB memory overhead" and gVisor overheads ("Simple syscalls ~2x slower", "File I/O intensive up to 10-200x slower"). [agent-sdk/secure-deployment, "Isolation technologies"] UNVERIFIED: any Claude Code behaviour specific to microVMs. The docs treat a microVM as an ordinary Linux host.
- Hardened `docker run` example from the docs: `--cap-drop ALL --security-opt no-new-privileges --security-opt seccomp=... --read-only --tmpfs /tmp:rw,noexec,nosuid,size=100m --tmpfs /home/agent:rw,noexec,nosuid,size=500m --network none --memory 2g --cpus 2 --pids-limit 100 --user 1000:1000 -v /path/to/code:/workspace:ro -v /var/run/proxy.sock:/var/run/proxy.sock:ro`, with egress only through a Unix-socket proxy on the host. [agent-sdk/secure-deployment, "Containers"]
- Credential proxying: `ANTHROPIC_BASE_URL` routes sampling requests to a plaintext HTTP proxy that can inject the key; `HTTP_PROXY`/`HTTPS_PROXY` give only a CONNECT tunnel. "Node.js `fetch()` ignores these variables by default; in Node 24+ you can set `NODE_USE_ENV_PROXY=1`." [agent-sdk/secure-deployment, "Credential management"]
- Dev container reference: feature `ghcr.io/anthropics/devcontainer-features/claude-code:1.0`; "The Claude Code feature installs Node.js itself when the base image doesn't provide it"; the reference `init-firewall.sh` needs `NET_ADMIN` and `NET_RAW` but "The firewall script and these capabilities are not required for Claude Code itself." Persist login by mounting a volume at `~/.claude` and setting `CLAUDE_CONFIG_DIR` to it, because `~/.claude.json` (OAuth account, trust) lives outside `~/.claude`. Pin a version with `npm install -g @anthropic-ai/claude-code@X.Y.Z` and `DISABLE_AUTOUPDATER=1`. Warning: with `--dangerously-skip-permissions`, "dev containers do not prevent a malicious project from exfiltrating anything accessible inside the container, including the Claude Code credentials stored in `~/.claude`." [devcontainer]
- Managed policy in a container: `/etc/claude-code/managed-settings.json` on Linux is highest precedence. [devcontainer, "Enforce organization policy"]
- Container env vars the docs recommend: `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` (disables auto-updates, telemetry, error reporting, feedback, release notes, availability checks, and feature-flag fetching; "Setting it to `0` or `false` still disables this traffic"), `DISABLE_AUTOUPDATER=1` (background check only), `DISABLE_UPDATES=1` (also blocks `claude update`/`claude install`), `DISABLE_TELEMETRY`, `DISABLE_ERROR_REPORTING`. [env-vars; devcontainer; setup]
- Install and runtime: system requirements "macOS 13.0+ ... Ubuntu 20.04+, Debian 10+, Alpine Linux 3.19+", "4 GB+ RAM, x64 or ARM64 processor". Native installer `curl -fsSL https://claude.ai/install.sh | bash` (accepts `stable`, `latest`, or a version); the npm package "downloads a native binary that doesn't use your Node.js at runtime" and "The installed `claude` binary does not itself invoke Node." Signed apt/dnf/apk repositories exist. Alpine needs `bash`, `curl`, `libgcc`, `libstdc++`, `ripgrep` and `USE_BUILTIN_RIPGREP=0`. Native installs "automatically update in the background". [setup]
- Network allowlist (required): `api.anthropic.com`; `claude.ai`, `claude.com`, `platform.claude.com` for account auth and OAuth token exchange/refresh; `downloads.claude.ai` for installer and updates; `registry.npmjs.org` for npm installs and `npx` MCP servers; optional telemetry to `http-intake.logs.us5.datadoghq.com` and `browser-intake-us5-datadoghq.com`. On Bedrock/Vertex/Foundry, model traffic goes to the provider but WebFetch "still calls `api.anthropic.com` for its domain safety check unless you set `skipWebFetchPreflight: true`". Proxies: `HTTPS_PROXY`/`HTTP_PROXY`/`NO_PROXY`; "Claude Code does not support SOCKS proxies"; custom CA via `NODE_EXTRA_CA_CERTS`; mTLS via `CLAUDE_CODE_CLIENT_CERT`/`_KEY`. [network-config, "Network access requirements", "Proxy configuration"]
- Streaming watchdogs abort stalled model responses (first-byte deadline 180 s on the direct API; event/byte watchdogs 180-300 s). [network-config, "Streaming idle watchdogs"]
- Anthropic's own cloud sessions run in "an isolated, Anthropic-managed virtual machine" with a network proxy enforcing an allowlist; the environment is Ubuntu 24.04 x86_64 with 4 vCPUs, 16 GB RAM, 30 GB disk (per the subagent's read of cloud-environments; I did not fetch that page myself). [sandbox-environments, "Cloud sessions"; cloud-environments]

## 8. Authentication for an automated environment

Pages: https://code.claude.com/docs/en/authentication, https://code.claude.com/docs/en/env-vars, https://code.claude.com/docs/en/headless

Precedence when several credentials exist [authentication, "Authentication precedence"]:
1. Cloud provider credentials when `CLAUDE_CODE_USE_BEDROCK`, `CLAUDE_CODE_USE_VERTEX`, or `CLAUDE_CODE_USE_FOUNDRY` is set.
2. `ANTHROPIC_AUTH_TOKEN` (sent as `Authorization: Bearer`; for LLM gateways).
3. `ANTHROPIC_API_KEY` (sent as `X-Api-Key`). "In non-interactive mode (`-p`), the key is always used when present."
4. `apiKeyHelper` script output (for rotating credentials; re-run every five minutes by default or `CLAUDE_CODE_API_KEY_HELPER_TTL_MS`, and on 401/403).
5. `CLAUDE_CODE_OAUTH_TOKEN`: "A long-lived OAuth token generated by `claude setup-token`. Use this for CI pipelines and scripts where browser login isn't available."
6. Anthropic profile / Workload Identity Federation credentials.
7. Subscription OAuth from `/login`.

- `claude setup-token`: "generate a one-year OAuth token"; "It does not save the token anywhere"; "requires a Pro, Max, Team, or Enterprise plan"; "It can only make model requests". "Bare mode does not read `CLAUDE_CODE_OAUTH_TOKEN`. If your script passes `--bare`, authenticate with `ANTHROPIC_API_KEY` or an `apiKeyHelper` instead." [authentication, "Generate a long-lived token"]
- Third-party products: "Anthropic does not allow third party developers to offer claude.ai login or rate limits for their products, including agents built on the Claude Agent SDK." [agent-sdk/overview]
- Browser login in containers: "If your browser shows a login code instead of redirecting back after you sign in, paste it into the terminal ... common in WSL2, SSH sessions, and containers." `claude auth login` has `--email`, `--sso`, `--console`; `claude auth status` prints JSON with `authMethod` (`none`, `claude.ai`, `oauth_token`, `api_key`, `api_key_helper`, `third_party`) and exits 1 when not logged in. [authentication; cli-reference] UNVERIFIED: whether `claude auth login` completes with no browser at all.
- Storage: Linux `~/.claude/.credentials.json` mode `0600`; macOS Keychain with `.credentials.json` fallback; with `CLAUDE_CONFIG_DIR` the file moves under that directory. `~/.claude.json` separately holds the OAuth account, personal MCP servers, and per-project trust. [authentication, "Credential management"; devcontainer]
- Providers: Bedrock (`CLAUDE_CODE_USE_BEDROCK=1`, `AWS_REGION`, AWS SDK credential chain or `AWS_BEARER_TOKEN_BEDROCK`); Google Cloud's Agent Platform, formerly Vertex AI (`CLAUDE_CODE_USE_VERTEX=1`, `CLOUD_ML_REGION`, `ANTHROPIC_VERTEX_PROJECT_ID`, Application Default Credentials); Microsoft Foundry (`CLAUDE_CODE_USE_FOUNDRY=1`, `ANTHROPIC_FOUNDRY_RESOURCE`, `ANTHROPIC_FOUNDRY_API_KEY` or Entra ID or `ANTHROPIC_FOUNDRY_AUTH_TOKEN`). [amazon-bedrock; google-vertex-ai; microsoft-foundry, per the subagent's reads]
- Gateway: `ANTHROPIC_BASE_URL` overrides the endpoint; `ANTHROPIC_AUTH_TOKEN` for bearer auth; `ANTHROPIC_CUSTOM_HEADERS` in `Name: Value` form (v2.1.227+). Setting `ANTHROPIC_AUTH_TOKEN` "turns off subscription login for that session." [env-vars; gateways]
- Managed restrictions: `forceLoginMethod`, `forceLoginOrgUUID` (blocks `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `apiKeyHelper` at startup when set), `allowedProviders` (v2.1.285+). [authentication, "Restrict login to your organization"]
- Agent SDK: "the subprocess reads `ANTHROPIC_API_KEY` from its environment. Supply it from your secret manager, or set `ANTHROPIC_BASE_URL` to route model calls through a proxy that injects the key outside the container." The SDK does not load `.env` files. [hosting, "Auth and secrets"; quickstart]

## Unverified

- That the CLI `--output-format json` object matches the SDK `SDKResultMessage` field for field.
- That the CLI's `--input-format stream-json` stdin lines use the SDK's `{"type":"user","message":{...}}` shape. Inferred from the stdio transport and control-protocol references; not stated on a CLI page.
- Whether `--verbose` is mandatory for `stream-json` output.
- An explicit statement that `-p` needs no TTY. Inferred (section 6).
- What "a recognized sandbox" means for the root check skip under `--dangerously-skip-permissions`.
- Python SDK `sandbox` option details and a Python `abortController` equivalent (only `interrupt()` is documented).
- Field lists for `hook_*`, `prompt_suggestion`, `compact_boundary`, `informational`, and CLI `user` stream messages.
- Any microVM-specific Claude Code behaviour; whether the CLI process runs as root inside Anthropic's cloud sessions.
- Disk requirement for the CLI itself; `apiKeyHelper` timeout.
- Whether `claude auth login` completes with no browser available.
- Contents of the reference Dockerfile on GitHub (not a docs-domain page; not fetched).
- Pages read by subagents but not by me directly: cloud-environments, amazon-bedrock, google-vertex-ai, microsoft-foundry, gateways, agent-sdk/python, agent-sdk/hooks, agent-sdk/subagents, agent-sdk/sessions, agent-sdk/permissions, agent-sdk/structured-outputs, agent-sdk/cost-tracking, settings-reference, permissions, github-actions.

## Sources

- https://code.claude.com/docs/en/headless
- https://code.claude.com/docs/en/cli-reference
- https://code.claude.com/docs/en/errors
- https://code.claude.com/docs/en/sessions
- https://code.claude.com/docs/en/permission-modes
- https://code.claude.com/docs/en/permissions
- https://code.claude.com/docs/en/settings-reference
- https://code.claude.com/docs/en/sandboxing
- https://code.claude.com/docs/en/sandbox-environments
- https://code.claude.com/docs/en/devcontainer
- https://code.claude.com/docs/en/setup
- https://code.claude.com/docs/en/network-config
- https://code.claude.com/docs/en/env-vars
- https://code.claude.com/docs/en/authentication
- https://code.claude.com/docs/en/cloud-environments
- https://code.claude.com/docs/en/amazon-bedrock, /google-vertex-ai, /microsoft-foundry, /gateways
- https://code.claude.com/docs/en/agent-sdk/overview
- https://code.claude.com/docs/en/agent-sdk/quickstart
- https://code.claude.com/docs/en/agent-sdk/hosting
- https://code.claude.com/docs/en/agent-sdk/secure-deployment
- https://code.claude.com/docs/en/agent-sdk/typescript
- https://code.claude.com/docs/en/agent-sdk/python
- https://code.claude.com/docs/en/agent-sdk/streaming-input
- https://code.claude.com/docs/en/agent-sdk/permissions, /hooks, /subagents, /sessions, /structured-outputs, /cost-tracking, /migration-guide
