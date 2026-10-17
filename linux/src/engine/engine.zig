//! Layer 2 - engine (low volatility).
//!
//! Bindings to hardware and native libraries: PulseAudio capture, WAV/VAD
//! processing, the speech recognizers (Phonon-2 on CrispASR, whisper.cpp
//! fallback), the S1-mini runtime, clipboard, uinput paste,
//! the X11 hotkey grab and the WebSocket transport. These wrap stable C APIs
//! and change rarely. May import `core` only - never `app`.

pub const audio = @import("audio.zig");
pub const audio_processing = @import("audio_processing.zig");
pub const vad = @import("vad.zig");
pub const whisper = @import("whisper.zig");
pub const phonon = @import("phonon.zig");
pub const phonon_model = @import("phonon_model.zig");
pub const speech_policy = @import("speech_policy.zig");
pub const speech = @import("speech.zig");
pub const cleanup = @import("cleanup.zig");
pub const input = @import("input.zig");
pub const clipboard = @import("clipboard.zig");
pub const hotkey = @import("hotkey.zig");
pub const evdev_hotkey = @import("evdev_hotkey.zig");
pub const websocket = @import("websocket.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
