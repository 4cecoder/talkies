using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Talkies.Windows.Models;

namespace Talkies.Windows.Services
{
    public enum GpuBackend
    {
        Cpu,
        Cuda,
        DirectMl
    }

namespace Talkies.Windows.Services
{
    /// <summary>
    /// Decoding options for transcription (similar to WhisperKit's DecodingOptions).
    /// </summary>
    public class DecodingOptions
    {
        /// <summary>
        /// Temperature for sampling (0.0 = deterministic, higher = more random).
        /// </summary>
        public float Temperature { get; set; } = 0.0f;

        /// <summary>
        /// Temperature increment on fallback.
        /// </summary>
        public float TemperatureIncrementOnFallback { get; set; } = 0.2f;

        /// <summary>
        /// Number of temperature fallback attempts.
        /// </summary>
        public int TemperatureFallbackCount { get; set; } = 5;

        /// <summary>
        /// Sample length for audio processing.
        /// </summary>
        public int SampleLength { get; set; } = 224;

        /// <summary>
        /// Top K for beam search.
        /// </summary>
        public int TopK { get; set; } = 5;

        /// <summary>
        /// Whether to use prefix prompt.
        /// </summary>
        public bool UsePrefillPrompt { get; set; } = true;

        /// <summary>
        /// Whether to use prefix cache.
        /// </summary>
        public bool UsePrefillCache { get; set; } = true;

        /// <summary>
        /// Whether to skip special tokens.
        /// </summary>
        public bool SkipSpecialTokens { get; set; } = true;

        /// <summary>
        /// Whether to include timestamps.
        /// </summary>
        public bool WithoutTimestamps { get; set; } = false;

        /// <summary>
        /// Whether to enable verbose output.
        /// </summary>
        public bool Verbose { get; set; } = false;
    }

    /// <summary>
    /// Result of a transcription operation.
    /// </summary>
    public class TranscriptionResult
    {
        public List<TranscriptSegment> Segments { get; set; } = new();
        public string Text { get; set; } = string.Empty;
        public string Vtt { get; set; } = string.Empty;

        // Statistics
        public int TotalWords => Segments.Sum(s => s.Text.Split(' ', StringSplitOptions.RemoveEmptyEntries).Length);
        public double DurationSeconds => Segments.Count > 0 ? Segments.Last().End : 0;
        public int WordsPerMinute => DurationSeconds > 0 ? (int)(TotalWords / (DurationSeconds / 60.0)) : 0;
    }

    /// <summary>
    /// Progress update for transcription operations (download + decode).
    /// </summary>
    public record TranscriptionProgress(TranscriptionStage Stage, double Percent, string? Message = null, bool IsIndeterminate = false);

    public enum TranscriptionStage
    {
        DownloadModel,
        Transcribing
    }

    /// <summary>
    /// Service interface for audio transcription.
    /// </summary>
    public interface ITranscriptionService : IDisposable
    {
        /// <summary>
        /// Transcribes an audio file with custom decoding options.
        /// </summary>
        Task<TranscriptionResult> TranscribeAsync(
            string filePath,
            string model,
            string language,
            bool vadEnabled,
            bool filterEnabled,
            bool preferGpu,
            GpuBackend gpuBackend,
            DecodingOptions? decodingOptions = null,
            IProgress<TranscriptionProgress>? progress = null);

        /// <summary>
        /// Exports segments to VTT (WebVTT) format.
        /// </summary>
        string ExportVtt(IEnumerable<TranscriptSegment> segments);

        /// <summary>
        /// Exports segments to SRT (SubRip) format.
        /// </summary>
        string ExportSrt(IEnumerable<TranscriptSegment> segments);

        /// <summary>
        /// Exports segments to plain text format.
        /// </summary>
        string ExportTxt(IEnumerable<TranscriptSegment> segments);
    }
}
