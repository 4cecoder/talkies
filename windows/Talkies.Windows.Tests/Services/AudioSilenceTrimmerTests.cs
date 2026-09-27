using System;
using System.IO;
using NAudio.Wave;
using Talkies.Windows.Services;
using Xunit;

namespace Talkies.Windows.Tests.Services
{
    public class AudioSilenceTrimmerTests
    {
        [Fact]
        public void TrimLeadingAndTrailingSilence_KeepsVoiceAndAddsPadding()
        {
            var inputPath = CreateWav(writer =>
            {
                WriteSilence(writer, seconds: 2);
                WriteTone(writer, seconds: 1, amplitude: 0.25f);
                WriteSilence(writer, seconds: 2);
            });
            var outputPath = AudioSilenceTrimmer.TrimLeadingAndTrailingSilence(inputPath);

            try
            {
                Assert.NotEqual(inputPath, outputPath);
                using var input = new WaveFileReader(inputPath);
                using var output = new WaveFileReader(outputPath);
                Assert.Equal(5, input.TotalTime.TotalSeconds, precision: 2);
                Assert.InRange(output.TotalTime.TotalSeconds, 1.45, 1.52);
            }
            finally
            {
                DeleteIfDifferent(outputPath, inputPath);
                File.Delete(inputPath);
            }
        }

        [Fact]
        public void TrimLeadingAndTrailingSilence_PreservesAudioWhenNoVoiceIsDetected()
        {
            var inputPath = CreateWav(writer =>
            {
                WriteSilence(writer, seconds: 2);
                WriteTone(writer, seconds: 1, amplitude: 0.001f);
                WriteSilence(writer, seconds: 2);
            });

            var outputPath = AudioSilenceTrimmer.TrimLeadingAndTrailingSilence(inputPath);

            Assert.Equal(inputPath, outputPath);
            Assert.True(File.Exists(inputPath));
            File.Delete(inputPath);
        }

        [Fact]
        public void TrimLeadingAndTrailingSilence_KeepsQuietSpeechBeforeLouderSpeech()
        {
            var inputPath = CreateWav(writer =>
            {
                WriteSilence(writer, seconds: 2);
                WriteTone(writer, seconds: 1, amplitude: 0.006f);
                WriteTone(writer, seconds: 1, amplitude: 0.25f);
                WriteSilence(writer, seconds: 2);
            });
            var outputPath = AudioSilenceTrimmer.TrimLeadingAndTrailingSilence(inputPath);

            try
            {
                Assert.NotEqual(inputPath, outputPath);
                using var output = new WaveFileReader(outputPath);
                Assert.InRange(output.TotalTime.TotalSeconds, 2.45, 2.52);
            }
            finally
            {
                DeleteIfDifferent(outputPath, inputPath);
                File.Delete(inputPath);
            }
        }

        private static string CreateWav(Action<WaveFileWriter> writeAudio)
        {
            var path = Path.Combine(Path.GetTempPath(), $"talkies-vad-test-{Guid.NewGuid():N}.wav");
            using var writer = new WaveFileWriter(path, new WaveFormat(16000, 16, 1));
            writeAudio(writer);
            return path;
        }

        private static void WriteSilence(WaveFileWriter writer, int seconds)
        {
            writer.Write(new byte[16000 * sizeof(short) * seconds], 0, 16000 * sizeof(short) * seconds);
        }

        private static void WriteTone(WaveFileWriter writer, int seconds, float amplitude)
        {
            var sampleCount = 16000 * seconds;
            var samples = new byte[sampleCount * sizeof(short)];
            for (var index = 0; index < sampleCount; index++)
            {
                var sample = (short)(Math.Sin(2 * Math.PI * 440 * index / 16000) * amplitude * short.MaxValue);
                samples[index * sizeof(short)] = (byte)(sample & 0xFF);
                samples[index * sizeof(short) + 1] = (byte)((sample >> 8) & 0xFF);
            }

            writer.Write(samples, 0, samples.Length);
        }

        private static void DeleteIfDifferent(string firstPath, string secondPath)
        {
            if (!string.Equals(firstPath, secondPath, StringComparison.Ordinal) && File.Exists(firstPath))
            {
                File.Delete(firstPath);
            }
        }
    }
}
