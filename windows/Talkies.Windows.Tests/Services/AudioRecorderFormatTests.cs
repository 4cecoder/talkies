using System;
using NAudio.Wave;
using Talkies.Windows.Services;
using Xunit;

namespace Talkies.Windows.Tests.Services
{
    public class AudioRecorderFormatTests
    {
        [Fact]
        public void GetWaveFormatForCapturedData_PreservesWasapiSourceFormat()
        {
            var wasapiFormat = WaveFormat.CreateIeeeFloatWaveFormat(48000, 2);

            var recordingFormat = AudioRecorder.GetWaveFormatForCapturedData(wasapiFormat);

            Assert.Same(wasapiFormat, recordingFormat);
            Assert.Equal(48000, recordingFormat.SampleRate);
            Assert.Equal(2, recordingFormat.Channels);
            Assert.Equal(32, recordingFormat.BitsPerSample);
            Assert.Equal(WaveFormatEncoding.IeeeFloat, recordingFormat.Encoding);
        }

        [Fact]
        public void CalculatePeakLevel_UsesFloatCaptureFormat()
        {
            var samples = new[] { 0.25f, -0.75f };
            var bytes = System.Runtime.InteropServices.MemoryMarshal.AsBytes(samples.AsSpan()).ToArray();

            var peak = AudioRecorder.CalculatePeakLevel(bytes, WaveFormat.CreateIeeeFloatWaveFormat(48000, 2));

            Assert.Equal(0.75f, peak, 4);
        }

        [Fact]
        public void CalculatePeakLevel_UsesExtensiblePcmCaptureFormat()
        {
            var bytes = new byte[] { 0x00, 0x20, 0x00, 0xA0 };
            var format = new WaveFormatExtensible(48000, 16, 2, 16);

            var peak = AudioRecorder.CalculatePeakLevel(bytes, format);

            Assert.Equal(0.75f, peak, 4);
        }

        [Fact]
        public void CalculatePeakLevel_UsesPcmBitDepth()
        {
            var bytes = new byte[] { 0x00, 0x40, 0x00, 0x80 };

            var peak = AudioRecorder.CalculatePeakLevel(bytes, new WaveFormat(16000, 16, 1));

            Assert.Equal(1f, peak, 4);
        }
    }
}
