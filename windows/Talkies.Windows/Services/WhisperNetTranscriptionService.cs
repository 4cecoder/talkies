using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Threading.Tasks;
using NAudio.Wave;
using Whisper.net;
using Whisper.net.Ggml;
using Talkies.Windows.Models;

namespace Talkies.Windows.Services
{
    /// <summary>
    /// Native transcription using whisper.net (no Python). Requires a GGML model file.
    /// Supports dynamic model download if not available locally.
    /// </summary>
    public class WhisperNetTranscriptionService : ITranscriptionService
    {
        // OpenAI Whisper model URLs (GGML format from ggerganov/whisper.cpp)
        private static readonly Dictionary<string, string> ModelUrls = new()
        {
            { "tiny", "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin" },
            { "base", "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin" },
            { "small", "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin" },
            { "medium", "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin" },
            { "large", "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large.bin" }
        };

        private static readonly HttpClient HttpClient = new() { Timeout = TimeSpan.FromMinutes(30) };

        public async Task<TranscriptionResult> TranscribeAsync(
            string filePath,
            string model,
            string language,
            bool vadEnabled,
            bool filterEnabled,
            bool preferGpu,
            GpuBackend gpuBackend,
            DecodingOptions? decodingOptions = null,
            IProgress<TranscriptionProgress>? progress = null)
        {
            string cudaReason = "";
            var useCuda = preferGpu && gpuBackend == GpuBackend.Cuda && CudaDetector.IsNvidiaCudaAvailable(out cudaReason);
            if (useCuda)
            {
                Environment.SetEnvironmentVariable("GGML_USE_CUBLAS", "1");
                Environment.SetEnvironmentVariable("GGML_CUDA", "1");
                Logger.Info($"CUDA detected: enabling GGML CUDA offload for whisper.net ({cudaReason})");
            }
            else if (preferGpu && !string.IsNullOrEmpty(cudaReason))
            {
                Logger.Warn($"CUDA not available: {cudaReason}");
            }

            // Resolve model path with dynamic download
            var modelPath = await ResolveModelPathAsync(model, progress);
            if (!File.Exists(modelPath))
            {
                throw new FileNotFoundException(
                    $"Model file not found at {modelPath}. Failed to download or place a GGML file there (e.g., ggml-base.bin).");
            }

            // Ensure audio is 16kHz mono PCM
            var compatibleWav = ConvertTo16kMono(filePath);

            Logger.Info($"whisper.net: model={modelPath}, audio={compatibleWav}, lang={language}");

            var segments = new List<TranscriptSegment>();
            string text = "";
            progress?.Report(new TranscriptionProgress(TranscriptionStage.Transcribing, 0, "Transcribing...", IsIndeterminate: false));

            try
            {
                // Check audio file size
                var audioFileInfo = new System.IO.FileInfo(compatibleWav);
                Logger.Info($"Audio file size: {audioFileInfo.Length} bytes");

                if (audioFileInfo.Length < 1000)
                {
                    Logger.Warn($"Audio file is suspiciously small ({audioFileInfo.Length} bytes), may be empty");
                }

                // whisper.net usage
                using var factory = WhisperFactory.FromPath(modelPath);
                var builder = factory.CreateBuilder();
                
                // CUDA support temporarily disabled due to package compatibility
                // if (useCuda)
                // {
                //     builder.WithCuda();
                //     Logger.Info("Using CUDA for transcription acceleration");
                // }
                
                if (!string.IsNullOrWhiteSpace(language) && language != "auto")
                {
                    builder.WithLanguage(language);
                }

                // Apply decoding options if provided
                if (decodingOptions != null)
                {
                    builder.WithTemperature(decodingOptions.Temperature);
                }

                var processor = builder.Build();

                await using var audio = File.OpenRead(compatibleWav);
                Logger.Info($"Audio stream opened, position: {audio.Position}, length: {audio.Length}");

                int segmentCount = 0;
                double totalDurationSeconds = 0;
                try
                {
                    using var probe = new WaveFileReader(compatibleWav);
                    totalDurationSeconds = probe.TotalTime.TotalSeconds;
                }
                catch
                {
                    totalDurationSeconds = 0;
                }

                await foreach (var result in processor.ProcessAsync(audio))
                {
                    segmentCount++;
                    Logger.Info($"Segment {segmentCount}: '{result.Text}' ({result.Start:hh\\:mm\\:ss\\.fff} - {result.End:hh\\:mm\\:ss\\.fff})");

                    var seg = new TranscriptSegment
                    {
                        Timestamp = FormatTimestamp(result.Start),
                        Start = result.Start.TotalSeconds,
                        End = result.End.TotalSeconds,
                        Text = result.Text
                    };
                    segments.Add(seg);
                    text += result.Text;

                    // Report transcription progress if we know the audio duration
                    double progressPercent;
                    var isIndeterminate = totalDurationSeconds <= 0;
                    if (isIndeterminate)
                    {
                        progressPercent = 0;
                    }
                    else
                    {
                        progressPercent = Math.Max(0, Math.Min(100, (result.End.TotalSeconds / totalDurationSeconds) * 100.0));
                    }

                    progress?.Report(new TranscriptionProgress(
                        TranscriptionStage.Transcribing,
                        progressPercent,
                        $"Transcribing... {progressPercent:F0}%",
                        IsIndeterminate: isIndeterminate));
                }

                Logger.Info($"Whisper.net processing complete: {segmentCount} segments yielded");

                var vtt = ExportVtt(segments);

                Logger.Info($"whisper.net complete: {segments.Count} segments, {text.Length} chars");
                return new TranscriptionResult
                {
                    Segments = segments,
                    Text = text,
                    Vtt = vtt
                };
            }
            finally
            {
                // Cleanup temporary converted file if it was created
                if (compatibleWav != filePath && File.Exists(compatibleWav))
                {
                    try
                    {
                        File.Delete(compatibleWav);
                    }
                    catch
                    {
                        // Ignore cleanup errors
                    }
                }
            }
        }

