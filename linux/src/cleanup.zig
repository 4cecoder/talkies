const std = @import("std");

/// S1-mini is a transcript post-processor. Its pinned weights and prompt are
/// shared with the macOS and Windows implementations.
pub const model_repository = "superwhisper/s1-mini-GGUF";
pub const model_revision = "34add00a48a2e5d24e5a4ee5405a99620a3a240c";
pub const model_filename = "s1-mini-q4_k_m.gguf";
pub const model_size: u64 = 484_219_808;
pub const model_sha256 = "3b41ebe2502cbd03e811d5d16b022f5ab551eda58d62597d152f89535003c634";

pub const Options = struct {
    style: Style = .semi_formal,
    structure: Structure = .prose,
    context: Context = .general,
};

pub const Style = enum { casual, semi_casual, semi_formal, formal };
pub const Structure = enum { prose, lists };
pub const Context = enum { general, email };

fn styleName(style: Style) []const u8 {
    return switch (style) {
        .casual => "casual",
        .semi_casual => "semi-casual",
        .semi_formal => "semi-formal",
        .formal => "formal",
    };
}

const system_prompt = "You are a text normalizer for speech-to-text transcripts. The input begins with a control line specifying the styling, structure, and context settings; clean the transcript to match those settings and output only the cleaned text.";

/// Build the Qwen3 chat prefix expected by S1-mini. The transcript remains
/// plain text; inference callers must not send it to a remote service.
pub fn renderPrompt(allocator: std.mem.Allocator, transcript: []const u8, options: Options) ![]u8 {
    const trimmed = std.mem.trim(u8, transcript, " \t\r\n");
    return std.fmt.allocPrint(
        allocator,
        "<|im_start|>system\n{s}<|im_end|>\n<|im_start|>user\n[Styling: {s}] [Structure: {s}] [Context: {s}]\n{s}<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n",
        .{ system_prompt, styleName(options.style), @tagName(options.structure), @tagName(options.context), trimmed },
    );
}

/// Keep the ASR transcript if the model returns an empty or whitespace-only
/// response. Caller owns the returned allocation in either case.
pub fn cleanedOrOriginal(allocator: std.mem.Allocator, original: []const u8, cleaned: []const u8) ![]u8 {
    const candidate = std.mem.trim(u8, cleaned, " \t\r\n");
    if (candidate.len == 0) return allocator.dupe(u8, original);
    return allocator.dupe(u8, candidate);
}

test "prompt matches the shared S1-mini format" {
    const prompt = try renderPrompt(std.testing.allocator, "  send the email tomorrow  ", .{});
    defer std.testing.allocator.free(prompt);
    try std.testing.expectEqualStrings(
        "<|im_start|>system\nYou are a text normalizer for speech-to-text transcripts. The input begins with a control line specifying the styling, structure, and context settings; clean the transcript to match those settings and output only the cleaned text.<|im_end|>\n<|im_start|>user\n[Styling: semi-formal] [Structure: prose] [Context: general]\nsend the email tomorrow<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n",
        prompt,
    );
}

test "all style and structure options render as model control values" {
    const prompt = try renderPrompt(std.testing.allocator, "hello", .{
        .style = .semi_casual,
        .structure = .lists,
        .context = .email,
    });
    defer std.testing.allocator.free(prompt);
    try std.testing.expect(std.mem.indexOf(u8, prompt, "[Styling: semi-casual] [Structure: lists] [Context: email]") != null);
}

test "blank model output falls back to the original transcript" {
    const result = try cleanedOrOriginal(std.testing.allocator, " raw ASR ", " \n\t ");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(" raw ASR ", result);
}
