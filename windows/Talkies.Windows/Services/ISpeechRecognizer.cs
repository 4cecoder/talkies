using System;
using System.Threading;
using System.Threading.Tasks;

namespace Talkies.Windows.Services
{
    /// <summary>One local transcription request, independent of the runtime that serves it.</summary>
    /// <param name="AudioPath">Recorded audio file; recognizers convert it to the format they need.</param>
    /// <param name="WhisperModel">Selected Whisper model name (ignored by runtimes with a fixed model).</param>
    /// <param name="Language">ISO-639-1 code, or "auto".</param>
    public sealed record SpeechRecognitionRequest(
        string AudioPath,
        string WhisperModel,
        string Language,
        bool VadEnabled,
        bool FilterEnabled,
        DecodingOptions? DecodingOptions = null);

    /// <summary>A local speech-recognition runtime that can take part in the recognizer fallback chain.</summary>
    public interface ISpeechRecognizer : IDisposable
    {
        /// <summary>Stable identifier used by <see cref="SpeechEnginePolicy"/> ("phonon2", "whisper").</summary>
        string Id { get; }

        /// <summary>User-facing runtime name.</summary>
        string DisplayName { get; }

        /// <summary>
        /// Returns null when the recognizer can serve requests now, otherwise an actionable reason
        /// (for example, the model has not been downloaded). Must be cheap and must not download.
        /// </summary>
        string? GetUnavailableReason();

        Task<TranscriptionResult> RecognizeAsync(
            SpeechRecognitionRequest request,
            IProgress<TranscriptionProgress>? progress = null,
            CancellationToken cancellationToken = default);
    }
}