        /// <summary>
        /// Resolves the model path with dynamic download if needed.
        /// </summary>
        private static async Task<string> ResolveModelPathAsync(string model, IProgress<TranscriptionProgress>? progress = null)
        {
            // Allow env override
            var env = Environment.GetEnvironmentVariable("TALKIES_MODEL_PATH");
            if (!string.IsNullOrWhiteSpace(env))
            {
                return env!;
            }

            // Map model names to filenames
            var name = model switch
            {
                "tiny" => "ggml-tiny.bin",
                "base" => "ggml-base.bin",
                "small" => "ggml-small.bin",
                "medium" => "ggml-medium.bin",
                "large" => "ggml-large.bin",
                _ => "ggml-tiny.bin"
            };

            // Place models under user profile .talkies/models
            var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            var modelsDir = Path.Combine(home, ".talkies", "models");
            var modelPath = Path.Combine(modelsDir, name);

            // If model doesn't exist, try to download it
            if (!File.Exists(modelPath))
            {
                Logger.Info($"Model not found at {modelPath}, attempting to download...");
                progress?.Report(new TranscriptionProgress(TranscriptionStage.DownloadModel, 0, $"Downloading {name}...", IsIndeterminate: true));
                await DownloadModelAsync(model, modelPath, progress);
            }

            return modelPath;
        }

        /// <summary>
        /// Downloads a model from HuggingFace if not already present.
        /// </summary>
        private static async Task DownloadModelAsync(string modelName, string targetPath, IProgress<TranscriptionProgress>? progress = null)
        {
            if (!ModelUrls.TryGetValue(modelName, out var url))
            {
                Logger.Error($"Unknown model: {modelName}");
                return;
            }

            try
            {
                // Ensure directory exists
                var directory = Path.GetDirectoryName(targetPath);
                if (!string.IsNullOrEmpty(directory))
                {
                    Directory.CreateDirectory(directory);
                }

                Logger.Info($"Downloading model {modelName} from {url}");

                using var response = await HttpClient.GetAsync(url, HttpCompletionOption.ResponseHeadersRead);
                response.EnsureSuccessStatusCode();

                var totalBytes = response.Content.Headers.ContentLength ?? -1L;
                var canReportProgress = totalBytes != -1;

                using var contentStream = await response.Content.ReadAsStreamAsync();
                using var fileStream = new FileStream(targetPath, FileMode.Create, FileAccess.Write, FileShare.None);

                var totalRead = 0L;
                var buffer = new byte[8192];
                int read;

                if (!canReportProgress)
                {
                    progress?.Report(new TranscriptionProgress(
                        TranscriptionStage.DownloadModel,
                        0,
                        "Downloading model (size unknown)...",
                        IsIndeterminate: true));
                }

                while ((read = await contentStream.ReadAsync(buffer, 0, buffer.Length)) != 0)
                {
                    await fileStream.WriteAsync(buffer, 0, read);
                    totalRead += read;

                    if (canReportProgress)
                    {
                        var progressPercent = (totalRead * 100d) / totalBytes;
                        Logger.Info($"Download progress: {progressPercent:F1}%");
                        progress?.Report(new TranscriptionProgress(
                            TranscriptionStage.DownloadModel,
                            progressPercent,
                            $"Downloading model... {progressPercent:F0}%",
                            IsIndeterminate: false));
                    }
                }

                Logger.Info($"Model {modelName} downloaded successfully to {targetPath}");
                progress?.Report(new TranscriptionProgress(
                    TranscriptionStage.DownloadModel,
                    100,
                    "Model download complete",
                    IsIndeterminate: false));
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to download model {modelName}: {ex.Message}");
                throw;
            }
        }

