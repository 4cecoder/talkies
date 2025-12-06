"""
Lightweight IPC bridge to reuse the existing Python realtime pipeline on Windows.
Started by the WPF app via: python -m whisper_cli.bridge
Speaks JSON lines on stdout and listens for JSON commands on stdin.
"""

from __future__ import annotations

import json
import sys
import threading
import time
from pathlib import Path
from typing import Any, Dict, Optional


# Make sure we can import the main project (../src on the repo root)
ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "src"
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

try:
    from whisper_cli.realtime import RealtimeVTTStream
except Exception as exc:  # pragma: no cover
    sys.stderr.write(f"Failed to import realtime pipeline: {exc}\n")
    sys.stderr.flush()
    raise

streamer: Optional[RealtimeVTTStream] = None
start_time: Optional[float] = None
lock = threading.Lock()


def send(obj: Dict[str, Any]) -> None:
    """Write a single JSON line to stdout."""
    sys.stdout.write(json.dumps(obj, ensure_ascii=True) + "\n")
    sys.stdout.flush()


def start(opts: Dict[str, Any]) -> None:
    """Start realtime streaming."""
    global streamer, start_time
    with lock:
        if streamer is not None:
            return

        model = opts.get("model") or "base"
        language = opts.get("language") or None
        vad_enabled = opts.get("vad", True)

        try:
            streamer = RealtimeVTTStream(
                model=model,
                language=language,
                use_mlx=False,
                vad_enabled=vad_enabled,
                config=opts.get("config") or {},
            )
        except Exception as exc:
            send({"type": "error", "message": f"init_failed: {exc}"})
            streamer = None
            return

        start_time = time.time()

        def on_segment(seg):
            elapsed = max(time.time() - (start_time or time.time()), 0.001)
            words = len(seg.text.split())
            wpm = int((words / elapsed) * 60)
            send(
                {
                    "type": "segment",
                    "timestamp": seg._format_timestamp(seg.start),
                    "text": seg.text,
                    "start": seg.start,
                    "end": seg.end,
                    "wpm": wpm,
                }
            )

        streamer.on_segment(on_segment)
        threading.Thread(target=_run_stream, daemon=True).start()
        send({"type": "status", "value": "recording"})


def _run_stream() -> None:
    """Run the stream blocking in a thread."""
    if streamer is None:
        return
    try:
        streamer.start()
    except Exception as exc:
        send({"type": "error", "message": f"runtime_failed: {exc}"})


def stop() -> None:
    """Stop streaming and emit VTT."""
    global streamer
    with lock:
        if streamer is None:
            return
        try:
            streamer.stop()
            vtt = streamer.get_vtt()
            send({"type": "vtt", "value": vtt})
        except Exception as exc:
            send({"type": "error", "message": f"stop_failed: {exc}"})
        finally:
            streamer = None


def main() -> None:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            send({"type": "error", "message": "invalid_json"})
            continue

        cmd = msg.get("cmd")
        if cmd == "start":
            threading.Thread(target=start, args=(msg,), daemon=True).start()
        elif cmd == "stop":
            stop()
        elif cmd == "ping":
            send({"type": "pong"})
        else:
            send({"type": "error", "message": f"unknown_cmd:{cmd}"})


if __name__ == "__main__":
    main()
