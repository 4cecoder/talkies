using System;
using System.Collections.Generic;
using System.IO;
using NAudio.Wave;

namespace Talkies.Windows.Services
{
    /// <summary>Converts recordings to the 16 kHz mono PCM both local recognizers expect.</summary>
    internal static class Pcm16kMonoAudio
    {
        public const int SampleRate = 16000;

        /// <summary>Returns the input when it is already 16 kHz mono PCM, otherwise a temporary converted copy.</summary>
        public static string ConvertTo16kMono(string inputPath)
        {
            try
            {
                using var readerProbe = new WaveFileReader(inputPath);
                if (readerProbe.WaveFormat.SampleRate == SampleRate &&
                    readerProbe.WaveFormat.Channels == 1 &&
                    readerProbe.WaveFormat.Encoding == WaveFormatEncoding.Pcm)
                {
                    return inputPath;
                }
            }
            catch
            {
                // Not a readable PCM WAV; convert below.
            }

            var target = Path.Combine(Path.GetTempPath(), $"talkies_conv_{Guid.NewGuid():N}.wav");
            var targetFormat = new WaveFormat(SampleRate, 16, 1);

            using var reader = new AudioFileReader(inputPath);
            using var resampler = new MediaFoundationResampler(reader, targetFormat)
            {
                ResamplerQuality = 60
            };
            WaveFileWriter.CreateWaveFile(target, resampler);
            Logger.Info($"Converted audio to 16k mono -> {target}");
            return target;
        }

        /// <summary>Reads a 16 kHz mono WAV as normalized float samples.</summary>
        public static float[] ReadSamples(string wavPath)
        {
            using var reader = new WaveFileReader(wavPath);
            if (reader.WaveFormat.SampleRate != SampleRate || reader.WaveFormat.Channels != 1)
                throw new InvalidDataException($"Expected 16 kHz mono audio, got {reader.WaveFormat.SampleRate} Hz with {reader.WaveFormat.Channels} channel(s).");

            var provider = reader.ToSampleProvider();
            var samples = new List<float>(checked((int)Math.Min(int.MaxValue, reader.SampleCount)));
            var buffer = new float[SampleRate];
            int read;
            while ((read = provider.Read(buffer, 0, buffer.Length)) > 0)
            {
                for (var i = 0; i < read; i++) samples.Add(buffer[i]);
            }
            return samples.ToArray();
        }

        public static void DeleteTemporary(string path, string original)
        {
            if (string.Equals(path, original, StringComparison.OrdinalIgnoreCase) || !File.Exists(path)) return;
            try
            {
                File.Delete(path);
            }
            catch (IOException ex)
            {
                Logger.Debug($"Could not delete temporary audio {path}: {ex.Message}");
            }
            catch (UnauthorizedAccessException ex)
            {
                Logger.Debug($"Could not delete temporary audio {path}: {ex.Message}");
            }
        }
    }
}
