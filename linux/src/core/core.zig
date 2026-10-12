//! Layer 1 - core (lowest volatility).
//!
//! Pure Zig with no system libraries: process/XDG helpers, recognition-hint
//! normalization, transcript export formats and crash diagnostics. Changes
//! here are rare; nothing in this layer may import `engine` or `app`.

pub const utils = @import("utils.zig");
pub const vocabulary = @import("vocabulary.zig");
pub const transcript_export = @import("transcript_export.zig");
pub const local_diagnostics = @import("local_diagnostics.zig");
pub const wav = @import("wav.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
