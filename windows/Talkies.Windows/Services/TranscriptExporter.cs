using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using Talkies.Windows.Models;

namespace Talkies.Windows.Services
{
    public class TranscriptExporter
    {
        /// <summary>
        /// Exports transcript segments to SRT (SubRip) format.
        /// </summary>
        public static string ExportToSrt(IEnumerable<TranscriptSegment> segments)
        {
            var sb = new StringBuilder();
            int index = 1;

            foreach (var segment in segments)
            {
                sb.AppendLine(index.ToString());
                sb.AppendLine($"{FormatSrtTime(segment.Start)} --> {FormatSrtTime(segment.End)}");
                sb.AppendLine(segment.Text);
                sb.AppendLine();
                index++;
            }

            return sb.ToString();
        }

        /// <summary>
        /// Exports transcript segments to plain text format with timestamps.
        /// </summary>
        public static string ExportToTxt(IEnumerable<TranscriptSegment> segments)
        {
            var sb = new StringBuilder();

            foreach (var segment in segments)
            {
                sb.AppendLine($"[{segment.Timestamp}] {segment.Text}");
            }

            return sb.ToString();
        }

        /// <summary>
        /// Exports transcript segments to WebVTT format.
        /// </summary>
        public static string ExportToVtt(IEnumerable<TranscriptSegment> segments)
        {
            var sb = new StringBuilder();
            sb.AppendLine("WEBVTT");
            sb.AppendLine();

            foreach (var segment in segments)
            {
                sb.AppendLine($"{FormatVttTime(segment.Start)} --> {FormatVttTime(segment.End)}");
                sb.AppendLine(segment.Text);
                sb.AppendLine();
            }

            return sb.ToString();
        }

        /// <summary>
        /// Exports transcript segments to plain text without timestamps.
        /// </summary>
        public static string ExportToPlainText(IEnumerable<TranscriptSegment> segments)
        {
            var sb = new StringBuilder();

            foreach (var segment in segments)
            {
                if (!string.IsNullOrWhiteSpace(segment.Text))
                {
                    sb.AppendLine(segment.Text);
                }
            }

            return sb.ToString();
        }

        /// <summary>
        /// Saves content to a file with UTF-8 encoding.
        /// </summary>
        public static void SaveToFile(string filePath, string content)
        {
            try
            {
                File.WriteAllText(filePath, content, Encoding.UTF8);
                Logger.Success($"Exported transcript to {Path.GetFileName(filePath)}");
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to export transcript: {ex.Message}");
                throw;
            }
        }

        /// <summary>
        /// Formats time in VTT format: HH:MM:SS.mmm
        /// </summary>
        private static string FormatVttTime(double seconds)
        {
            var ts = TimeSpan.FromSeconds(seconds);
            return $"{ts.Hours:D2}:{ts.Minutes:D2}:{ts.Seconds:D2}.{ts.Milliseconds:D3}";
        }

        /// <summary>
        /// Formats time in SRT format: HH:MM:SS,mmm
        /// </summary>
        private static string FormatSrtTime(double seconds)
        {
            var ts = TimeSpan.FromSeconds(seconds);
            return $"{ts.Hours:D2}:{ts.Minutes:D2}:{ts.Seconds:D2},{ts.Milliseconds:D3}";
        }
    }
}
