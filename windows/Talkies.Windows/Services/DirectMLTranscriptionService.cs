using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Threading.Tasks;
using Microsoft.ML.OnnxRuntime;
using Microsoft.ML.OnnxRuntime.Tensors;
using NAudio.Wave;
using Talkies.Windows.Models;

namespace Talkies.Windows.Services
{
    /// <summary>
    /// DirectML-based transcription using ONNX Runtime with DirectML execution provider.
    /// Supports AMD, Intel, and NVIDIA GPUs via DirectML.
    /// </summary>
    public class DirectMLTranscriptionService : ITranscriptionService
    {
        private static readonly HttpClient HttpClient = new() { Timeout = TimeSpan.FromMinutes(30) };

        // ONNX Whisper model URLs (converted from PyTorch models)
        private static readonly Dictionary<string, (string EncoderUrl, string DecoderUrl)> OnnxModelUrls = new()
        {
            { "tiny", ("https://huggingface.co/onnx-community/whisper-tiny/resolve/main/encoder_model.onnx", "https://huggingface.co/onnx-community/whisper-tiny/resolve/main/decoder_model.onnx") },
            { "base", ("https://huggingface.co/onnx-community/whisper-base/resolve/main/encoder_model.onnx", "https://huggingface.co/onnx-community/whisper-base/resolve/main/decoder_model.onnx") },
            { "small", ("https://huggingface.co/onnx-community/whisper-small/resolve/main/encoder_model.onnx", "https://huggingface.co/onnx-community/whisper-small/resolve/main/decoder_model.onnx") }
        };

