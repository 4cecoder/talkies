# Talkies WebSocket Architecture

## Overview

Replace file-based IPC with WebSocket server for real-time bidirectional communication between daemon and UI clients.

## Benefits

1. **Real-time updates**: No polling delay (currently 50-100ms)
2. **Bidirectional**: Clients can send commands, daemon pushes state
3. **Efficient**: Single persistent connection vs repeated file reads
4. **Scalable**: Multiple clients can connect (GTK + AGS + Web dashboard)
5. **Rich data**: Can stream audio levels, progress, errors

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│          Talkies Daemon (Zig)                            │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  WebSocket Server (ws://localhost:6789)            │ │
│  │                                                     │ │
│  │  Message Types:                                    │ │
│  │  - Commands (from clients):                       │ │
│  │    * start_recording                              │ │
│  │    * stop_recording                               │ │
│  │    * get_state                                    │ │
│  │                                                    │ │
│  │  - Events (broadcast to clients):                 │ │
│  │    * state_changed: {state: "recording"}          │ │
│  │    * audio_level: {level: 0.75}                   │ │
│  │    * transcription_complete: {text: "..."}        │ │
│  │    * error: {message: "..."}                      │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  Core Services:                                          │
│  - AudioRecorder (streams levels via WebSocket)         │
│  - WhisperService (transcription)                        │
│  - TextInserter (paste results)                          │
└───────────────────────┬───────────────────────────────────┘
                        │ WebSocket (JSON messages)
        ┌───────────────┼───────────────┬─────────────┐
        ↓               ↓               ↓             ↓
   ┌─────────┐     ┌─────────┐     ┌─────────┐  ┌──────────┐
   │ Toggle  │     │   GTK   │     │   AGS   │  │   Web    │
   │ Script  │     │ Overlay │     │ Widget  │  │Dashboard │
   │ (bash)  │     │(Python) │     │  (JS)   │  │   (TS)   │
   └─────────┘     └─────────┘     └─────────┘  └──────────┘
```

## Message Protocol

All messages are JSON over WebSocket text frames.

### Client → Server (Commands)

```json
{
  "type": "start_recording",
  "timestamp": 1234567890
}

{
  "type": "stop_recording",
  "timestamp": 1234567890
}

{
  "type": "get_state"
}
```

### Server → Client (Events)

```json
{
  "type": "state_changed",
  "data": {
    "state": "recording",  // "idle" | "recording" | "processing"
    "timestamp": 1234567890
  }
}

{
  "type": "audio_level",
  "data": {
    "level": 0.75,  // 0.0 - 1.0
    "timestamp": 1234567890
  }
}

{
  "type": "transcription_complete",
  "data": {
    "text": "Hello, this is a test recording",
    "duration_ms": 5230,
    "timestamp": 1234567890
  }
}

{
  "type": "error",
  "data": {
    "message": "Model failed to load",
    "code": "MODEL_ERROR"
  }
}

{
  "type": "waveform_update",
  "data": {
    "levels": [0.2, 0.5, 0.8, ...],  // 40 values
    "timestamp": 1234567890
  }
}
```

## Implementation Plan

### Phase 1: Daemon WebSocket Server

**File**: `src/websocket.zig` ✅ (created)
- Basic WebSocket server
- Client connection management
- Message broadcasting

**File**: `src/daemon_websocket.zig` (new)
- Message handler for commands
- State management
- Event broadcasting

### Phase 2: Update Core Services

**File**: `src/audio.zig`
- Add callback for audio level updates
- Stream levels to WebSocket clients in real-time

**File**: `src/main.zig` (`runDaemon`)
- Initialize WebSocket server
- Connect audio recorder callbacks to WebSocket broadcasts
- Handle incoming commands

### Phase 3: Client Implementations

#### Bash Toggle Script
**File**: `~/.config/hypr/scripts/talkies-toggle-ws.sh`
```bash
#!/bin/bash
# Send WebSocket command using websocat

STATE=$(echo '{"type":"get_state"}' | websocat -n ws://localhost:6789)

if [[ "$STATE" == *"idle"* ]]; then
    echo '{"type":"start_recording"}' | websocat -n ws://localhost:6789
else
    echo '{"type":"stop_recording"}' | websocat -n ws://localhost:6789
fi
```

#### Python GTK Overlay
**File**: `linux/talkies-overlay-gtk-ws` (update existing)
```python
import asyncio
import websockets
import json

async def connect():
    uri = "ws://localhost:6789"
    async with websockets.connect(uri) as websocket:
        async for message in websocket:
            data = json.loads(message)

            if data["type"] == "state_changed":
                update_ui_state(data["data"]["state"])

            elif data["type"] == "audio_level":
                update_waveform(data["data"]["level"])

            elif data["type"] == "transcription_complete":
                show_success(data["data"]["text"])
```

#### JavaScript AGS Widget
**File**: `~/.config/ags/widgets/talkies-ws.js`
```javascript
const ws = new WebSocket('ws://localhost:6789');

ws.onmessage = (event) => {
    const msg = JSON.parse(event.data);

    if (msg.type === 'state_changed') {
        updateOverlay(msg.data.state);
    } else if (msg.type === 'waveform_update') {
        updateWaveform(msg.data.levels);
    }
};

function toggleRecording() {
    ws.send(JSON.stringify({ type: 'start_recording' }));
}
```

## Migration Strategy

### Option 1: Gradual Migration
1. Keep file-based IPC as fallback
2. Add WebSocket support in parallel
3. Clients can use either method
4. Remove file-based after testing

### Option 2: Clean Break
1. Fully replace file-based with WebSocket
2. Update all clients at once
3. Simpler codebase, no dual support

## Dependencies

### Zig Daemon
- ✅ `std.net` (built-in) - TCP server
- ✅ `std.crypto` (built-in) - SHA1 for WebSocket handshake
- ✅ Custom WebSocket implementation (`src/websocket.zig`)

### Toggle Script
- `websocat` - WebSocket CLI client
  ```bash
  # Install on Gentoo
  emerge net-misc/websocat
  ```

### Python GTK
- `websockets` library
  ```bash
  pip install websockets
  # or
  emerge dev-python/websockets
  ```

### JavaScript AGS
- Built-in WebSocket API (no deps)

## Performance Comparison

| Metric | File-based IPC | WebSocket |
|--------|---------------|-----------|
| Latency | 50-100ms (polling) | <5ms (push) |
| CPU usage (idle) | ~1% (constant polling) | <0.1% (event-driven) |
| Updates/sec | 10-20 (poll rate) | Unlimited (push) |
| Waveform smoothness | Choppy (low poll rate) | Smooth (60 FPS) |
| Clients supported | Unlimited (read files) | Unlimited (connections) |

## Testing

### Manual WebSocket Test
```bash
# Terminal 1: Start daemon
zig build run -- daemon

# Terminal 2: Test with websocat
echo '{"type":"start_recording"}' | websocat -n ws://localhost:6789

# Watch events
websocat ws://localhost:6789
```

### Python Test Client
```python
import asyncio
import websockets

async def test():
    async with websockets.connect('ws://localhost:6789') as ws:
        await ws.send('{"type":"start_recording"}')
        async for msg in ws:
            print(f"Received: {msg}")

asyncio.run(test())
```

## Rollout Plan

1. ✅ Create `src/websocket.zig` (minimal WebSocket server)
2. Create `src/daemon_websocket.zig` (message handlers)
3. Update `src/main.zig` (`runDaemon`) to start WebSocket server
4. Update toggle script to use `websocat`
5. Update GTK overlay to use `websockets` library
6. Update AGS widget to use WebSocket API
7. Test complete workflow
8. Remove file-based IPC code (optional cleanup)

## Next Steps

Would you like to:
- **A**: Continue with full WebSocket implementation (more work, better architecture)
- **B**: Debug and fix the current file-based system (simpler, faster to working state)
- **C**: Hybrid approach: WebSocket for UI overlays, keep file-based for toggle script

Recommendation: **A** - The WebSocket approach will solve your current issues and provide a much better foundation for features like:
- Real-time waveform (actual audio levels, not random)
- Progress indicators during transcription
- Web-based dashboard
- Multiple simultaneous UIs
