using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Talkies.Windows.Models;

namespace Talkies.Windows.Services
{
    /// <summary>Lets the presentation layer choose the engine and explain fallbacks without knowing runtimes.</summary>
    public interface ISpeechEngineSelection
    {
        SpeechEngine Engine { get; set; }

        /// <summary>Display name of the recognizer that produced the last transcript.</summary>
        string? LastRecognizerName { get; }

        /// <summary>Why a preferred recognizer was skipped on the last request, or null when none was.</summary>
        string? LastFallbackReason { get; }
    }

    /// <summary>
    /// Tries local recognizers in <see cref="SpeechEnginePolicy"/> order. A recognizer that is not
    /// installed, fails to load, or fails to transcribe hands the request to the next one; Whisper is
    /// always last and its failure is reported to the caller. There is no network fallback.
    /// </summary>
    public sealed class SpeechRecognizerChain : ITranscriptionService, ISpeechEngineSelection
    {
        private readonly Dictionary<string, ISpeechRecognizer> _recognizers;
        private readonly object _sync = new();
        private SpeechEngine _engine;
        private string? _lastRecognizerName;
        private string? _lastFallbackReason;

        public SpeechRecognizerChain(IEnumerable<ISpeechRecognizer> recognizers, SpeechEngine engine = SpeechEngine.Automatic)
        {
            ArgumentNullException.ThrowIfNull(recognizers);
            _recognizers = recognizers.ToDictionary(r => r.Id, StringComparer.OrdinalIgnoreCase);
            if (!_recognizers.ContainsKey(SpeechEnginePolicy.WhisperId))
                throw new ArgumentException("The recognizer chain requires the Whisper fallback.", nameof(recognizers));
            _engine = engine;
        }

        public SpeechEngine Engine
        {
            get { lock (_sync) return _engine; }
            set { lock (_sync) _engine = value; }
        }

        public string? LastRecognizerName { get { lock (_sync) return _lastRecognizerName; } }
        public string? LastFallbackReason { get { lock (_sync) return _lastFallbackReason; } }

        public Task<TranscriptionResult> TranscribeAsync(
            string filePath,
            string model,
            string language,
            bool vadEnabled,
            bool filterEnabled,
            DecodingOptions? decodingOptions = null,
            IProgress<TranscriptionProgress>? progress = null) =>
            RecognizeAsync(new SpeechRecognitionRequest(filePath, model, language, vadEnabled, filterEnabled, decodingOptions), progress);

        public async Task<TranscriptionResult> RecognizeAsync(
            SpeechRecognitionRequest request,
            IProgress<TranscriptionProgress>? progress = null,
            CancellationToken cancellationToken = default)
        {
            ArgumentNullException.ThrowIfNull(request);
            var engine = Engine;
            var order = SpeechEnginePolicy.Order(engine, request.Language);
            var reasons = new List<string>();

            if (engine == SpeechEngine.Phonon2 && !SpeechEnginePolicy.IsPhonon2Language(request.Language))
                reasons.Add($"Phonon-2 recognizes English only; used Whisper for language '{request.Language}'.");

            for (var i = 0; i < order.Count; i++)
            {
                var isLast = i == order.Count - 1;
                if (!_recognizers.TryGetValue(order[i], out var recognizer))
                {
                    // Phonon-2 is optional in a composition (for example, tests or a build without it).
                    reasons.Add($"{order[i]} is not part of this build.");
                    continue;
                }

                var unavailable = recognizer.GetUnavailableReason();
                if (unavailable is not null)
                {
                    if (isLast) throw new InvalidOperationException($"{recognizer.DisplayName} is unavailable: {unavailable}");
                    reasons.Add($"{recognizer.DisplayName} is unavailable: {unavailable}");
                    Logger.Info($"Speech engine: skipping {recognizer.DisplayName} ({unavailable})");
                    continue;
                }

                try
                {
                    var result = await recognizer.RecognizeAsync(request, progress, cancellationToken).ConfigureAwait(false);
                    result.RecognizerId = recognizer.Id;
                    lock (_sync)
                    {
                        _lastRecognizerName = recognizer.DisplayName;
                        _lastFallbackReason = reasons.Count > 0 ? string.Join(" ", reasons) : null;
                    }
                    return result;
                }
                catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
                {
                    throw;
                }
                catch (Exception ex) when (!isLast)
                {
                    reasons.Add($"{recognizer.DisplayName} failed: {ex.Message}");
                    Logger.Warn($"Speech engine: {recognizer.DisplayName} failed, falling back ({ex.GetType().Name}: {ex.Message})");
                    progress?.Report(new TranscriptionProgress(
                        TranscriptionStage.Transcribing,
                        0,
                        $"{recognizer.DisplayName} could not transcribe; using Whisper...",
                        IsIndeterminate: true));
                }
            }

            // Unreachable while Whisper is required and last, but keeps the contract explicit.
            throw new InvalidOperationException("No local speech recognizer is available. " + string.Join(" ", reasons));
        }

        public string ExportVtt(IEnumerable<TranscriptSegment> segments) => TranscriptExporter.ExportToVtt(segments);
        public string ExportSrt(IEnumerable<TranscriptSegment> segments) => TranscriptExporter.ExportToSrt(segments);
        public string ExportTxt(IEnumerable<TranscriptSegment> segments) => TranscriptExporter.ExportToTxt(segments);

        public void Dispose()
        {
            foreach (var recognizer in _recognizers.Values)
                recognizer.Dispose();
        }
    }
}
