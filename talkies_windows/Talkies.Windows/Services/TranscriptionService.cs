using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Talkies.Windows.Models;

namespace Talkies.Windows.Services
{
    public class TranscriptionResult
    {
        public List<TranscriptSegment> Segments { get; set; } = new();
        public string Text { get; set; } = string.Empty;
        public string Vtt { get; set; } = string.Empty;
    }

    public interface ITranscriptionService
    {
        Task<TranscriptionResult> TranscribeAsync(string filePath, string model, string language, bool vadEnabled, bool filterEnabled);
    }

    /// <summary>
    /// Runs the existing python CLI in file mode and parses JSON to hydrate segments/VTT.
    /// </summary>
    public class TranscriptionService : ITranscriptionService
    {
        private readonly Func<string> _pythonResolver;

        public TranscriptionService()
        {
            _pythonResolver = PythonLocator.ResolvePython;
        }

        public TranscriptionService(Func<string> pythonResolver)
        {
            _pythonResolver = pythonResolver;
        }

        public async Task<TranscriptionResult> TranscribeAsync(string filePath, string model, string language, bool vadEnabled, bool filterEnabled)
        {
            var outputJson = Path.Combine(Path.GetTempPath(), $"talkies_{Guid.NewGuid():N}.json");

            var args = new StringBuilder();
            args.Append("-m whisper_cli.cli transcribe ");
            args.Append($"\"{filePath}\" ");
            if (!string.IsNullOrWhiteSpace(model)) args.Append($"--model \"{model}\" ");
            if (!string.IsNullOrWhiteSpace(language) && language != "auto") args.Append($"--language \"{language}\" ");
            // Always force VTT output path and JSON path
            args.Append($"--format json --output \"{outputJson}\"");

            Logger.Info($"Transcribe start: {filePath} model={model} lang={language}");

            var psi = new ProcessStartInfo
            {
                FileName = _pythonResolver(),
                Arguments = args.ToString(),
                UseShellExecute = false,
                RedirectStandardError = true,
                CreateNoWindow = true,
                WorkingDirectory = AppDomain.CurrentDomain.BaseDirectory
            };

            using var proc = Process.Start(psi);
            if (proc == null) throw new InvalidOperationException("Failed to start python process");
            var stderr = await proc.StandardError.ReadToEndAsync();
            await proc.WaitForExitAsync();
            if (proc.ExitCode != 0)
            {
                Logger.Error($"Transcribe failed (code {proc.ExitCode}): {stderr}");
                throw new InvalidOperationException($"Transcription failed: {stderr}");
            }

            if (!File.Exists(outputJson))
            {
                throw new FileNotFoundException("Transcription output not found", outputJson);
            }

            var jsonText = await File.ReadAllTextAsync(outputJson);
            dynamic parsed = JsonConvert.DeserializeObject(jsonText) ?? throw new InvalidOperationException("Invalid JSON output");

            var segments = new List<TranscriptSegment>();
            var textBuilder = new StringBuilder();

            foreach (var seg in parsed.segments)
            {
                string t = (string)seg.text;
                double start = (double)seg.start;
                double end = (double)seg.end;
                segments.Add(new TranscriptSegment
                {
                    Timestamp = FormatTimestamp(start),
                    Text = t,
                    Start = start,
                    End = end
                });
                textBuilder.Append(t);
            }

            // Build VTT locally
            var vttBuilder = new StringBuilder();
            vttBuilder.AppendLine("WEBVTT");
            vttBuilder.AppendLine();
            foreach (var seg in segments)
            {
                vttBuilder.AppendLine($"{seg.Timestamp} --> {FormatTimestamp(seg.End)}");
                vttBuilder.AppendLine(seg.Text);
                vttBuilder.AppendLine();
            }

            // Cleanup temp file
            try { File.Delete(outputJson); } catch { /* ignore */ }

            Logger.Info($"Transcribe complete: {segments.Count} segments, {textBuilder.Length} chars");
            return new TranscriptionResult
            {
                Segments = segments,
                Text = textBuilder.ToString(),
                Vtt = vttBuilder.ToString()
            };
        }

        private static string FormatTimestamp(double seconds)
        {
            var ts = TimeSpan.FromSeconds(seconds);
            return $"{(int)ts.TotalHours:00}:{ts.Minutes:00}:{ts.Seconds:00}.{ts.Milliseconds:000}";
        }
    }
}
