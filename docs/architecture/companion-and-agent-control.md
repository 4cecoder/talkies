# Companion devices and voice agent control

> **Note** This is a design proposal. Nothing on this page is implemented yet. Current behavior
> is described in the [platform guides](../README.md#platform-build-guides) and the
> [feature gap analysis](../product/feature-gap-analysis.md).

## Summary

Talkies stays a dictation app first. This design adds three capabilities on top of dictation:

1. **Android as a companion to the PC.** A paired phone works as a remote microphone, keyboard,
   remote control, status screen, and spoken readback for the user's own desktop. The phone is a
   thin client. It captures audio and text; the PC does all recognition, cleanup, intent parsing,
   and agent work.
2. **Voice control of coding agents.** Talkies can address agents by name, send them dictated
   prompts, report what they are doing, and approve or deny their permission requests. It does
   this through an agent-connector boundary. The built-in connector makes Talkies its own small
   agent harness; cmux and herdr connectors drive those tools when the user already uses them.
3. **Optional memory through the user's own Hindsight server.** Explicit voice notes can be
   retained as memories and recalled by voice. Recalled context can be added to an agent prompt,
   but only after the user sees it. This is opt-in, and it is never used for inference.

The constraints do not change. No hosted service is added and there is no network fallback for
inference. Model downloads stay explicit and SHA-256 verified. Devices talk to each other only over
the user's LAN or tailnet, through a mutually authenticated, encrypted channel that is pinned at
pairing time.

### Settled decisions

These decisions are fixed and are not open questions.

| Decision | Consequence for this design |
|---|---|
| The PC does the heavy lifting. | Recognition, cleanup, intent parsing, agent connectors, and the Hindsight connector run on the PC. The phone captures audio and text, shows state, and speaks readback. Phone-side recognition runs only when no paired PC is reachable. |
| Talkies can act as an agent harness. | A built-in connector launches and supervises agents directly. The cmux and herdr connectors are alternatives behind the same interface. |
| Dictation stays the primary interaction. | The existing dictation hotkey and keyboard flows keep their behavior. Commands work only in an explicit agent mode and are layered on dictated text, never replacing it. |

## 1. Product thesis

### What voice does better than typing into cmux or herdr

cmux and herdr solve "many agents, one screen." Each gives a sidebar of agent states and a
keyboard-driven way to move between panes. Both assume the user is at the keyboard, looking at the
screen. That assumption breaks down in three common cases:

- **Most of the user's input to an agent is a long, natural-language prompt.** Speaking is faster
  than typing for that kind of text, and Talkies already turns speech into clean text locally.
- **The interrupting work is small and frequent.** An agent asks "may I run `swift test`?" or
  finishes a task. Answering takes one word, but today the user has to switch panes to do it.
- **The user is not at the desk.** They may be walking, away from the screen, or in another room.
  A phone in the pocket can still carry a prompt or a "deny."

A voice-first control surface removes the navigation step. The user names the agent and says what
they want. Talkies resolves the name, routes the text, and confirms what happened out loud or on
the phone. The keyboard and the agent UI stay available, and Talkies does not try to replace the
terminal view.

The built-in harness makes the approach work better than screen-driving. cmux and herdr infer an
agent's state from hooks and from what is on its screen, and answering a permission prompt there
means sending keystrokes into a terminal dialog. The built-in harness instead speaks the
[Agent Client Protocol](https://agentclientprotocol.com/protocol/overview) (ACP) to agents that
support it. ACP delivers permission requests as structured `session/request_permission` calls and
progress as `session/update` notifications. Talkies can then read the exact tool call aloud and
answer with a structured decision instead of a guessed keystroke.

### Interaction flows

The flows below use two agents, **Atlas** (agent 1) and **Borealis** (agent 2). Numbers follow
the order shown in the Talkies agent list and stay stable while an agent is running.

#### Flow A: address an agent by name

1. At the PC, the user holds the **agent hotkey**. This is a separate binding from the dictation
   hotkey, which keeps its current behavior.
2. They say: "Atlas, rebase on main and rerun the failing tests."
3. The PC recognizes the speech and runs cleanup. The intent parser matches the leading address
   "Atlas" against agent names and aliases. Those names are also added to the recognition
   vocabulary. The rest of the utterance becomes prompt text.
4. The heads-up display (HUD) shows `To Atlas: "Rebase on main and rerun the failing tests."` with
   a two-second cancel window. Pressing Esc or saying "cancel" stops the send.
5. The connector delivers the prompt. For cmux that is `cmux agent message`, which delivers through
   the agent's hooks rather than as keystrokes. For herdr it is `agent.prompt`. For the built-in
   harness it is ACP `session/prompt`. Talkies plays a short confirmation sound.

If the name matches no agent, or matches two agents equally well, Talkies asks "Which agent?" and
lists the candidates. It never guesses.

#### Flow B: approve or deny a permission request

1. Atlas asks to run `rm -rf build/`. The connector raises a `needs_input` event with the request
   text.
2. Talkies notifies the PC HUD and every paired phone that has the *agents* scope. A phone with
   announcements enabled and headphones connected speaks: "Atlas wants to run rm -rf build.
   Approve or deny?"
3. **Deny** is in the safe direction, so it is never gated. Saying "deny", or tapping Deny,
   rejects the request at once.
4. **Approve** is consequential. Saying "approve" opens a confirmation card that shows the exact
   command and the agent. The user then taps **Approve once** or says "confirm" within 15 seconds.
   The confirmation is bound to that specific request ID. If the agent's request changes or
   expires, the confirmation is void.
5. "Always allow" options are never offered by voice.

#### Flow C: "What's agent 2 doing?"

1. The user asks this from the agent hotkey or the phone's agent screen. It is a read-only intent,
   so it runs immediately.
2. Talkies builds a short status sentence from connector data, without a language model: "Agent 2,
   Borealis, in workspace talkies: working for six minutes. Last step: running swift test. No
   questions waiting."
3. The sentence is spoken on the device that asked, through local text-to-speech (TTS), and shown
   as text.

#### Flow D: dictate a long prompt on the phone while walking

1. On the phone's **Agents** screen, the user picks Borealis or says its name first, then presses
   **Talk**. A tap toggles recording; holding works as push-to-talk.
2. The phone streams 16 kHz mono PCM to the PC. The PC splits the stream at pauses and transcribes
   each segment as it arrives, so the draft grows on the phone screen.
3. If the connection drops, the phone keeps buffering in memory, up to the same five-minute limit
   as phone dictation today, and resumes the stream on reconnect. If the PC is still unreachable
   when recording stops, the phone transcribes locally (see
   [where recognition runs](#where-recognition-runs)).
4. When recording stops, the phone shows the full draft. Tapping **Send to Borealis** delivers it.
   Tapping **Read back** speaks the draft first. A prompt dictated offline never sends itself on
   reconnect; it waits in an outbox until the user taps Send.

#### Flow E: spoken summaries through local TTS

1. When an agent changes to `done` or `needs_input`, the PC sends an event to the phone.
2. If the user enabled announcements for that agent, the phone speaks a one-line status (Flow C
   format) through a TTS voice that runs on the device. Announcements default to headphones only,
   so the phone does not speak aloud in public by default.
3. "Read the last message" speaks the agent's most recent reply. Long replies are cut at a
   sentence boundary, about 60 seconds of speech, and the phone says "more on the PC".

#### Flow F: plain dictation through the phone

This is the companion's primary use, and it needs no agent setup.

- **Phone as microphone.** The user taps **Dictate to PC**. The PC runs its normal recognition and
  cleanup chain and inserts the text at the PC's focused field, as if the PC hotkey had been used.
- **Phone as keyboard.** The phone's **Keyboard** screen has a text field and a key row: Enter,
  Tab, Esc, Backspace, and the arrow keys. Committed text and allowlisted keys go to the PC's
  insertion adapter.

## 2. Architecture

### Components

```text
Android (thin client)                            PC (Talkies desktop host)
┌───────────────────────────┐   TLS 1.3, mutual  ┌──────────────────────────────────────────┐
│ Mic capture  · Keyboard   │   pinned certs     │ Companion host (listener, pairing, pins) │
│ Agents screen · Outbox    │◀──────────────────▶│   ├─ audio → speech chain → cleanup      │
│ Local TTS readback        │   LAN or tailnet   │   ├─ text  → insertion adapter           │
│ Offline fallback ASR      │                    │   ├─ intent parser (rules, local only)   │
└───────────────────────────┘                    │   ├─ safety gate + action log            │
                                                 │   ├─ agent connectors                    │
                                                 │   │    built-in (ACP) · cmux · herdr     │
                                                 │   ├─ memory connector: Hindsight (opt-in)│
                                                 │   └─ history + vocabulary sync           │
                                                 └──────────────────────────────────────────┘
```

### Device pairing and discovery

#### Options considered

| Option | Advantages | Problems | Decision |
|---|---|---|---|
| Rely on Tailscale for encryption and identity | No app crypto | Does not cover plain LAN use. Every device on the tailnet is not equally trusted. Adds a hard dependency. | Rejected as the only layer. Tailscale is a supported route, not the trust anchor. |
| Noise protocol (for example XX or IK) over TCP | Small and modern; keys are the identity | No platform-native implementation. Four third-party crypto libraries to audit and pin. | Rejected for v1. |
| WebSocket over TLS | Familiar; browser-debuggable | Windows `HttpListener` needs a URL ACL for non-loopback, or else ASP.NET Kestrel. Linux needs an HTTP upgrade server that is not in GIO. | Rejected. Its benefits do not matter here. |
| **TLS 1.3 over TCP with self-signed certificates pinned by SPKI hash, mutual authentication, and length-prefixed frames** | Native on every platform: Network.framework, .NET `SslStream`, Android `SSLContext` with an Android Keystore key, GIO `GTlsConnection` | Talkies must handle pinning and certificate generation itself | **Chosen.** |

Each device creates one ECDSA P-256 key pair on first use. P-256 is chosen over Ed25519 because it
is supported for TLS certificates by every native stack listed above and by the Android Keystore.
The private key stays in the platform key store: the Keychain on macOS, a DPAPI-protected store on
Windows, the Android Keystore (non-exportable) on Android, and libsecret on Linux, falling back to
a file with mode 0600. The device's self-signed certificate wraps that key. A device's identity is
the SHA-256 hash of its SubjectPublicKeyInfo (SPKI).

#### Pairing flow (QR code)

1. On the PC, the user chooses **Pair a phone**. The PC starts the companion listener if it is not
   already running and generates a 32-byte single-use pairing secret `S` that expires after
   120 seconds.
2. The PC shows a QR code that encodes:
   `talkies-pair:v1?id=<pc_device_id>&fp=<pc_spki_sha256>&s=<S>&addr=<lan_ip:port,...>&ts=<magicdns_name>&exp=<unix_s>`.
   All binary fields use base64url. The same payload is offered as copyable text for PC-to-PC
   pairing later.
3. The phone scans the code. The design uses ZXing (Apache-2.0) rather than a Play Services
   scanner, so the scan works without Google services. The phone then opens TLS to the PC,
   accepting only a server certificate whose SPKI hash equals `fp`, and presents its own client
   certificate.
4. The phone sends
   `pair.request {device_name, proof = HMAC-SHA256(S, "talkies-pair-v1" ‖ pc_fp ‖ phone_fp)}`.
   The PC recomputes `phone_fp` from the client certificate it received in this TLS session,
   checks the proof in constant time, and invalidates `S`.
5. Both screens show the same four-digit code, derived from the proof, and the device name. The
   user confirms on the PC. This step stops someone who photographed the QR code from pairing
   silently.
6. Each side stores the other's pin: SPKI hash, name, last-known addresses, and, on the PC, the
   phone's granted scopes. Later connections use mutual TLS checked against the stored pins. No
   shared secret is stored after pairing.

Removing a device on the PC deletes its pin and closes its sessions at once. **Forget this PC** on
the phone deletes the phone's pin. Reinstalling either app creates a new key, which requires
pairing again. That is intended: a key is never silently re-trusted.

#### Per-device scopes

The PC grants scopes when pairing and lets the user change them later.

| Scope | Allows | Default |
|---|---|---|
| `dictate` | Stream audio for dictation into the PC's focused field | On |
| `keyboard` | Send text and allowlisted keys to the focused field | On |
| `history` | Read and sync transcript history | Off |
| `vocabulary` | Read and sync vocabulary | On |
| `agents.read` | List agents, receive status events, request summaries | On |
| `agents.control` | Send prompts and interrupts | Off |
| `agents.approve` | Approve permission requests (always confirmed) | Off |
| `memory` | Retain and recall through the Hindsight connector | Off |

#### Discovery

- **LAN:** The PC advertises `_talkies._tcp` over mDNS (Bonjour on macOS, `DnsServiceRegister` on
  Windows 10 1809 and later, Avahi over D-Bus on Linux). The TXT record carries only
  `v=1` and a random per-installation instance ID; it carries no user name or fingerprint. The
  phone discovers peers with `NsdManager` and connects only to instance IDs it has paired with. The
  pin check, not mDNS, decides trust.
- **Tailscale:** The QR payload includes the PC's MagicDNS name. The phone tries the last LAN
  address first, then mDNS, then the MagicDNS name. Talkies does not call the Tailscale API or
  depend on the Tailscale client. On a tailnet, traffic may pass through Tailscale's encrypted
  DERP relays. The TLS layer still protects the content end to end.
- **Listener scope:** The companion listener is off by default. It starts only after the user
  enables companion devices, and it binds to the LAN and Tailscale interfaces. The existing Linux
  daemon WebSocket stays bound to `127.0.0.1`, unauthenticated as it is today, and must never be
  exposed on a network interface.

### Companion protocol, version 1

#### Framing

The stream sits inside the TLS session. Each frame is:

```text
u32 big-endian length (max 1 MiB) | u8 kind | payload
kind 0x01: UTF-8 JSON control message
kind 0x02: audio chunk = u32 stream_id | u32 seq | PCM s16le bytes
```

A JSON control message has this envelope:

```json
{"v": 1, "id": "01J…", "type": "audio.start", "body": {}}
```

`id` is a client-generated ULID. It serves as the idempotency key, so a message resent after a
reconnect is applied at most once.

#### Versioning

- `hello {versions: [1], features: [...], device_id, app_version}` → `hello.ack {version,
  features}`. The PC picks the highest common major version and the intersection of the features.
- Adding a message type or an optional field adds a feature string, such as `opus`,
  `agents.events`, or `history.v1`, and keeps the major version.
- Removing a field or changing its meaning bumps the major version. The PC supports the previous
  major version for at least one release.
- An unknown `type` gets `error {code: "unsupported", ref: id}`. An unknown field is ignored.
- Golden JSON fixtures for every message live in `tests/fixtures/companion/v1/`, and every
  platform's codec test reads them.

#### Messages

| Area | Phone → PC | PC → phone |
|---|---|---|
| Session | `hello`, `ping` | `hello.ack`, `pong`, `error` |
| Pairing | `pair.request` | `pair.confirmed`, `pair.rejected` |
| Audio | `audio.start {stream_id, codec: "pcm_s16le", rate: 16000, channels: 1, target}`, kind 0x02 chunks, `audio.end`, `audio.cancel` | `audio.ack {stream_id, seq}`, `dictation.partial {stream_id, text}`, `dictation.result {stream_id, transcript_uuid, text, raw_text}` |
| Keyboard | `text.insert {text, submit: false}`, `key.press {key}` (allowlist: enter, tab, escape, backspace, arrows) | `insert.result {ok, method: "accessibility"\|"sendinput"\|"uinput"\|"clipboard", reason}` |
| Control | `intent.text {text, target}` (a typed command), `action.request {action, target, args}` (a button tap), `action.confirm {action_id, request_ref, decision}` | `action.confirm_required {action_id, summary, risk, expires_at}`, `action.result {action_id, ok, message}` |
| Agents | `agents.list`, `agents.subscribe`, `agent.read {agent_id, lines}` | `agents.snapshot {agents: [...]}`, `agent.event {agent_id, kind: "status"\|"needs_input"\|"done"\|"notification", ...}` |
| Readback | none | `speak {text, priority, reason}`. The phone speaks it with local TTS. |
| History | `history.pull {since_seq}`, `history.push {rows, tombstones}`, `history.query {text, before, limit}` | `history.batch {rows, tombstones, next_seq}`, `history.ack {seq}`, `history.page {rows}` |
| Vocabulary | `vocab.pull {since_seq}`, `vocab.push {entries}` | `vocab.batch {entries, next_seq}` |

`target` is one of `focused` (insert at the PC cursor), `agent:<connector>/<agent_id>`, `note`
(save to history only), or `memory` (retain through Hindsight).

Audio is raw 16 kHz mono PCM, about 256 kbit/s. That is acceptable on a LAN or tailnet and avoids
an encoder dependency. The phone's minimum is API 28, and Android's built-in Opus encoder needs
API 29, so Opus is a later optional feature (`opus`). Audio is never written to disk on either
side. The PC wipes received PCM buffers after recognition, as the Android client already does.

#### History sync (CRDT-light)

History sync builds on the shared `transcripts` table: `id`, `uuid TEXT UNIQUE`, `created_at` in
milliseconds, `text`, `raw_text`, `duration_ms`, `runtime`, `language`. `uuid` is the global
identity. `id` is local and is never sent.

Sync adds **sidecar tables** and does not alter `transcripts`. That avoids conflicts with the four
parallel history branches and makes the migration reversible: dropping the sidecar tables restores
the original schema exactly.

```sql
CREATE TABLE IF NOT EXISTS sync_state (
  key TEXT PRIMARY KEY, value INTEGER NOT NULL          -- 'local_seq', 'hlc'
);
CREATE TABLE IF NOT EXISTS transcript_sync (
  uuid TEXT PRIMARY KEY, hlc INTEGER NOT NULL, origin_device TEXT NOT NULL,
  local_seq INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS transcript_tombstones (
  uuid TEXT PRIMARY KEY, deleted_hlc INTEGER NOT NULL, origin_device TEXT NOT NULL,
  local_seq INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS sync_peers (
  peer_id TEXT PRIMARY KEY, last_recv_seq INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_transcript_sync_seq ON transcript_sync(local_seq);
CREATE INDEX IF NOT EXISTS idx_tombstones_seq ON transcript_tombstones(local_seq);
```

Merge rules:

1. **Union by `uuid`.** An incoming row with an unknown `uuid` is inserted with a new local `id`.
2. **Delete wins.** A tombstone removes the row and suppresses any later copy of the same `uuid`,
   whatever its timestamp. Deleting is the privacy-preserving direction, so it always wins.
3. **Last writer wins for edits.** If both sides hold the row, the higher `hlc` keeps its `text`
   and `raw_text`. A tie goes to the lexically greater `origin_device`.
4. `hlc` is a hybrid logical clock: `max(now_ms, last_seen_hlc + 1)`. Clock skew between the phone
   and the PC therefore cannot reorder causally related edits.
5. Every local insert, edit, or delete increments `local_seq` in the same transaction. A peer pulls
   changes with `local_seq > last_recv_seq` and acknowledges the new high-water mark.

Tombstones hold only a `uuid` and a time, never content, and are kept indefinitely. Without them,
a peer that was offline for a long time could bring deleted text back. Each history store's delete
path must write the tombstone in the same transaction. That is the one hook this design needs from
the history branches.

Topology and phone storage:

- The PC is the hub, and sync is pairwise between the PC and each phone.
- Following the thin-client decision, the phone does not mirror full history by default. It
  browses PC history on demand with `history.query`. It pushes up only the rows it created itself,
  such as offline-fallback dictations. **Keep a local copy** is an opt-in setting that turns on full
  pull.
- History sync obeys each device's history setting. A device with history off neither stores
  incoming rows nor sends its own. Turning history off on one device does not delete others'
  copies. An explicit delete does propagate.

The merge function is pure and lives on the stable contract side on every platform. Shared
fixtures in `tests/fixtures/sync/` cover concurrent edits, delete-versus-edit, a replayed batch,
and an out-of-order batch.

#### Vocabulary sync

Vocabulary is a set of terms. Today it is stored as a settings list and normalized by
`LocalVocabulary` (Swift and C#) and `vocabulary.zig`. Sync treats it as a last-writer-wins
element set, keyed by the case-folded normalized term:

```sql
CREATE TABLE IF NOT EXISTS vocabulary_entries (
  key TEXT PRIMARY KEY, term TEXT NOT NULL, hlc INTEGER NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0, origin_device TEXT NOT NULL, local_seq INTEGER NOT NULL
);
```

The settings list stays the input that recognizers read. The sync layer recomputes it from the
live entries after each merge, then applies the existing normalization and the Windows 400-character
prompt limit. Agent names and aliases are added to the PC's effective vocabulary for the session
only. They are not synced as user vocabulary.

### Where recognition runs

| Factor | Recognize on the PC (chosen) | Recognize on the phone |
|---|---|---|
| Accuracy and latency | Desktop Phonon-2 (Core ML on macOS) and larger Whisper models; faster than phone CPU inference | Phonon-2 Q4_K or Whisper tiny on the CPU; slower for long prompts |
| Battery and heat | Phone only captures and streams | A five-minute prompt costs noticeable battery |
| Vocabulary and agent names | One effective vocabulary, including live agent names | Needs vocabulary sync and still lacks live agent names |
| Cleanup and intent | Same S1-mini cleanup and intent parser as desktop dictation | Would need a second copy on the phone |
| Bandwidth | About 256 kbit/s PCM while talking | Text only |
| Works without the PC | No | Yes |
| Privacy | Audio crosses the user's own network, encrypted by TLS, never stored | Audio never leaves the phone |

**Decision:** The PC recognizes. The phone falls back to its existing local recognizer chain only
when no paired PC is reachable as recording ends. Text recognized that way is marked
`runtime = "<engine>@phone"`. It goes to the phone's outbox with its intended target and is
delivered only by an explicit tap after the PC comes back. Offline drafts never trigger an intent.
Phone audio is not kept for re-recognition on the PC; it is discarded as it is today.

### Agent connector boundary

#### Interface

The contract is small, owned by the stable side, and free of any connector types. This is a
language-neutral sketch; each platform writes it natively.

```text
AgentConnector
  id: "talkies" | "cmux" | "herdr"
  capabilities: {list, status_events, read, prompt, interrupt, approve, spawn}
  list() -> [AgentRef]
  subscribe() -> stream<AgentEvent>
  read(agent, lines) -> String                    // untrusted text
  prompt(agent, text) -> DeliveryResult           // never submits to a shell
  interrupt(agent) -> Result
  respond(agent, request_ref, decision) -> Result // decision: allow_once | deny
  // spawn() exists only on the built-in connector and is driven from settings, never by voice

AgentRef   {connector, id, name, aliases, kind, status, workspace, cwd, pending_request?}
AgentEvent {agent_id, kind: status | needs_input | done | notification, status, request?, at}
status     : idle | working | needs_input | done | unknown
```

Each connector maps its native states into this enum. herdr's `blocked` maps to `needs_input`;
cmux's `needsInput` lifecycle maps to `needs_input`. A connector reports missing capabilities
instead of faking them, and the UI hides actions that a connector cannot perform.

Connectors run in the PC process. The cmux and herdr connectors call their tools with argv arrays
or socket JSON, never through a shell. Each connector has a fake for tests, and the fakes are
driven by shared fixtures in `tests/fixtures/agents/`.

#### Built-in connector: Talkies as the harness

- Talkies starts agents that the user configured in Settings as argv arrays, for example
  `["gemini", "--acp"]` or an ACP adapter for Claude Code or Codex. It talks to each agent as an ACP
  client over the subprocess's stdio (JSON-RPC 2.0).
- Permission requests arrive as `session/request_permission` with structured tool-call details.
  Talkies offers only the allow-once and reject-once options by voice. Progress comes from
  `session/update` notifications. Interruption uses `session/cancel`.
- Agents are named by the user ("Atlas"). The default names come from a short, easily recognized
  word list, which works better for speech than `w1:p2`.
- Talkies does not emulate a terminal. A **Show** action opens the agent's transcript in a
  Talkies window. Users who want terminal panes keep using cmux or herdr.
- Tradeoff: agents are children of the Talkies process and stop when Talkies quits. Talkies warns
  before quitting with running agents. A detached agent host is deferred until users need it.
- Tradeoff: an ACP agent can skip permission requests. One user's tests reported that GitHub
  Copilot CLI in `--acp` mode auto-approved tool calls
  ([copilot-cli#845](https://github.com/github/copilot-cli/issues/845)). Talkies shows such agents
  as "approvals not reported" and cannot enforce approval for them.

#### cmux connector (macOS)

Verified against cmux 0.65.0 on this machine (`cmux --help`, `cmux help automation`, and per-command
`--help`) and the upstream
[CLI contract](https://raw.githubusercontent.com/manaflow-ai/cmux/main/docs/cli-contract.md):

- **Topology:** `cmux tree --all`, `list-workspaces`, `list-panes`, `list-pane-surfaces`,
  `identify --json`. Handles are short refs (`workspace:2`, `surface:5`) or UUIDs. Talkies stores
  UUIDs (`--id-format uuids`), because refs and indexes can shift.
- **Prompting:** `cmux agent message <target> <text|->`. It "delivers it through that agent's
  hooks, never by typing into its terminal, so it cannot land in a half-typed prompt." This is the
  preferred path. The fallback `cmux paste --surface … <text>` (without `--submit`) is used only for
  surfaces with no hook support, and only to stage text.
- **Draft guard:** `send` and `paste` consult `surface.input_state` and refuse when a human draft
  or an agent dialog is open. `input_state` returns `state` (`empty`/`draft`/`dialog`/`unknown`),
  `agent`, `lifecycle` (`running`/`idle`/`needsInput`), and `blocks_typing`. Talkies never passes
  `--force`.
- **Status and events:** `cmux events --category notification --reconnect` streams NDJSON events;
  `list-notifications`, `list-status`, and `workspace status` (lanes such as `working` and
  `needs-attention`) provide snapshots. `read-screen --surface … --lines N` gives recent text.
- **Approvals:** cmux has no structured approval call. Answering a dialog means `send-key` into it,
  which the guard refuses without `--force`. The cmux connector therefore does not claim the
  `approve` capability. Talkies offers **Show in cmux** (`open-notification`), and the user answers
  there.
- **Socket access:** The CLI reaches `~/.local/state/cmux/cmux.sock`. On this machine,
  `cmux socket-status --json` reports `configured_mode: "cmuxOnly"`. This probably means only
  processes started inside cmux may connect (inferred from the name, not verified). Talkies runs
  outside cmux, so the user may need to change the socket mode or set a socket password. The CLI
  accepts `--password` or `CMUX_SOCKET_PASSWORD`, and Talkies would keep that password in the
  Keychain.

#### herdr connector (macOS, Linux; Windows preview)

This section is verified from the [herdr socket API docs](https://herdr.dev/docs/socket-api/)
(docs version 0.9.5), the plugin docs in the
[herdr repository](https://github.com/herdrdev/herdr), and the GitHub API. herdr is not installed
on this machine, so none of these calls have been run.

- **Transport:** Newline-delimited JSON requests, `{"id", "method", "params"}`, over a Unix socket
  (a named pipe on Windows). The default path is `~/.config/herdr/herdr.sock`, overridden by
  `HERDR_SOCKET_PATH` or `HERDR_SESSION`. The docs describe no socket authentication, so file
  permissions are the boundary.
- **Methods used:** `agent.list`, `agent.get`, `agent.read`, `agent.prompt` (it returns
  `agent_blocked` instead of sending when the agent is blocked), `agent.send_keys`, `agent.focus`,
  `pane.process_info`, and `events.subscribe` with `pane.agent_status_changed`.
- **Status enum:** `idle`, `working`, `blocked`, `done`, `unknown`.
- **Approvals:** herdr reports `blocked` but has no structured approval call. Like cmux, the
  connector offers **Show in herdr** rather than sending keys to a dialog. A later version may
  answer with `agent.send_keys` once a fixture proves the dialog's key mapping for a given agent.
- **Licensing:** The GitHub API reports `Apache-2.0` for `herdrdev/herdr`. Some third-party write-ups
  say AGPL-3.0. Talkies only calls herdr over its socket and bundles none of its code, so the
  difference does not affect Talkies. The discrepancy is still recorded here.

#### Hindsight connector (memory, opt-in)

Hindsight is a memory server, not an agent, so it implements a separate, smaller contract:

```text
MemoryConnector
  retain(bank, content, context, tags, document_id) -> OperationRef
  recall(bank, query, max_tokens, tags) -> [MemoryFact]   // untrusted text
  forget(bank, document_id) -> Result                     // undo for a retain
```

This is verified against the upstream OpenAPI document
(`hindsight-clients/go/api/openapi.yaml` in
[vectorize-io/hindsight](https://github.com/vectorize-io/hindsight), MIT):

- Retain: `POST /v1/default/banks/{bank_id}/memories`, with `items[]` of `content` (required),
  `context`, `timestamp`, `document_id`, `metadata`, and `tags`, plus top-level `async`.
- Recall: `POST /v1/default/banks/{bank_id}/memories/recall`, with `query` (under 500 tokens),
  `types`, `budget`, `max_tokens`, `tags`, and `tags_match`. Results are facts with `text`, `type`,
  `tags`, and dates.
- Reflect: `POST /v1/default/banks/{bank_id}/reflect`. It "uses LLM to formulate a contextual
  answer." The connector does not use reflect by default.
- Undo: `DELETE /v1/default/banks/{bank_id}/documents/{document_id}`.
- Auth: every operation takes an `authorization` header. Health: `GET /health`.
- Hindsight extensions (Tenant, HTTP, OperationValidator, and MCP) are Python classes that run on
  the server. The Talkies integration needs no server-side extension. It is a client connector
  that uses the REST API, chosen over MCP because REST has a simpler, versioned surface.

What the Talkies Hindsight connector does:

- **Retain a voice note:** "Remember: the release branch freezes on Thursdays." The `remember`
  prefix in agent mode, or the phone's **Remember** target, retains the cleaned text. Talkies uses
  `document_id = transcript uuid`, context `talkies voice note`, and tags `source:talkies` and
  `device:<name>`. The HUD offers Undo for 10 seconds, which calls `forget`.
- **Recall by voice:** "What did I decide about the release freeze?" This calls `recall` and
  speaks the top facts. It is read-only, so it runs immediately.
- **Add context to a prompt:** "Atlas, using my notes, draft the changelog." The phrase
  `using my notes` triggers `recall(query = prompt body)`. The confirmation card shows the facts it
  found, and the user removes any they do not want. Talkies then sends the prompt with a delimited
  block: `Context from the user's notes (may be outdated): …`. Nothing is added silently.
- **Not done by default:** Talkies never retains all dictation automatically and never retains
  agent output. Offering to retain an agent's final summary is a separate opt-in.

Boundaries and disclosures:

- The connector is off until the user adds a server URL, an API key (stored in the platform key
  store), and a bank. Talkies accepts `https://` URLs and tailnet hosts (`*.ts.net` or
  `100.64.0.0/10`). For any other plain-`http://` host it shows a warning, because LAN HTTP is
  unencrypted.
- Retain sends text to a server that runs its own language model to extract facts, with whatever
  provider the user configured. Talkies cannot verify that the provider is local. Settings say this
  plainly. Hindsight is never part of recognition, cleanup, or intent parsing, and Talkies keeps
  working when it is unreachable.

### Intent parsing

Intent parsing runs on the PC, after recognition and cleanup. It uses no cloud model.

**Modes:** The dictation hotkey and the phone's **Dictate to PC** control never parse commands;
the text is always inserted. Commands are recognized only in **agent mode**: the agent hotkey, the
phone's **Agents** screen, or an utterance sent to an agent target. This layering keeps dictation
safe. "Approve the budget" dictated into an email is just text.

**Rules first.** The parser uses a closed, versioned grammar:

```text
utterance := [address ","] (command | prompt)
address   := <agent name or alias> | "agent" <number>
command   := status | list | read-last | show | approve | deny | interrupt
           | send | cancel | confirm | remember <text> | recall <text>
prompt    := anything else
```

- A command must be short: six words or fewer after the address. A long utterance that starts with
  "approve" is prompt text, not an approval.
- Agent names are matched by normalized edit distance and a phonetic key against names and aliases.
  Ambiguous matches ask "Which agent?". Numbers come from the visible list order.
- Anything that does not match the grammar becomes prompt text for the addressed agent. The
  fallback is always "this is dictation", never "guess a command".
- Utterance-to-intent fixtures in `tests/fixtures/intents/` cover misrecognitions observed in
  testing, such as "a prove" and "Atlas" heard as "at last". Every platform's parser runs them.

**Optional local model, later.** If the fixtures show the rules missing real phrasings, a local
GGUF model may map free text to the same closed intent set. It would run through the existing
llama.cpp runtime with a GBNF grammar that can emit only the intent enum, an agent ID from the
current list, and spans copied from the utterance. S1-mini is fine-tuned for transcript cleanup,
and its intent accuracy is unmeasured. Using it, or any other model, needs a fixture-based
evaluation first, and any new model needs a pinned, SHA-256-verified, explicit download. The model
never produces shell text or tool arguments.

### Safety model for voice-triggered actions

Every action passes through one safety gate on the PC, whether it came from speech, a phone tap, or
the HUD.

| Tier | Examples | Rule |
|---|---|---|
| 0 Read | status, list, read last message, recall | Run immediately |
| 1 Reversible | insert text at the cursor, send a prompt, focus or show an agent, retain (with undo), interrupt | Run after a visible two-second cancel window. For phone keyboard and dictation, run at once. |
| 2 Consequential | approve a permission request, send a prompt to an agent marked auto-approve | Explicit confirmation: a tap, or a fresh "confirm" utterance within 15 s. Bound to `action_id` and the connector's request reference. Requires the `agents.approve` scope. The phone may also require its screen-lock credential (`BiometricPrompt`). |
| 3 Never by voice | run a shell command, spawn or close agents, "always allow", delete memories or banks, change scopes, pair or unpair | Not exposed to voice or to the companion protocol. Settings UI only. |

Rules that apply to every tier:

- **No shell from speech.** Talkies never builds a shell string from recognized text. Connectors use
  argv arrays and structured calls. The cmux `--command` and `send` paths and herdr's `pane.run` are
  not reachable from voice.
- **Prompt text only reaches agents.** Talkies refuses to deliver prompt text to a pane or surface
  whose foreground process is not a detected agent (cmux `input_state.agent == false`, or herdr's
  `pane.process_info`). This stops a misrouted prompt from landing in a bare shell.
- **Asymmetry.** Deny, cancel, and interrupt are cheap. Approve is expensive. A misheard word should
  fail in the safe direction.
- **Stale-action protection.** A confirmation expires after 15 s. It also becomes invalid if the
  agent's pending request changes, and replaying an `action_id` has no effect.
- **Untrusted inputs.** Agent output, screen text, notifications, and recalled memories are data.
  They are spoken or shown, never parsed for intents, so an agent cannot trigger an action by
  printing "approve".
- **Offline drafts.** Text recognized on the phone while offline waits for a tap.
- **Action log.** Each gated action records time, device, intent, tier, decision, and result in a
  local `action_log` table. It references the transcript `uuid` rather than copying its text, and it
  follows the history retention setting.

### Failure modes

| Failure | Behavior |
|---|---|
| The PC is asleep or unreachable | Phone shows "PC offline." Dictation falls back to local recognition and the outbox. Agent screens show the last snapshot, marked as stale. |
| The network changes mid-stream | The phone buffers in memory (up to five minutes), reconnects, and resumes from the last `audio.ack` sequence |
| A certificate mismatch (reinstall or impostor) | The connection is refused. The user sees "This PC's identity changed. Pair again." There is no trust-on-first-use. |
| The connector tool is not running (cmux or herdr) | The connector reports `unavailable`, and its agents disappear from the list with a reason |
| The cmux socket refuses access | Show the socket-mode or password setup steps. Never retry in a tight loop. |
| The agent's prompt holds a human draft | The cmux guard refuses the send. Talkies says "Atlas has a draft open" and keeps the text on the phone. |
| A duplicate or replayed message | Deduplicated by message `id` and `action_id` |
| Concurrent history edits or deletes | Resolved by the merge rules: delete wins, then last writer wins by `hlc` |
| Two phones answer the same request | The first decision wins. The other phone receives `action.result {ok: false, message: "already answered"}`. |
| Hindsight is unreachable | Memory intents report "Notes server unreachable". Nothing else is affected. |
| A rogue LAN device | It cannot complete TLS without a pinned key. Connections are rate-limited per IP, frames are capped at 1 MiB, and an unauthenticated connection is closed after 10 s. |

## 3. Placement by platform and module

The placement follows [module boundaries by volatility](module-volatility.md). Contracts and merge
rules sit on the stable side. Transport, discovery, key storage, and TTS are platform adapters.
Connectors change with third-party tools, so they sit beside inference on the high-volatility
side. The app composes all of them.

| Piece | Layer | macOS | Windows | Linux | Android |
|---|---|---|---|---|---|
| Protocol messages and codec, sync merge, intent grammar, safety tiers, `AgentConnector` and `MemoryConnector` contracts | Contracts | `TalkiesCore` (Foundation only) | `Models/` plus interfaces in `Services/` | `linux/src/core/` (`companion_protocol.zig`, `sync_merge.zig`, `intent.zig`) | `:core` (protocol codec and sync merge only; no intent parsing on the phone) |
| Shared fixtures | Contracts | `tests/fixtures/companion/`, `sync/`, `intents/`, `agents/` | same | same | same |
| TLS listener or client, pinning, mDNS, key store | Platform adapter | New `TalkiesCompanion` target: Network.framework `NWListener` with TLS and Bonjour, Keychain | `Services/Companion/`: `TcpListener` and `SslStream`, `DnsServiceRegister`, DPAPI | `linux/src/app/companion*.zig` plus a GIO TLS and Avahi shim under `linux/src/native/` | `:app`: `SSLContext` with Android Keystore, `NsdManager`, ZXing scanner |
| Received-text insertion | Platform adapter (existing) | `TalkiesAccessibility.TextInserter.insertTextAtCursor` | `TextInjector.TryInsertText` (SendInput Unicode, clipboard fallback) | `TextInserter.insertTextAtCursor` (uinput paste) | Not used. The phone sends; the IME's `commitText` stays for phone-local dictation. |
| Readback TTS | Platform adapter | `AVSpeechSynthesizer` (already used in `TalkiesApp`) | System.Speech (as `SystemSpeechTtsPlugin`) | `spd-say` or `espeak-ng` (as `daemon.zig`) | `android.speech.tts`, restricted to voices where `isNetworkConnectionRequired()` is false |
| Agent and memory connectors | High volatility | New `TalkiesConnectors` package: built-in ACP, cmux, herdr, Hindsight | `Services/Agents/` in the existing project (no new library until a second consumer exists) | `linux/src/agents/` (built-in ACP, herdr, Hindsight; no cmux) | None |
| Sync and action-log storage | Platform adapter | Beside the history store from `feat/mac-transcript-history` | Beside the history store from `feat/windows-transcript-history` | Beside the history store from `feat/linux-history-updater` | Beside the history store from `feat/android-transcript-history` |
| UI: pairing QR, devices and scopes, agent HUD, confirmation card, agent list | App | SwiftUI and AppKit in `mac/Sources/Talkies` | WPF views and view models | GTK in `linux/src/ui/` | Compose screens in `:app`: Connect, Dictate, Keyboard, Agents, Outbox |

Notes:

- cmux is macOS only, so Linux and Windows offer the built-in and herdr connectors.
- `TalkiesConnectors` is a separate package because its code changes when cmux, herdr, ACP, or
  Hindsight change. The UI depends only on the `TalkiesCore` contracts.
- Android gains no connector and no intent code, which keeps the thin-client decision visible in
  the module graph.

### Rule changes this design needs

These product and coding rules must be amended in the same pull request that ships the first
networked phase:

- **[AGENTS.md](../../AGENTS.md), Kotlin/Android:** "network access is only for an explicit,
  verified model download" becomes: "...and for connections to the user's own paired devices over
  mutually authenticated, pinned TLS."
- **[Product vision](../product/vision.md), out of scope:** "remote APIs, and any feature that sends
  user audio or text to a service" needs an explicit carve-out. The carve-out covers (a) the
  user's own paired Talkies devices and (b) opt-in, user-configured, user-owned services such as
  Hindsight. Both are excluded from inference.
- **Privacy acceptance check:** Extend it with a companion variant. With external networking
  blocked, and only the LAN or tailnet route to the paired PC available, phone dictation, keyboard
  input, and agent control must work.

## 4. Phased plan

Each phase ships on macOS (host) and Android first, because cmux is macOS only and the maintainer
uses macOS daily. Linux and then Windows host support follows within the same milestone before it
closes. Each phase is usable without the next.

### Phase 1: Dictate to an agent on the PC

The smallest useful slice. It needs no phone and no networking.

- An agent hotkey, a target picker, and leading-name addressing for cmux and herdr agents.
- Read-only status ("what's Atlas doing") shown on the HUD and spoken with local TTS.
- Rules-based intent grammar with tiers 0 and 1 only. No approvals yet.

Acceptance:

- With cmux running and its socket reachable, dictating "Atlas, run the tests" delivers that text
  through `cmux agent message` to the workspace titled Atlas. The command is a tier-1 send with a
  cancel window.
- A target with an open human draft refuses delivery and shows why. Nothing is typed.
- The dictation hotkey's behavior is unchanged, and existing dictation tests pass.
- Intent fixtures pass on macOS. Command-shaped text dictated with the dictation hotkey is
  inserted verbatim.
- With external networking blocked, all of the above works.

### Phase 2: Pairing, phone as microphone, phone as keyboard

- QR pairing, mutual pinned TLS, mDNS and MagicDNS discovery, per-device scopes, and the protocol
  v1 session, audio, and keyboard messages.
- The phone's **Dictate to PC** and **Keyboard** screens. The PC recognizes and inserts through the
  existing adapters.
- Phone fallback recognition into an outbox when the PC is unreachable.

Acceptance:

- Pairing completes in under 30 s. Scanning an expired or used QR code fails. A device with a
  mismatched SPKI hash cannot connect, as verified by a test client presenting a different key.
- Phone dictation lands at the PC's focused field, with median end-of-speech to insertion under
  1.5 s for a 10 s utterance on LAN (measured and recorded in the platform guide).
- A packet capture shows only TLS 1.3 on the companion port. No audio file is created on either
  device.
- With external networking blocked, phone dictation works over the LAN and over a tailnet
  MagicDNS name.
- With the PC unreachable, the phone transcribes locally, and the draft waits in the outbox until
  the user taps Send.
- The rule changes in [rule changes this design needs](#rule-changes-this-design-needs) are
  merged.

### Phase 3: History and vocabulary sync

This phase depends on the four transcript-history branches landing.

- Sidecar tables, the tombstone hook in each history store's delete path, protocol `history.*` and
  `vocab.*` messages, phone browsing of PC history, and opt-in full copy.

Acceptance:

- Shared `tests/fixtures/sync/` cases pass on all four platforms.
- Deleting a transcript on either device removes it from the other within one sync, and it does not
  come back after the other device was offline during the delete.
- Dropping the sidecar tables leaves `transcripts` readable by the pre-sync app (migration
  reversibility test).
- A vocabulary term added on the phone is used for the next PC recognition.

### Phase 4: Remote agent control from the phone

- The phone's Agents screen: live list, status events, "what's agent 2 doing", read last message,
  send dictated prompts (Flow D), announcements (Flow E).
- Tier-2 approvals through the built-in connector only (phase 5). In this phase, approvals for cmux
  and herdr agents are shown with **Show on PC**.

Acceptance:

- A status change in cmux or herdr reaches the phone within 2 s on LAN.
- A five-minute prompt dictated while the phone switches from Wi-Fi to cellular plus Tailscale
  arrives complete and in order.
- Fixtures prove that agent output containing "approve" or "confirm" triggers no action.
- Readback uses only TTS voices with `isNetworkConnectionRequired() == false`. The test fails if
  only network voices are installed.

### Phase 5: Talkies as an agent harness

- The built-in ACP connector: user-configured agent commands, naming, structured approvals
  (allow once or reject once), interrupt, and a transcript window.
- Voice and phone approvals with tier-2 confirmation and an optional phone biometric check.

Acceptance:

- With an ACP agent that issues `session/request_permission`, the phone shows the exact tool call.
  "Deny" rejects it at once. "Approve" requires a tap or "confirm" within 15 s, and a confirmation
  after the request changed is rejected.
- "Always allow" is not reachable by voice or by the companion protocol (protocol test).
- An agent that never sends permission requests is labeled "approvals not reported."
- Quitting Talkies with running agents warns first.

### Phase 6: Hindsight connector (opt-in)

- Settings for the server, key, and bank. `remember`, `recall`, and `using my notes` intents.
  Undo through the document delete call. The LLM-processing disclosure.

Acceptance:

- With the connector disabled, Talkies sends no request to the configured host (network-capture
  test).
- `remember` retains with `document_id = transcript uuid`, and Undo deletes that document.
- Recalled facts are shown before they are added to a prompt, and removing a fact keeps it out of
  the sent prompt.
- With Hindsight unreachable, dictation and agent control still work, and the memory intent reports
  the failure in one sentence.

## 5. Open questions

1. **Host platform order.** Is macOS then Linux then Windows right, or should Linux, with herdr
   native and the existing daemon, be the first host?
2. **Rule amendments.** Do you accept the AGENTS.md and product-vision wording in
   [rule changes this design needs](#rule-changes-this-design-needs)? In particular, should
   user-owned services such as Hindsight be allowed by the vision at all, or should the Hindsight
   connector live outside the main app?
3. **Approvals from the phone.** Should phone approvals require the screen-lock credential every
   time, or only when the phone is off the home LAN?
4. **Agents in use.** Which agents and modes do you run? Some agents run in auto-approve or "yolo"
   modes, where a prompt is effectively a command. This decides whether those agents' prompts start
   at tier 2.
5. **cmux socket access.** Are you willing to switch cmux's socket mode from `cmuxOnly`, or set a
   socket password, so that Talkies can connect from outside cmux? If not, the cmux connector would
   need to run as a helper started inside cmux.
6. **Phone history.** Is on-demand browsing of PC history enough by default, or do you want the
   phone to keep a full offline copy?
7. **Hands-free.** Push-to-talk and tap-to-toggle are the only phone capture modes in this design.
   Do you want a wake phrase while walking? It would need an always-on local keyword model and a
   new privacy review.
8. **PC-to-PC sync.** Do you need history and vocabulary to sync between two PCs, for example a Mac
   and a Linux desktop? The protocol supports it, but pairing without a camera needs the
   text-code flow, which is not scheduled yet.
9. **Harness lifetime.** Is it acceptable that built-in agents stop when Talkies quits, at least
   until a detached host is justified?
10. **Hindsight banks.** Should you use one bank for all Talkies notes, or one bank per project or
    agent? Should agent summaries ever be retained automatically?

## Sources

Checked on 2026-10-18.

- cmux 0.65.0 local CLI help (`cmux --help`, `cmux help agents`, `cmux help automation`,
  `cmux send --help`, `cmux agent message --help`, `cmux events --help`,
  `cmux socket-status --json`) and the
  [cmux CLI contract](https://raw.githubusercontent.com/manaflow-ai/cmux/main/docs/cli-contract.md).
- [herdr socket API](https://herdr.dev/docs/socket-api/), herdr plugin and socket documentation in
  [herdrdev/herdr](https://github.com/herdrdev/herdr), and the GitHub repository metadata.
- [Hindsight documentation](https://hindsight.vectorize.io), the
  [retain](https://hindsight.vectorize.io/developer/api/retain),
  [recall](https://hindsight.vectorize.io/developer/api/recall), and
  [extensions](https://hindsight.vectorize.io/developer/extensions) pages, and the OpenAPI document
  in [vectorize-io/hindsight](https://github.com/vectorize-io/hindsight).
- [Agent Client Protocol overview](https://agentclientprotocol.com/protocol/overview) and
  [copilot-cli#845](https://github.com/github/copilot-cli/issues/845), a user report on which ACP
  agents send permission requests.
