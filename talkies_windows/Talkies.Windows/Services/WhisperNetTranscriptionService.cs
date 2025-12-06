using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using NAudio.Wave;
using Whisper.net;
using Whisper.net.Ggml;
using Talkies.Windows.Models;

namespace Talkies.Windows.Services
{
    /// <summary>
    /// Native transcription using whisper.net (no Python). Requires a GGML model file.
    /// </summary>
    public class WhisperNetTranscriptionService : ITranscriptionService
    {
        public async Task<TranscriptionResult> TranscribeAsync(string filePath, string model, string language, bool vadEnabled, bool filterEnabled)
        {
            // Resolve model path
            var modelPath = ResolveModelPath(model);
            if (!File.Exists(modelPath))
            {
                throw new FileNotFoundException($"Model file not found at {modelPath}. Place a GGML file there (e.g., ggml-base.bin).");
            }

            // Ensure audio is 16kHz mono PCM
            var compatibleWav = ConvertTo16kMono(filePath);

            Logger.Info($"whisper.net: model={modelPath}, audio={compatibleWav}, lang={language}");

            var segments = new List<TranscriptSegment>();
            string text = "";

            // whisper.net usage
            using var factory = WhisperFactory.FromPath(modelPath);
            var builder = factory.CreateBuilder();
            if (!string.IsNullOrWhiteSpace(language) && language != "auto")
            {
                builder.WithLanguage(language);
            }
            var processor = builder.Build();

            await using var audio = File.OpenRead(compatibleWav);
            await foreach (var result in processor.ProcessAsync(audio))
            {
                var seg = new TranscriptSegment
                {
                    Timestamp = FormatTimestamp(result.Start),
                    Start = result.Start.TotalSeconds,
                    End = result.End.TotalSeconds,
                    Text = result.Text
                };
                segments.Add(seg);
                text += result.Text;
            }

            var vtt = BuildVtt(segments);

            Logger.Info($"whisper.net complete: {segments.Count} segments, {text.Length} chars");
            return new TranscriptionResult
            {
                Segments = segments,
                Text = text,
                Vtt = vtt
            };
        }

        private static string ResolveModelPath(string model)
        {
            // Allow env override
            var env = Environment.GetEnvironmentVariable("TALKIES_MODEL_PATH");
            if (!string.IsNullOrWhiteSpace(env))
            {
                return env!;
            }

            // Hardcoded default path to tiny model (user-specified)
            const string defaultTiny = @"C:\Users\admin\prog\talkies\talkies_windows\Talkies.Windows\bin\Debug\net8.0-windows\models\ggml-tiny.bin";
            return defaultTiny;
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

        private static string BuildVtt(IEnumerable<TranscriptSegment> segments)
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

        private static string FormatTimestamp(TimeSpan ts)
        {
            return $"{(int)ts.TotalHours:00}:{ts.Minutes:00}:{ts.Seconds:00}.{ts.Milliseconds:000}";
        }

        private static string FormatTimestamp(double seconds)
        {
            var ts = TimeSpan.FromSeconds(seconds);
            return $"{(int)ts.TotalHours:00}:{ts.Minutes:00}:{ts.Seconds:00}.{ts.Milliseconds:000}";
        }
    }
}
