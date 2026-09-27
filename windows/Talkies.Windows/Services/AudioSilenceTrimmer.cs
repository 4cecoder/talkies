using System;
using System.Collections.Generic;
using System.IO;
using NAudio.Wave;

namespace Talkies.Windows.Services
{
    /// <summary>
    /// Conservatively removes leading and trailing silence from Whisper-ready audio.
    /// If the format or voice activity is uncertain, the source file is preserved.
    /// </summary>
    internal static class AudioSilenceTrimmer
    {
        private const int SampleRate = 16000;
        private const int FrameDurationMilliseconds = 20;
        private const int PaddingDurationMilliseconds = 240;
        private const float MinimumFrameRms = 0.004f;

        private const int SamplesPerFrame = SampleRate * FrameDurationMilliseconds / 1000;
        private const int BytesPerFrame = SamplesPerFrame * sizeof(short);
        private const int PaddingFrames = PaddingDurationMilliseconds / FrameDurationMilliseconds;

        /// <summary>
        /// Returns a temporary trimmed WAV path when silence can be removed safely;
        /// otherwise returns <paramref name="audioPath"/> unchanged.
        /// The caller owns and must delete any different path returned.
        /// </summary>
        internal static string TrimLeadingAndTrailingSilence(string audioPath)
        {
            try
            {
                using var reader = new WaveFileReader(audioPath);
                var format = reader.WaveFormat;
                if (format.SampleRate != SampleRate ||
                    format.Channels != 1 ||
                    format.Encoding != WaveFormatEncoding.Pcm ||
                    format.BitsPerSample != 16 ||
                    format.BlockAlign != sizeof(short))
                {
                    return audioPath;
                }

                var frameLevels = ReadFrameLevels(reader);
                var firstVoiceFrame = frameLevels.FindIndex(level => level >= MinimumFrameRms);
                var lastVoiceFrame = frameLevels.FindLastIndex(level => level >= MinimumFrameRms);
                if (firstVoiceFrame < 0 || lastVoiceFrame < firstVoiceFrame)
                {
                    return audioPath;
                }

                var startFrame = Math.Max(0, firstVoiceFrame - PaddingFrames);
                var endFrameExclusive = Math.Min(frameLevels.Count, lastVoiceFrame + PaddingFrames + 1);
                var dataLength = reader.Length;
                var startOffset = Math.Min((long)startFrame * BytesPerFrame, dataLength);
                var endOffset = Math.Min((long)endFrameExclusive * BytesPerFrame, dataLength);
                if (endOffset <= startOffset || (startOffset <= 0 && endOffset >= dataLength))
                {
                    return audioPath;
                }

                var trimmedPath = Path.Combine(Path.GetTempPath(), $"talkies-vad-{Guid.NewGuid():N}.wav");
                try
                {
                    WriteTrimmedAudio(reader, trimmedPath, format, startOffset, endOffset - startOffset);
                    Logger.Info($"VAD trimmed {(startOffset + dataLength - endOffset) / (double)(SampleRate * sizeof(short)):F2}s of leading/trailing silence");
                    return trimmedPath;
                }
                catch
                {
                    TryDelete(trimmedPath);
                    throw;
                }
            }
            catch (Exception exception)
            {
                Logger.Warn($"VAD silence trimming skipped; preserving original audio: {exception.Message}");
                return audioPath;
            }
        }

        private static List<float> ReadFrameLevels(WaveFileReader reader)
        {
            var levels = new List<float>();
            var buffer = new byte[BytesPerFrame];
            while (true)
            {
                var bytesRead = reader.Read(buffer, 0, buffer.Length);
                if (bytesRead <= 0)
                {
                    break;
                }

                var sampleCount = bytesRead / sizeof(short);
                if (sampleCount == 0)
                {
                    break;
                }

                double sumSquares = 0;
                for (var offset = 0; offset + 1 < bytesRead; offset += sizeof(short))
                {
                    var sample = (short)(buffer[offset] | (buffer[offset + 1] << 8));
                    var normalized = sample / 32768.0;
                    sumSquares += normalized * normalized;
                }

                levels.Add((float)Math.Sqrt(sumSquares / sampleCount));
            }

            return levels;
        }

        private static void WriteTrimmedAudio(WaveFileReader reader, string path, WaveFormat format, long startOffset, long byteCount)
        {
            reader.Position = startOffset;
            using var writer = new WaveFileWriter(path, format);
            var buffer = new byte[BytesPerFrame * 32];
            while (byteCount > 0)
            {
                var requested = (int)Math.Min(buffer.Length, byteCount);
                var bytesRead = reader.Read(buffer, 0, requested);
                if (bytesRead <= 0)
                {
                    throw new EndOfStreamException("Audio file ended before the trimmed segment was written.");
                }

                writer.Write(buffer, 0, bytesRead);
                byteCount -= bytesRead;
            }
        }

        private static void TryDelete(string path)
        {
            try
            {
                if (File.Exists(path))
                {
                    File.Delete(path);
                }
            }
            catch
            {
                // Preserve the original transcription path even if temp cleanup fails.
            }
        }
    }
}