        private InferenceSession? _encoderSession;
        private InferenceSession? _decoderSession;

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
            try
            {
                // Ensure models are loaded
                await EnsureModelsAsync(model, progress);

                // Convert audio to 16kHz mono PCM
                var compatibleWav = ConvertTo16kMono(filePath);

                Logger.Info($"DirectML: model={model}, audio={compatibleWav}, lang={language}");

                var segments = new List<TranscriptSegment>();
                string text = "";
                progress?.Report(new TranscriptionProgress(TranscriptionStage.Transcribing, 0, "Transcribing with DirectML...", IsIndeterminate: false));

                try
                {
                    // Load and process audio
                    using var reader = new WaveFileReader(compatibleWav);
                    var audioData = ReadAudioData(reader);

                    // Run encoder
                    var melSpectrogram = await RunEncoderAsync(audioData);

                    // Run decoder with beam search
                    var transcriptionTokens = await RunDecoderAsync(melSpectrogram, language);

                    // Convert tokens to text and segments
                    (text, segments) = DecodeTokens(transcriptionTokens);

                    Logger.Info($"DirectML transcription complete: {segments.Count} segments, {text.Length} chars");
                    return new TranscriptionResult
                    {
                        Segments = segments,
                        Text = text,
                        Vtt = ExportVtt(segments)
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
            catch (Exception ex)
            {
                Logger.Error($"DirectML transcription failed: {ex.Message}");
                throw;
            }
        }

        private async Task EnsureModelsAsync(string model, IProgress<TranscriptionProgress>? progress = null)
        {
            if (!OnnxModelUrls.TryGetValue(model, out var urls))
            {
                throw new ArgumentException($"Unsupported model: {model}");
            }

            var modelsDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".talkies", "models", "onnx");
            Directory.CreateDirectory(modelsDir);

            var encoderPath = Path.Combine(modelsDir, $"{model}_encoder.onnx");
            var decoderPath = Path.Combine(modelsDir, $"{model}_decoder.onnx");

            // Download models if they don't exist
            if (!File.Exists(encoderPath))
            {
                Logger.Info($"Downloading DirectML encoder model: {model}");
                progress?.Report(new TranscriptionProgress(TranscriptionStage.DownloadModel, 0, $"Downloading {model} encoder...", IsIndeterminate: true));
                await DownloadFileAsync(urls.EncoderUrl, encoderPath);
            }

            if (!File.Exists(decoderPath))
            {
                Logger.Info($"Downloading DirectML decoder model: {model}");
                progress?.Report(new TranscriptionProgress(TranscriptionStage.DownloadModel, 50, $"Downloading {model} decoder...", IsIndeterminate: true));
                await DownloadFileAsync(urls.DecoderUrl, decoderPath);
            }

            // Create ONNX Runtime sessions with DirectML
            var sessionOptions = new SessionOptions();
            if (GpuDetector.IsDirectMlAvailable())
            {
                sessionOptions.AppendExecutionProvider_DML(0); // Use first GPU
                Logger.Info("Using DirectML execution provider for GPU acceleration");
            }
            else
            {
                Logger.Warn("DirectML not available, falling back to CPU");
            }

            _encoderSession = new InferenceSession(encoderPath, sessionOptions);
            _decoderSession = new InferenceSession(decoderPath, sessionOptions);

            progress?.Report(new TranscriptionProgress(TranscriptionStage.DownloadModel, 100, "Models ready", IsIndeterminate: false));
        }

        private float[] ReadAudioData(WaveFileReader reader)
        {
            var samples = new List<float>();
            using var resampler = new MediaFoundationResampler(reader, new WaveFormat(16000, 1));
            var buffer = new byte[4096];
            int bytesRead;
            while ((bytesRead = resampler.Read(buffer, 0, buffer.Length)) > 0)
            {
                for (int i = 0; i < bytesRead / 2; i++) // 16-bit samples
                {
                    var sample = BitConverter.ToInt16(buffer, i * 2) / 32768f;
                    samples.Add(sample);
                }
            }
            return samples.ToArray();
        }

        private async Task<Tensor<float>> RunEncoderAsync(float[] audioData)
        {
            return await Task.Run(() =>
            {
                if (_encoderSession == null)
                    throw new InvalidOperationException("Encoder session not initialized");

                // Create input tensor - audio data should be shaped appropriately for Whisper
                // This is a simplified implementation - actual Whisper ONNX models have specific input requirements
                var inputTensor = new DenseTensor<float>(audioData, new int[] { 1, audioData.Length });

                var inputs = new List<NamedOnnxValue>
                {
                    NamedOnnxValue.CreateFromTensor("input_features", inputTensor)
                };

                using var results = _encoderSession.Run(inputs);
                return results.First().AsTensor<float>();
            });
        }

        private async Task<int[]> RunDecoderAsync(Tensor<float> melSpectrogram, string language)
        {
            return await Task.Run(() =>
            {
                if (_decoderSession == null)
                    throw new InvalidOperationException("Decoder session not initialized");

                // Simplified decoder implementation
                // Actual implementation would need proper token generation with beam search
                var startToken = 50258; // <|startoftranscript|>
                var tokens = new List<int> { startToken };

                // For now, return a basic implementation
                // This would need to be expanded with proper Whisper decoder logic
                return tokens.ToArray();
            });
        }

        private (string text, List<TranscriptSegment> segments) DecodeTokens(int[] tokens)
        {
            // Simplified token decoding
            // This would need a proper tokenizer implementation
            var text = "DirectML transcription placeholder - needs tokenizer implementation";
            var segments = new List<TranscriptSegment>
            {
                new TranscriptSegment
                {
                    Timestamp = "00:00:00.000",
                    Start = 0,
                    End = 10,
                    Text = text
                }
            };

            return (text, segments);
        }

        private string ConvertTo16kMono(string inputPath)
        {
            // Reuse the same conversion logic from WhisperNetTranscriptionService
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

        private static async Task DownloadFileAsync(string url, string destinationPath)
        {
            using var response = await HttpClient.GetAsync(url, HttpCompletionOption.ResponseHeadersRead);
            response.EnsureSuccessStatusCode();

            using var contentStream = await response.Content.ReadAsStreamAsync();
            using var fileStream = new FileStream(destinationPath, FileMode.Create, FileAccess.Write, FileShare.None);
            await contentStream.CopyToAsync(fileStream);
        }

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

        public string ExportTxt(IEnumerable<TranscriptSegment> segments)
        {
            var lines = segments.Select(s => s.Text);
            return string.Join(Environment.NewLine, lines);
        }

        private static string FormatTimestamp(double seconds)
        {
            var ts = TimeSpan.FromSeconds(seconds);
            return $"{(int)ts.TotalHours:00}:{ts.Minutes:00}:{ts.Seconds:00}.{ts.Milliseconds:000}";
        }

        private static string FormatSrtTime(double seconds)
        {
            var ts = TimeSpan.FromSeconds(seconds);
            return $"{(int)ts.TotalHours:00}:{ts.Minutes:00}:{ts.Seconds:00},{ts.Milliseconds:000}";
        }

        public void Dispose()
        {
            _encoderSession?.Dispose();
            _decoderSession?.Dispose();
            _encoderSession = null;
            _decoderSession = null;
        }
    }
}
