using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Talkies.Windows.Models;

namespace Talkies.Windows.Services
{
    /// <summary>
    /// English speech recognition with Phonon-2 through CrispASR's Parakeet TDT backend. The native
    /// runtime runs in a <see cref="CrispAsrWorkerProcess"/> that keeps the model loaded between
    /// dictations. Any load or transcription failure is thrown so the chain can fall back to Whisper.
    /// </summary>
    public sealed class Phonon2Recognizer : ISpeechRecognizer
    {
        public const string BackendLabel = "Phonon-2 (CPU)";
        private static readonly TimeSpan LoadTimeout = TimeSpan.FromMinutes(2);
        private const int MaxConsecutiveWorkerFailures = 2;

        private readonly Phonon2ModelStore _store;
        private readonly SemaphoreSlim _gate = new(1, 1);
        private CrispAsrWorkerProcess? _worker;
        private bool _modelVerified;
        private int _consecutiveWorkerFailures;
        private volatile string? _disabledReason;
        private int _disposed;

        public Phonon2Recognizer(Phonon2ModelStore? store = null)
        {
            _store = store ?? new Phonon2ModelStore();
        }

        public string Id => SpeechEnginePolicy.Phonon2Id;
        public string DisplayName => "Phonon-2";

        public string? GetUnavailableReason()
        {
            if (!OperatingSystem.IsWindows()) return "Phonon-2 requires Windows.";
            if (_disabledReason is { } disabled) return disabled;
            if (!CrispAsrRuntime.IsPresent) return "the CrispASR runtime is missing from this Talkies installation.";
            if (!_store.IsInstalled) return "the Phonon-2 model has not been downloaded.";
            return null;
        }

        /// <summary>Clears a session-level disable after the model was reinstalled.</summary>
        public void ResetAfterInstall()
        {
            _disabledReason = null;
            _modelVerified = false;
            Interlocked.Exchange(ref _consecutiveWorkerFailures, 0);
        }

        public async Task<TranscriptionResult> RecognizeAsync(
            SpeechRecognitionRequest request,
            IProgress<TranscriptionProgress>? progress = null,
            CancellationToken cancellationToken = default)
        {
            ArgumentNullException.ThrowIfNull(request);
            ObjectDisposedException.ThrowIf(Volatile.Read(ref _disposed) != 0, this);

            await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
            var compatibleWav = request.AudioPath;
            var transcriptionWav = request.AudioPath;
            try
            {
                compatibleWav = Pcm16kMonoAudio.ConvertTo16kMono(request.AudioPath);
                transcriptionWav = request.VadEnabled
                    ? AudioSilenceTrimmer.TrimLeadingAndTrailingSilence(compatibleWav)
                    : compatibleWav;
                var samples = Pcm16kMonoAudio.ReadSamples(transcriptionWav);
                if (samples.Length == 0)
                    return new TranscriptionResult();

                var worker = await EnsureWorkerAsync(progress, cancellationToken).ConfigureAwait(false);
                var seconds = samples.Length / (double)Pcm16kMonoAudio.SampleRate;
                progress?.Report(new TranscriptionProgress(
                    TranscriptionStage.Transcribing, 0, "Transcribing with Phonon-2...", IsIndeterminate: true, Backend: BackendLabel));
                Logger.Info($"Phonon-2: transcribing {seconds:F1}s of audio with {worker.RuntimeDescription}");

                IReadOnlyList<CrispAsrSegment> segments;
                try
                {
                    // Generous bound: CPU Parakeet is normally well under real time.
                    segments = await worker.TranscribeAsync(samples, "en", TimeSpan.FromSeconds(60 + (seconds * 3)), cancellationToken).ConfigureAwait(false);
                    Interlocked.Exchange(ref _consecutiveWorkerFailures, 0);
                }
                catch (Exception ex) when (ex is not OperationCanceledException)
                {
                    if (worker.HasExited) RecordWorkerFailure(ex);
                    throw;
                }

                return BuildResult(segments);
            }
            finally
            {
                Pcm16kMonoAudio.DeleteTemporary(transcriptionWav, compatibleWav);
                Pcm16kMonoAudio.DeleteTemporary(compatibleWav, request.AudioPath);
                _gate.Release();
            }
        }

        internal static TranscriptionResult BuildResult(IReadOnlyList<CrispAsrSegment> segments)
        {
            var transcript = segments
                .Where(segment => !string.IsNullOrWhiteSpace(segment.Text))
                .Select(segment =>
                {
                    var start = Math.Max(0, segment.StartCentiseconds) / 100.0;
                    var end = Math.Max(start, segment.EndCentiseconds / 100.0);
                    return new TranscriptSegment
                    {
                        Timestamp = FormatTimestamp(start),
                        Start = start,
                        End = end,
                        Text = segment.Text.Trim(),
                    };
                })
                .ToList();

            return new TranscriptionResult
            {
                Segments = transcript,
                Text = string.Join(" ", transcript.Select(segment => segment.Text)),
                Vtt = TranscriptExporter.ExportToVtt(transcript),
            };
        }

        private async Task<CrispAsrWorkerProcess> EnsureWorkerAsync(IProgress<TranscriptionProgress>? progress, CancellationToken cancellationToken)
        {
            if (_worker is { HasExited: false } running) return running;
            _worker?.Dispose();
            _worker = null;

            if (!_modelVerified)
            {
                progress?.Report(new TranscriptionProgress(
                    TranscriptionStage.Transcribing, 0, "Verifying Phonon-2 model...", IsIndeterminate: true, Backend: BackendLabel));
                if (!await _store.VerifyInstalledAsync(cancellationToken).ConfigureAwait(false))
                {
                    _disabledReason = "the installed Phonon-2 files failed SHA-256 verification; download Phonon-2 again.";
                    throw new InvalidDataException("Phonon-2 model files failed SHA-256 verification.");
                }
                _modelVerified = true;
            }

            progress?.Report(new TranscriptionProgress(
                TranscriptionStage.Transcribing, 0, "Loading Phonon-2...", IsIndeterminate: true, Backend: BackendLabel));
            try
            {
                _worker = await CrispAsrWorkerProcess.StartAsync(_store.ModelPath, WorkerThreads(), LoadTimeout, cancellationToken).ConfigureAwait(false);
                Logger.Info($"Phonon-2 worker ready: {_worker.RuntimeDescription}");
                return _worker;
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                RecordWorkerFailure(ex);
                throw;
            }
        }

        private void RecordWorkerFailure(Exception ex)
        {
            if (Interlocked.Increment(ref _consecutiveWorkerFailures) >= MaxConsecutiveWorkerFailures)
            {
                _disabledReason = $"Phonon-2 failed {MaxConsecutiveWorkerFailures} times this session ({ex.Message}); restart Talkies to retry.";
                Logger.Warn($"Phonon-2 disabled for this session: {ex.Message}");
            }
        }

        /// <summary>ggml CPU inference scales with physical cores; logical/2 is a conservative proxy.</summary>
        internal static int WorkerThreads() =>
            Math.Min(Environment.ProcessorCount, Math.Clamp(Environment.ProcessorCount / 2, 2, 8));

        private static string FormatTimestamp(double seconds)
        {
            var ts = TimeSpan.FromSeconds(seconds);
            return $"{(int)ts.TotalHours:00}:{ts.Minutes:00}:{ts.Seconds:00}.{ts.Milliseconds:000}";
        }

        public void Dispose()
        {
            if (Interlocked.Exchange(ref _disposed, 1) != 0) return;
            _worker?.Dispose();
            _worker = null;
            _gate.Dispose();
        }
    }
}
