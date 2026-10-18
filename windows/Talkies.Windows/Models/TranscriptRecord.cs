using System;

namespace Talkies.Windows.Models
{
    /// <summary>A saved dictation in the local transcript history.</summary>
    /// <param name="Id">Local row id; only meaningful on this device.</param>
    /// <param name="Uuid">Random lowercase UUIDv4 that identifies the transcript across devices.</param>
    /// <param name="CreatedAt">When the dictation finished, in UTC.</param>
    /// <param name="Text">Final text that was inserted (after cleanup).</param>
    /// <param name="RawText">Recognizer output before cleanup, or null when identical to <paramref name="Text"/>.</param>
    /// <param name="DurationMs">Recorded audio length in milliseconds, when known.</param>
    /// <param name="Runtime">Speech runtime that produced it (<see cref="TranscriptRuntime"/>), when known.</param>
    /// <param name="Language">Language code, or null when unknown.</param>
    public sealed record TranscriptRecord(
        long Id,
        string Uuid,
        DateTimeOffset CreatedAt,
        string Text,
        string? RawText,
        long? DurationMs,
        string? Runtime,
        string? Language)
    {
        public string CreatedAtDisplay => CreatedAt.ToLocalTime().ToString("g");

        public string Details
        {
            get
            {
                var parts = new System.Collections.Generic.List<string> { CreatedAtDisplay };
                if (Runtime is not null) parts.Add(Runtime == TranscriptRuntime.Phonon ? "Phonon-2" : "Whisper");
                if (Language is not null) parts.Add(Language);
                if (DurationMs is { } ms) parts.Add(TimeSpan.FromMilliseconds(ms).ToString(ms >= 3_600_000 ? @"h\:mm\:ss" : @"m\:ss"));
                if (RawText is not null) parts.Add("cleaned up");
                return string.Join(" · ", parts);
            }
        }
    }

    /// <summary>A finished dictation to add to the history.</summary>
    public sealed record NewTranscript(
        DateTimeOffset CreatedAt,
        string Text,
        string? RawText = null,
        long? DurationMs = null,
        string? Runtime = null,
        string? Language = null);

    /// <summary>Values stored in the shared <c>transcripts.runtime</c> column.</summary>
    public static class TranscriptRuntime
    {
        public const string Phonon = "phonon";
        public const string Whisper = "whisper";

        /// <summary>Maps a recognizer-chain id ("phonon2", "whisper") to the stored value.</summary>
        public static string? FromRecognizerId(string? recognizerId) => recognizerId?.ToLowerInvariant() switch
        {
            "phonon2" => Phonon,
            "whisper" => Whisper,
            _ => null,
        };
    }
}
