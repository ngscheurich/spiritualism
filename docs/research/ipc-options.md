# Research: client-server IPC options

Ticket: `.tracker/v1-spec/issues/07-research-ipc-options.md`
Researched: 2026-10-11
Sources: protocol specs (jsonrpc.org, IETF RFC 6455, WHATWG HTML, gRPC `doc/`, Cap'n Proto, msgpack-rpc, connectrpc.com), official library docs (nodejs.org, bun.sh, pkg.go.dev, docs.rs, docs.python.org, learn.microsoft.com), and comparable tools' own docs (Docker Engine API OpenAPI v1.56, tmux(1), LSP 3.17, MCP 2025-06-18, Neovim `api.txt`, containerd ttrpc). Nothing was run. Every claim cites the page it was read on; quotes are as the fetch tool returned them. Items no source stated are in "Unverified" at the end and marked inline.

Scope note: the question is a local server that owns long-lived agent processes and PTYs, with CLI/TUI clients attaching. Three concerns dominate: (a) how messages are framed on a byte stream, (b) whether the server can push to the client without being asked, (c) whether a raw byte channel for PTY I/O plus an out-of-band resize call fits the protocol. This note lays out trade-offs. It recommends nothing.

## Summary

1. JSON-RPC 2.0 defines no framing and is "transport agnostic". Two shipped conventions exist: LSP's `Content-Length` header block and MCP's newline-delimited messages. Notifications are built in and flow either way (LSP and MCP use them server-to-client). Nothing in the spec addresses binary PTY bytes; they would need base64 or a side channel. [jsonrpc-spec; lsp-base; mcp-transports]
2. gRPC requires HTTP/2 and gives four call shapes including bidirectional streaming with per-stream ordering, deadlines, and cancellation. Its naming doc supports `unix:` and `unix-abstract:` on "Unix systems only" and does not mention Windows named pipes. Official libraries exist for Node, Go, Python, Rust and nine other languages; Bun's `Bun.serve` states gRPC trailers are unsupported. [grpc-http2; grpc-concepts; grpc-naming; grpc-languages; bun-http]
3. WebSocket (RFC 6455) is two-way over one TCP connection with text and binary frames, 7/16/64-bit length prefixes, mandatory client-to-server masking, and ping/pong. SSE is server-push only, UTF-8 only, with automatic reconnection and `Last-Event-ID`. Docker exposes a WebSocket attach endpoint next to its hijacked-HTTP attach. [rfc6455; sse-spec; docker-openapi]
4. Docker's attach "hijacks the HTTP connection" and then carries "raw, bidirectional" bytes; with a TTY the stream is "simply the raw data from the process PTY", and resize is a separate `POST /containers/{id}/resize?h=&w=`. tmux's control mode uses newline-delimited commands with `%begin`/`%end` blocks and `%output pane-id value` notifications, with non-printables escaped as octal. [docker-openapi; tmux]
5. Portability: Node's `net` does Unix sockets and Windows named pipes behind one `path` API; Go's `net` has no named-pipe support (Microsoft's `go-winio` adds it); tokio has `UnixStream` (Unix only) and a separate `windows::named_pipe` module; Python asyncio's Unix-socket APIs are "Availability: Unix" and `multiprocessing.connection` adds `AF_PIPE`. Windows 10 build 17063+ has `AF_UNIX` for `SOCK_STREAM` only, with "no support for ancillary data" (so no fd passing). [node-net; go-net; go-winio; tokio-uds; tokio-pipe; py-asyncio; py-mp; win-afunix]

## 1. Transport layer: Unix domain sockets, named pipes, localhost TCP

### Unix domain sockets (Linux/macOS)

- Linux `unix(7)`: "On Linux, sun_path is 108 bytes in size". Node's docs give the practical limits as "107 bytes on Linux and 103 bytes on macOS". [unix7; node-net]
- Permissions: "In the Linux implementation, pathname sockets honor the permissions of the directory they are in." and "On Linux, connecting to a stream socket object requires write permission on that socket". The same page warns "POSIX does not make any statement about the effect of the permissions on a socket file, and on some systems (e.g., older BSDs), the socket permissions are ignored. Portable programs should not rely on this feature for security." [unix7]
- Peer identity: `SO_PEERCRED` "returns the credentials of the peer process connected to this socket." [unix7]
- Fd passing: `SCM_RIGHTS` lets a process "Send or receive a set of open file descriptors from another process." This is the one mechanism in this survey that could hand a client the PTY fd itself rather than proxying bytes. Go exposes the out-of-band data via `UnixConn.ReadMsgUnix`/`WriteMsgUnix` ("copying the payload into b and the associated out-of-band data into oob"); the Go doc does not mention file descriptors by name. [unix7; go-net]
- Abstract namespace (Linux only): "Abstract sockets automatically disappear when all open references to the socket are closed." and "Socket permissions have no meaning for abstract sockets". gRPC's naming doc repeats: "No permissions will apply to the socket - any process/user may access the socket." Node and Bun both support it by prefixing the path with `\0`. [unix7; grpc-naming; node-net; bun-http]
- Lifecycle: "a Unix domain socket will be visible in the file system and will persist until unlinked"; if the creating process crashes "the user will need to remove it". Python's `start_unix_server` has a `cleanup_socket` flag (3.13+) that removes the file on close. [node-net; py-asyncio]
- How comparable tools use them: tmux's "server and each client are separate processes which communicate through a socket in /tmp", under `TMUX_TMPDIR` or `/tmp`, in a `tmux-UID` directory that "must not be world readable, writable or executable". Docker's daemon "By default ... listens on `unix:///var/run/docker.sock` to allow only local connections by the root user." Neovim "creates a default RPC socket at |startup|, given by |v:servername|" and notes "localhost TCP sockets are generally less secure than named pipes". VS Code's LSP client generates a random socket path under `XDG_RUNTIME_DIR` or the OS temp dir and caps total length at 107 (Linux) / 102 (macOS). [tmux; dockerd; nvim-api; vscode-jsonrpc-node]

### Windows named pipes

- Microsoft: "A named pipe is a named, one-way or duplex pipe for communication between the pipe server and one or more pipe clients. All instances of a named pipe share the same pipe name, but each instance has its own buffers and handles". Server side is `CreateNamedPipe` + `ConnectNamedPipe`; clients use `CreateFile`. Warning: "If the server service is running, all named pipes are accessible remotely. If you intend to use a named pipe locally only, deny access to NT AUTHORITY\NETWORK". [win-pipes]
- Node: "On Windows, the local domain is implemented using a named pipe. The path must refer to an entry in `\\?\pipe\` or `\\.\pipe\`." Pipes "will not persist. They are removed when the last reference to them is closed." VS Code's LSP client builds names as `\\.\pipe\lsp-<32 hex>-sock`. [node-net; vscode-jsonrpc-node]
- Docker's CLI default on Windows is `npipe:////./pipe/docker_engine`. "Starting with Docker Engine 29.5, you can configure `dockerd` on Windows to listen on a Unix socket"; "The default Windows endpoint remains the `npipe` named pipe." [docker-cli; docker-daemon]

### AF_UNIX on Windows

- "Beginning in Insider Build 17063, you'll be able to use the unix socket (AF_UNIX) address family on Windows". "Currently, the support only exists for the stream (SOCK_STREAM) socket type". "There is no support for ancillary data in the Windows unix socket implementation." `socketpair` "is not supported in Winsock 2.0." The post is dated December 19, 2017. [win-afunix]
- Consequence for this design: a Unix-socket-only server could in principle run on Windows, but fd passing (`SCM_RIGHTS`) would not, and none of the Node/Go/tokio/asyncio docs read here say their Unix-socket APIs work on Windows (tokio's `UnixStream` is "Available on Unix and crate feature net only"; asyncio's is "Availability: Unix"). [tokio-uds; py-asyncio]

### Localhost TCP

- Docker's client "defaults to connecting to ... `tcp://127.0.0.1:2376` on Windows" (dockerd reference). VS Code's LSP socket transport listens on `127.0.0.1` at a chosen port and passes `--socket=<port>` to the server. Neovim: `nvim --listen 127.0.0.1:6666`. [dockerd; vscode-client; nvim-api]
- MCP's HTTP guidance for local servers: "Servers MUST validate the `Origin` header on all incoming connections to prevent DNS rebinding attacks" and "When running locally, servers SHOULD bind only to localhost (127.0.0.1) rather than all network interfaces (0.0.0.0)". This applies to any browser-reachable localhost HTTP/WebSocket endpoint. [mcp-transports]

### Windows PTY

- ConPTY: the host creates "a pair of synchronous communication channels" (pipes), calls `CreatePseudoConsole`, and the hosted process writes VT output to one pipe and reads input from the other. "Threads could also be used to relay the information from the pseudoconsole channels out to a different channel or device including a network to remote information to another process or machine". Resize is `ResizePseudoConsole`. The doc warns that servicing both channels on one thread "may result in a deadlock". [conpty]
- Relevance: on Windows the server's PTY is two pipe handles, not one fd, so "pass the PTY fd to the client" is not a portable option; proxying bytes through the IPC channel is.

## 2. Protocol-by-protocol

Legend for each entry: framing / bidirectional notifications / streaming / PTY attach / libraries / portability.

### 2.1 JSON-RPC 2.0 over a socket or pipe

- Framing: the spec defines none. "It is transport agnostic in that the concepts can be used within the same process, over sockets, over http". Two shipped conventions:
  - LSP: a header part with `Content-Length` ("This header is required") and optional `Content-Type` (default `application/vscode-jsonrpc; charset=utf-8`); headers are ASCII, content is UTF-8, "the only encoding supported right now". [lsp-base]
  - MCP stdio: "Messages are delimited by newlines, and MUST NOT contain embedded newlines." MCP also says "JSON-RPC messages MUST be UTF-8 encoded." [mcp-transports]
- Notifications: "A Notification is a Request object without an "id" member." and "The Server MUST NOT reply to a Notification". The spec names roles Client and Server but LSP sends `$/progress` "from the server to the client" and MCP's server "MAY send JSON-RPC requests and notifications" to the client. Batch: "the Client MAY send an Array filled with Request objects." [jsonrpc-spec; lsp-base; mcp-transports]
- Streaming: no stream primitive. LSP models progress as repeated `$/progress` notifications "against a token"; cancellation is a `$/cancelRequest` notification. Unknown `$/` notifications may be ignored. [lsp-base]
- PTY attach: JSON is text; PTY output is bytes. The spec gives no binary type (unverified inference: base64 inside a notification, or a second raw connection, are the usual answers; no source read here prescribes one). Neovim shows the shape of a text-RPC terminal: MessagePack-RPC events plus `--embed` on stdio (see 2.5). [jsonrpc-spec; nvim-starting]
- Libraries:
  - TypeScript/Node: `vscode-jsonrpc` "implements the base messaging protocol spoken between a VSCode language server and a VSCode language client" and "can also be used standalone to establish a JSON-RPC channel". Its Node entry has `createClientPipeTransport`/`createServerPipeTransport` (Unix socket or Windows named pipe, name from `generateRandomPipeName()`) and `createClientSocketTransport` (127.0.0.1 + port). [vscode-jsonrpc; vscode-jsonrpc-node]
  - Go: the standard library's `net/rpc/jsonrpc` "implements a JSON-RPC 1.0 ClientCodec and ServerCodec"; it points elsewhere for 2.0. [go-jsonrpc]
  - Rust: `jsonrpsee` is a "JSON-RPC client/server framework" with `http-client` and `ws-client` features; its item list includes `SubscriptionSink` ("A handle to an active subscription"). The crate page read here does not name a Unix-socket transport. [jsonrpsee]
  - Python: no standard-library JSON-RPC 2.0 implementation was found (unverified: absence inferred from not finding one, not from a statement).
  - Bun: not checked separately; `vscode-jsonrpc` on Bun is unverified.
- Portability: inherits the transport's. The LSP client's pipe transport picks `\\.\pipe\...` on win32 and a Unix socket elsewhere behind one API. [vscode-jsonrpc-node]

### 2.2 gRPC

- Framing: "carried over HTTP2 framing"; each message is a Length-Prefixed-Message with a 1-byte Compressed-Flag and a 4-byte big-endian length. "DATA frame boundaries have no relation to Length-Prefixed-Message boundaries." End of request stream is `END_STREAM` on a DATA frame; end of response is `END_STREAM` on the Trailers HEADERS frame. [grpc-http2]
- Bidirectional: four call shapes; in bidirectional streaming "both sides send a sequence of messages using a read-write stream", "The two streams operate independently", "The order of messages in each stream is preserved." "Either the client or the server can cancel an RPC at any time." Deadlines end a call with `DEADLINE_EXCEEDED`. Server-initiated calls do not exist; server push is modelled as a long-lived server-streaming RPC (inference from the four shapes; the concepts page does not state this limitation in those words). [grpc-concepts]
- Streaming: native. The performance guide says "Use streaming RPCs when handling a long-lived logical flow of data" and that each connection "usually has a limit on the number of concurrent streams". [grpc-perf]
- PTY attach: a bidi stream of `bytes` messages fits; resize can be a field in the same stream or a separate unary call. Docker's `/session` endpoint upgrades the hijacked connection to h2c so "the client to expose gPRC services on that connection" (the endpoint is marked deprecated in favour of gRPC on the listening socket). [docker-openapi]
- Transports and names: `unix:path`, `unix:///absolute_path`, `unix-abstract:abstract_path` are "Unix systems only"; `vsock:cid:port` is "Linux systems only"; the page does not mention Windows named pipes. grpc-go's `WithContextDialer` sets a custom dialer, and "To bypass name resolution and cause the target string to be passed directly to the dialer ... use the "passthrough" resolver", so a Windows pipe dialer is possible in Go (unverified for other languages). [grpc-naming; grpc-go]
- Libraries: grpc.io lists C#/.NET, C++, Dart, Go, Java, Kotlin, Node, Objective-C, PHP, Python, Ruby, Rust, Swift. The Rust page links the `grpc/grpc-rust` repo, whose README is tonic's ("a gRPC over HTTP/2 implementation focused on high performance, interoperability, and flexibility"); tonic's `uds` example serves over `UnixListener` + `serve_with_incoming` and is `#[cfg(unix)]` ("The `uds` example only works on unix systems!"). `@grpc/grpc-js` is "Pure JavaScript Code" (the C-based `grpc` package is not) and registers a `unix` resolver (`registerResolver('unix', UdsResolver)`). Python's `grpcio` is on the official list; its Unix-socket support follows the C-core naming doc ("Most gRPC implementations support" the `unix:` forms). [grpc-languages; grpc-rust; tonic-uds; grpc-js-compare; grpc-js-uds; grpc-naming]
- Bun: `Bun.serve` states "WebSockets over HTTP/2, server push, and response trailers (needed by gRPC) are not supported." Running `@grpc/grpc-js` under Bun was not checked (unverified). [bun-http]
- Portability: HTTP/2 over any stream the library can dial. Node's `Http2Server` "Extends: net.Server", so it can listen on an IPC path like any `net.Server` (inference from the two Node pages; the http2 page was not read for an explicit IPC example). [node-http2; node-net]

### 2.3 HTTP on localhost with SSE (server push) and/or WebSocket

HTTP+SSE:

- SSE exists "To enable servers to push data to web pages over HTTP"; MIME type `text/event-stream`; fields `event`, `data`, `id`, `retry`; a blank line dispatches an event. "Event streams are always decoded as UTF-8." Clients "will reconnect if the connection is closed", send `Last-Event-ID` on reconnect, and stop on HTTP 204. [sse-spec]
- Direction: push only. Client-to-server traffic needs separate requests. MCP's Streamable HTTP shows the pattern: "Every JSON-RPC message sent from the client MUST be a new HTTP POST request"; a POSTed request is answered either as `application/json` or as an SSE stream; a client "MAY issue an HTTP GET" to open a server-to-client SSE stream; servers "MAY attach an `id` field to their SSE events" for resumption. [mcp-transports]
- PTY attach: text-only framing (UTF-8) with no binary frames, plus one direction only. Not a fit for raw PTY bytes without encoding and a second channel (inference).
- Libraries: any HTTP server; Node ships a browser-compatible `EventSource` client (experimental, `--experimental-eventsource`, v22.3.0/v20.18.0). Bun's and other runtimes' SSE client status not checked. [node-globals]

WebSocket (RFC 6455):

- Framing: "an opening handshake followed by basic message framing, layered over TCP"; the handshake "is an HTTP Upgrade request". Frames carry FIN, opcode, 7/16/64-bit payload length ("if 0-125, that is the payload length", 126 → 2 bytes, 127 → 8 bytes). "a client MUST mask all frames that it sends to the server". Text frames are UTF-8; binary frames are "arbitrary binary data whose interpretation is solely up to the application layer." Fragmentation, Ping/Pong ("Upon receipt of a Ping frame, an endpoint MUST send a Pong frame"), and Close with a 2-byte status code are specified. [rfc6455]
- Bidirectional: yes, message-oriented, either side sends at will. [rfc6455]
- Streaming: a message stream; no request/response correlation or cancellation semantics in the RFC (any RPC layer such as JSON-RPC rides on top; jsonrpsee's `ws-client` is one example). [rfc6455; jsonrpsee]
- PTY attach: binary frames carry PTY bytes natively; resize is an application message. Docker provides `GET /containers/{id}/attach/ws` ("Attach to a container via a websocket") alongside its hijacked attach. [docker-openapi]
- Libraries:
  - Node: global `WebSocket` is "A browser-compatible implementation" (client), added v21.0.0/v20.10.0, unflagged since v22.0.0; the Node docs read here state no server implementation (so a server needs a package; `ws` is referenced by Bun's benchmark, not verified further). [node-globals; bun-ws]
  - Bun: "`Bun.serve()` supports server-side WebSockets, with on-the-fly compression, TLS support, and a Bun-native publish-subscribe API"; `server.upgrade(req)`; handlers `open`/`message`/`close`/`drain`/`error`; `ws.send` returns `-1` on backpressure, `0` dropped, `1+` bytes sent; built on uWebSockets. `server.upgrade()` "only works on HTTP/1.1 requests." Bun also implements the client `WebSocket` class. `Bun.serve` accepts `unix: "/path"` (unix option + WebSocket upgrade together is unverified). [bun-ws; bun-http]
  - Go: `golang.org/x/net/websocket` "currently lacks some features" and recommends `gorilla/websocket` or `coder/websocket`; `coder/websocket` "implements the RFC 6455 WebSocket protocol" with `Accept(w, r, opts)` on `net/http` and `Dial` via `net/http.Client` (Go ≥ 1.12). [go-xnet-ws; coder-ws]
  - Rust: `tokio-tungstenite` is the "Tokio binding for Tungstenite" with `accept_async` and `connect_async`. [tokio-tungstenite]
  - Python: `websockets` "is a library for building WebSocket servers and clients in Python" on asyncio. [py-websockets]
- Portability: WebSocket over a Unix socket or named pipe is library-dependent; only the TCP/HTTP form is specified. Browser clients can only reach TCP localhost.

### 2.4 Hijacked HTTP / raw stream (the Docker pattern)

- `POST /containers/{id}/attach`: "This endpoint hijacks the HTTP connection to transport `stdin`, `stdout`, and `stderr` on the same socket." Response `HTTP/1.1 200 OK` + `Content-Type: application/vnd.docker.raw-stream`, then "the TCP connection can now be used for raw, bidirectional communication". Clients may send `Upgrade: tcp` / `Connection: Upgrade` and get `101 UPGRADED` "To hint potential proxies". [docker-openapi]
- Framing without a TTY: `application/vnd.docker.multiplexed-stream`, 8-byte header `{STREAM_TYPE, 0, 0, 0, SIZE1..SIZE4}` with type 0/1/2 = stdin/stdout/stderr and a big-endian uint32 payload size. With a TTY: "the stream is not multiplexed. The data exchanged over the hijacked connection is simply the raw data from the process PTY and client's `stdin`." [docker-openapi]
- Resize is out of band: `POST /containers/{id}/resize` with query `h` and `w` ("Height of the TTY session in characters"). The attach endpoint notes "You can attach to the same container multiple times and you can reattach to containers that have been detached." [docker-openapi]
- Transport: `unix:///var/run/docker.sock` (Linux/macOS), `npipe:////./pipe/docker_engine` (Windows), `tcp://`, `fd://`. [docker-cli; dockerd]
- Trade-off visible here: one HTTP API for control, plus a per-attach connection that leaves HTTP entirely. The protocol is trivial but is Docker-specific, not a standard, and proxies need the Upgrade hint.

### 2.5 MessagePack-RPC (and Neovim's use of it)

- Spec: three message types, `[type, msgid, method, params]` (Request), `[type, msgid, error, result]` (Response), `[type, method, params]` (Notification). "The server implementations don't need to send the reply in the order of the received requests." "The implementation should support multiple transports like TCP, UDP, or UNIX domain sockets, if possible." MessagePack itself "is an object serialization specification like JSON." Binary is a native MessagePack type (unverified against the msgpack spec page; the fetch returned only the opening line). [msgpack-rpc; msgpack]
- Framing: MessagePack values are self-delimiting on the wire, so no outer framing is specified or needed (inference; the rpc spec page does not say this in words).
- Neovim: "Nvim implements the MessagePack-RPC protocol with these extra (out-of-spec) constraints": "Responses must be given in reverse order of requests (like "unwinding a stack")." and "Nvim processes all messages (requests and notifications) in the order they are received." Transports: a default socket at `v:servername`; `--listen {addr}` "Start |RPC| server on pipe or TCP address {addr}"; `--embed` "Use stdin/stdout as a msgpack-RPC channel"; "RPC channels can also be opened by other processes connecting to TCP/IP sockets or named pipes". Events: "Clients can subscribe to |ui-events|, |api-buffer-updates|, etc." and "API event names are prefixed with "nvim_" and suffixed with "_event"." [nvim-api; nvim-starting]
- Libraries: not surveyed per language; Neovim's clients exist but were not checked (unverified).
- Portability: Neovim uses "pipe or TCP"; the docs read do not name Windows named pipes explicitly. [nvim-starting]

### 2.6 Cap'n Proto RPC

- Model: "Interface references – or, as we more commonly call them, capabilities – are a first-class type." Promise pipelining: "The promise actually has methods corresponding to whatever methods the final result would have". "Cap'n Proto does not distinguish between "clients" and "servers" -- this is up to the application." "An RPC connection is a bi-directional stream of Messages." Levels: Level 0 bootstrap only; Level 1 "simple bilateral interaction with object references"; Level 2 persistent capabilities; Level 3 three-way; Level 4 joins. "New implementations of Cap'n Proto should start out targeting the simplistic two-party network". "it is a simple byte stream protocol, it can easily be layered on top of SSL/TLS." [capnp-rpc; capnp-schema]
- Bidirectional notifications: either side can hold a capability to the other and call it; there is no separate notification type (inference from the symmetric model; the pages do not use the word "notification"). [capnp-schema]
- Streaming: not described on the pages read (unverified; Cap'n Proto has a `stream` keyword in newer versions, not checked).
- PTY attach: `Data` fields over a bidi connection would carry bytes; nothing read here shows it done.
- Libraries: "Serialization + RPC" implementations listed for C++, C#, Erlang, Go, Haskell, JavaScript (Node.js only), OCaml, Python, Rust. Rust's `capnp-rpc` "Includes all Level 1 features" with a `twoparty` VatNetwork "for the common case of a client-server connection"; its example uses `Rc<Self>`, which hints single-threaded use (page does not say). Bun/TypeScript: not listed. [capnp-otherlang; capnp-rust]
- Portability: byte-stream protocol; runs over whatever the implementation can open. Not checked per implementation (unverified).

### 2.7 Connect protocol

- "Connect servers and clients support three protocols: gRPC, gRPC-Web, and Connect’s own protocol." "Bidirectional streaming requires HTTP/2, but the other RPC types also support HTTP/1.1." Unary uses `application/proto` or `application/json` as the HTTP body; streaming uses `application/connect+proto`/`+json` with an envelope: 1 byte flags (bit 0 compressed, bit 1 EndStreamResponse, 6 reserved) + 4-byte big-endian length. Servers "must send an EndStreamResponse as the final message in the stream". [connect-protocol; connect-intro]
- Libraries: Go, Web, Node.js, Python ("available in beta"), Kotlin, Swift, Dart. Rust appears only as RFC "007: Rust Implementation". On Node: "Over HTTP/2, Node.js can serve the Connect, gRPC, and gRPC-Web protocols with all types of RPCs"; over HTTP/1.1 "the gRPC protocol and bidirectional streaming RPCs are not supported"; Express and Next.js "does not support the `http2` module". [connect-intro; connect-node]
- Bidirectional notifications / PTY attach: same shapes as gRPC (server push = server-stream; PTY = bidi stream, HTTP/2 only). Unix-socket/named-pipe support is not stated on the pages read (unverified).

### 2.8 Others worth naming

- ttrpc (containerd): "GRPC for low-memory environments"; replaces HTTP/2 with "a lightweight framing protocol": "Each Message Frame consists of a 10-byte message header followed by message data." (4-byte length, 4-byte stream ID, 1-byte type, 1-byte flags); "The maximum data length is 4MB"; "The Stream ID must be odd for client initiated streams and even for server initiated streams." but "Server initiated streams are not currently supported." "optimized for low latency and reliable connections between processes on the same host." Go-only as far as the pages read show (unverified for other languages). [ttrpc; ttrpc-protocol]
- Python `multiprocessing.connection`: `Listener` is "A wrapper for a bound socket or Windows named pipe"; families `'AF_INET'`, `'AF_UNIX'`, `'AF_PIPE'` ("Of these only the first is guaranteed to be available"); `AF_PIPE` addresses are `r'\\.\pipe\PipeName'`. Payloads are pickled ("unpickling data from an untrusted source is a security risk"), so it is Python-to-Python only. [py-mp]
- stdio as transport: MCP's stdio ("The client launches the MCP server as a subprocess") and Neovim's `--embed` both do this. It inverts ownership: the client spawns the server, which conflicts with a long-lived server that outlives clients (inference). [mcp-transports; nvim-starting]

## 3. Cross-cutting comparison

| Protocol | Framing on a byte stream | Server → client without request | Streams | Binary PTY bytes | Resize/control alongside |
| - | - | - | - | - | - |
| JSON-RPC 2.0 | none in spec; `Content-Length` (LSP) or newline (MCP) | notification (no `id`) | none; repeated notifications | not native (text) | same channel as RPC |
| gRPC | HTTP/2 DATA + 5-byte prefix | only inside a server-streaming call | 4 shapes, ordered, cancellable, deadlines | `bytes` in bidi stream | same connection, separate stream |
| Connect | HTTP body (unary) / 5-byte envelope (stream) | server-streaming call | same as gRPC; bidi needs HTTP/2 | as gRPC | as gRPC |
| HTTP + SSE | HTTP + `text/event-stream` lines | yes (push only) | one direction | no (UTF-8 only) | separate HTTP requests |
| WebSocket | RFC 6455 frames | yes | message stream; app-defined | binary frames | app-defined |
| Docker hijack | HTTP then raw bytes; 8-byte mux header without TTY | n/a (raw) | raw | yes | separate HTTP call (`/resize`) |
| MessagePack-RPC | self-delimiting values | notification | none; repeated notifications | bin type (unverified) | same channel |
| Cap'n Proto RPC | Cap'n Proto messages | symmetric calls | not verified | `Data` | same connection |
| ttrpc | 10-byte header | not supported ("Server initiated streams are not currently supported") | client-initiated streams | bytes | same connection |

Sources per row are in section 2.

Library coverage by stack (official docs only; "—" means not checked, not "absent"):

| Stack | Unix socket | Windows named pipe | JSON-RPC 2.0 | gRPC | WebSocket server |
| - | - | - | - | - | - |
| Node | `net` path [node-net] | `net` `\\?\pipe\` [node-net] | `vscode-jsonrpc` [vscode-jsonrpc] | `@grpc/grpc-js`, pure JS, `unix:` resolver [grpc-js-compare; grpc-js-uds] | none in core (client only) [node-globals] |
| Bun | `Bun.serve({unix})` [bun-http] | — | — | trailers unsupported in `Bun.serve` [bun-http] | `Bun.serve` websocket [bun-ws] |
| Go | `net` `"unix"` [go-net] | `go-winio` [go-winio] | stdlib is 1.0 only [go-jsonrpc] | grpc-go, `WithContextDialer` [grpc-go] | `coder/websocket`, `gorilla` [go-xnet-ws; coder-ws] |
| Rust | tokio `UnixStream` (Unix only) [tokio-uds] | tokio `windows::named_pipe` [tokio-pipe] | `jsonrpsee` (HTTP/WS) [jsonrpsee] | tonic, uds example `cfg(unix)` [tonic-uds] | `tokio-tungstenite` [tokio-tungstenite] |
| Python | asyncio (Unix only) [py-asyncio] | `multiprocessing.connection` `AF_PIPE` [py-mp] | — | `grpcio` [grpc-languages] | `websockets` [py-websockets] |

## 4. How comparable tools solve it (as their docs state)

- Docker Engine: REST over Unix socket / named pipe / TCP; attach by HTTP hijack to a raw bidirectional stream (multiplexed 8-byte frames without a TTY, raw bytes with one); resize via a separate endpoint; a WebSocket attach variant; an h2c upgrade endpoint for gRPC sessions (deprecated). [docker-openapi; docker-cli; dockerd]
- tmux: one server process per socket under `/tmp/tmux-UID/`; clients attach over that socket. Control mode (`-C`): "a client sends `tmux` commands or command sequences terminated by newlines on standard input"; each command yields a `%begin` ... `%end`/`%error` block with "an integer time (as seconds from epoch), command number and flags"; "A notification will never occur inside an output block"; `%output pane-id value` where "value escapes non-printable characters and backslash as octal \\xxx"; `%pause`/`%continue`/`%extended-output` exist when the `pause-after` flag is set (`refresh-client -A`); `refresh-client -C` sets the control client's size; `%session-changed`, `%layout-change`, `%exit`. [tmux]
- LSP: JSON-RPC with `Content-Length` headers; VS Code's client offers stdio, Node IPC, pipe (Unix socket or `\\.\pipe\...`), and TCP socket on 127.0.0.1, telling the server via `--stdio`, `--node-ipc`, `--pipe=`, `--socket=`. The pipe and socket listeners "are owned by the" client, which accepts exactly one connection then stops accepting. [lsp-base; vscode-client; vscode-jsonrpc-node]
- MCP: JSON-RPC over newline-delimited stdio, or Streamable HTTP (POST per client message; SSE for server-to-client; `Mcp-Session-Id`; `Last-Event-ID` resumption; Origin validation). [mcp-transports]
- Neovim: MessagePack-RPC over a default socket, `--listen` pipe/TCP, or `--embed` stdio; events pushed as notifications; out-of-spec LIFO response ordering. [nvim-api; nvim-starting]
- containerd ttrpc: gRPC service definitions over a custom 10-byte-header framing, same-host only, no server-initiated streams. [ttrpc; ttrpc-protocol]

## Unverified

Things no primary source read for this note states. Each is also marked inline.

- Whether `vscode-jsonrpc`, `@grpc/grpc-js`, or `ws` run under Bun.
- Whether `Bun.serve`'s `unix:` option and WebSocket `upgrade` work together.
- Python: absence of a standard-library JSON-RPC 2.0 implementation (inferred from not finding one).
- Python `grpcio` Unix-socket support specifically; inferred from gRPC's naming doc saying "Most gRPC implementations support" `unix:`.
- gRPC over Windows named pipes in any language other than via grpc-go's custom dialer (and even that was not demonstrated by the docs, only enabled by `WithContextDialer` + `passthrough`).
- Node `Http2Server` listening on an IPC path (inferred from "Extends: net.Server").
- MessagePack's binary type and self-delimiting framing (the msgpack spec fetch returned only its opening line).
- Cap'n Proto streaming support and per-implementation transport portability; `capnp-rpc` single-threadedness.
- Connect's Unix-socket or named-pipe support.
- ttrpc implementations outside Go.
- Neovim client libraries per language; whether Neovim's "pipe" means Windows named pipes.
- MessagePack-RPC spec symmetry (whether a server may issue Requests to a client).
- The Docker v1.56 page fetched the OpenAPI YAML (`v1.56.yaml`); quoted text is from that file, not the rendered page.

## Sources

- [jsonrpc-spec] https://www.jsonrpc.org/specification
- [lsp-base] https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/ (Base Protocol, Progress, Cancellation)
- [mcp-transports] https://modelcontextprotocol.io/specification/2025-06-18/basic/transports
- [grpc-http2] https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md
- [grpc-concepts] https://grpc.io/docs/what-is-grpc/core-concepts/
- [grpc-naming] https://github.com/grpc/grpc/blob/master/doc/naming.md
- [grpc-languages] https://grpc.io/docs/languages/
- [grpc-rust] https://grpc.io/docs/languages/rust/ and https://github.com/grpc/grpc-rust
- [grpc-perf] https://grpc.io/docs/guides/performance/
- [grpc-go] https://pkg.go.dev/google.golang.org/grpc (NewClient, WithContextDialer, CanonicalTarget)
- [grpc-js-compare] https://github.com/grpc/grpc-node/blob/master/PACKAGE-COMPARISON.md
- [grpc-js-uds] https://raw.githubusercontent.com/grpc/grpc-node/master/packages/grpc-js/src/resolver-uds.ts
- [tonic-uds] https://raw.githubusercontent.com/hyperium/tonic/master/examples/src/uds/server.rs
- [rfc6455] https://www.rfc-editor.org/rfc/rfc6455
- [sse-spec] https://html.spec.whatwg.org/multipage/server-sent-events.html
- [capnp-rpc] https://capnproto.org/rpc.html
- [capnp-schema] https://raw.githubusercontent.com/capnproto/capnproto/master/c++/src/capnp/rpc.capnp
- [capnp-otherlang] https://capnproto.org/otherlang.html
- [capnp-rust] https://docs.rs/capnp-rpc/latest/capnp_rpc/
- [msgpack-rpc] https://github.com/msgpack-rpc/msgpack-rpc/blob/master/spec.md
- [msgpack] https://github.com/msgpack/msgpack/blob/master/spec.md
- [connect-protocol] https://connectrpc.com/docs/protocol/
- [connect-intro] https://connectrpc.com/docs/introduction/
- [connect-node] https://connectrpc.com/docs/node/server-plugins/
- [ttrpc] https://github.com/containerd/ttrpc
- [ttrpc-protocol] https://github.com/containerd/ttrpc/blob/main/PROTOCOL.md
- [docker-openapi] https://docs.docker.com/reference/api/engine/version/v1.56.yaml (ContainerAttach, ContainerAttachWebsocket, ContainerResize, Session)
- [docker-cli] https://docs.docker.com/engine/reference/commandline/cli/
- [dockerd] https://docs.docker.com/reference/cli/dockerd/
- [docker-daemon] https://docs.docker.com/engine/daemon/
- [tmux] https://man.openbsd.org/tmux.1 (DESCRIPTION, CONTROL MODE)
- [nvim-api] https://raw.githubusercontent.com/neovim/neovim/master/runtime/doc/api.txt
- [nvim-starting] https://raw.githubusercontent.com/neovim/neovim/master/runtime/doc/starting.txt
- [vscode-jsonrpc] https://github.com/microsoft/vscode-languageserver-node/blob/main/jsonrpc/README.md
- [vscode-jsonrpc-node] https://raw.githubusercontent.com/microsoft/vscode-languageserver-node/main/jsonrpc/src/node/main.ts
- [vscode-client] https://raw.githubusercontent.com/microsoft/vscode-languageserver-node/main/client/src/node/main.ts
- [node-net] https://nodejs.org/api/net.html (IPC support)
- [node-http2] https://nodejs.org/api/http2.html (Class: Http2Server)
- [node-globals] https://nodejs.org/api/globals.html (WebSocket, EventSource)
- [bun-http] https://bun.sh/docs/api/http
- [bun-ws] https://bun.sh/docs/api/websockets
- [go-net] https://pkg.go.dev/net
- [go-winio] https://pkg.go.dev/github.com/Microsoft/go-winio
- [go-jsonrpc] https://pkg.go.dev/net/rpc/jsonrpc
- [go-xnet-ws] https://pkg.go.dev/golang.org/x/net/websocket
- [coder-ws] https://pkg.go.dev/github.com/coder/websocket
- [tokio-uds] https://docs.rs/tokio/latest/tokio/net/struct.UnixStream.html
- [tokio-pipe] https://docs.rs/tokio/latest/tokio/net/windows/named_pipe/index.html
- [tokio-tungstenite] https://docs.rs/tokio-tungstenite/latest/tokio_tungstenite/
- [jsonrpsee] https://docs.rs/jsonrpsee/latest/jsonrpsee/
- [py-asyncio] https://docs.python.org/3/library/asyncio-stream.html
- [py-mp] https://docs.python.org/3/library/multiprocessing.html (Listeners and Clients)
- [py-websockets] https://websockets.readthedocs.io/en/stable/
- [unix7] https://raw.githubusercontent.com/mkerrisk/man-pages/master/man7/unix.7 (man7.org returned connection errors; this is the maintainer's mirror of the same page)
- [win-afunix] https://devblogs.microsoft.com/commandline/af_unix-comes-to-windows/
- [win-pipes] https://learn.microsoft.com/en-us/windows/win32/ipc/named-pipes
- [conpty] https://learn.microsoft.com/en-us/windows/console/creating-a-pseudoconsole-session