        private static string ConvertTo16kMono(string inputPath)
        {
            // If already 16k mono PCM, reuse
            try
            {
                using var readerProbe = new WaveFileReader(inputPath);
                if (readerProbe.WaveFormat.SampleRate == 16000 &&
                    readerProbe.WaveFormat.Channels == 1 &&
                    readerProbe.WaveFormat.Encoding == WaveFormatEncoding.Pcm)
                {
                    return inputPath;
                }
            }
            catch
            {
                // ignore and convert
            }

            var target = Path.Combine(Path.GetTempPath(), $"talkies_conv_{Guid.NewGuid():N}.wav");
            var targetFormat = new WaveFormat(16000, 16, 1);

            using var reader = new AudioFileReader(inputPath);
            using var resampler = new MediaFoundationResampler(reader, targetFormat)
            {
                ResamplerQuality = 60
            };
            WaveFileWriter.CreateWaveFile(target, resampler);
            Logger.Info($"Converted audio to 16k mono -> {target}");
            return target;
        }

        /// <summary>
        /// Exports segments to VTT (WebVTT) format.
        /// </summary>
        public string ExportVtt(IEnumerable<TranscriptSegment> segments)
        {
            using var sw = new StringWriter();
            sw.WriteLine("WEBVTT");
            sw.WriteLine();
            foreach (var seg in segments)
            {
                sw.WriteLine($"{seg.Timestamp} --> {FormatTimestamp(seg.End)}");
                sw.WriteLine(seg.Text);
                sw.WriteLine();
            }
            return sw.ToString();
        }

        /// <summary>
        /// Exports segments to SRT (SubRip) format.
        /// </summary>
        public string ExportSrt(IEnumerable<TranscriptSegment> segments)
        {
            using var sw = new StringWriter();
            int index = 1;
            foreach (var seg in segments)
            {
                sw.WriteLine(index++);
                sw.WriteLine($"{FormatSrtTime(seg.Start)} --> {FormatSrtTime(seg.End)}");
                sw.WriteLine(seg.Text);
                sw.WriteLine();
            }
            return sw.ToString();
        }

        /// <summary>
        /// Exports segments to plain text format.
        /// </summary>
        public string ExportTxt(IEnumerable<TranscriptSegment> segments)
        {
            var lines = segments.Select(s => s.Text);
            return string.Join(Environment.NewLine, lines);
        }

        private static string FormatTimestamp(TimeSpan ts)
        {
            return $"{(int)ts.TotalHours:00}:{ts.Minutes:00}:{ts.Seconds:00}.{ts.Milliseconds:000}";
        }

        private static string FormatTimestamp(double seconds)
        {
            var ts = TimeSpan.FromSeconds(seconds);
            return $"{(int)ts.TotalHours:00}:{ts.Minutes:00}:{ts.Seconds:00}.{ts.Milliseconds:000}";
        }

        /// <summary>
        /// Formats timestamp for SRT format (uses comma instead of period for milliseconds).
        /// </summary>
        private static string FormatSrtTime(double seconds)
        {
            var ts = TimeSpan.FromSeconds(seconds);
            return $"{(int)ts.TotalHours:00}:{ts.Minutes:00}:{ts.Seconds:00},{ts.Milliseconds:000}";
        }

        public void Dispose()
        {
            // Nothing to dispose
        }
    }
}
