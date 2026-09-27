using System;
using System.IO;
using NAudio.CoreAudioApi;
using NAudio.Wave;
using Talkies.Windows.Models;

namespace Talkies.Windows.Services
{
    public class RecordingCompletedEventArgs : EventArgs
    {
        public string FilePath { get; init; } = string.Empty;
    }

    public interface IAudioRecorder : IDisposable
    {
        event EventHandler<RecordingCompletedEventArgs>? RecordingCompleted;
        event EventHandler<float>? LevelChanged;
        bool IsRecording { get; }
        TimeSpan Duration { get; }
        void Start(string? deviceId = null, AudioQualitySettings? qualitySettings = null);
        void Stop();
    }

    /// <summary>
    /// WASAPI loop-free microphone recorder. Captures mono PCM to a temp WAV, reports RMS level and duration.
    /// </summary>
    public class AudioRecorder : IAudioRecorder
    {
        private WasapiCapture? _capture;
        private WaveFileWriter? _writer;
        private DateTime _startTime;
        private readonly string _tempDir = Path.Combine(Path.GetTempPath(), "talkies_win");
        private string? _currentFile;

        public event EventHandler<RecordingCompletedEventArgs>? RecordingCompleted;
        public event EventHandler<float>? LevelChanged;

        public bool IsRecording { get; private set; }
        public TimeSpan Duration => IsRecording ? DateTime.UtcNow - _startTime : TimeSpan.Zero;

        public void Start(string? deviceId = null, AudioQualitySettings? qualitySettings = null)
        {
            if (IsRecording) return;

            Directory.CreateDirectory(_tempDir);
            _currentFile = Path.Combine(_tempDir, $"rec_{DateTime.UtcNow:yyyyMMdd_HHmmss}.wav");

            MMDevice? device = null;
            var useLoopback = string.Equals(deviceId, "__loopback", StringComparison.OrdinalIgnoreCase);

            try
            {
                if (!string.IsNullOrWhiteSpace(deviceId) && !useLoopback)
                {
                    var enumerator = new MMDeviceEnumerator();
                    device = enumerator.GetDevice(deviceId);
                }
            }
            catch
            {
                device = null;
            }

            _capture = useLoopback
                ? new WasapiLoopbackCapture()
                : device == null
                    ? new WasapiCapture()
                    : new WasapiCapture(device);

            _capture.ShareMode = AudioClientShareMode.Shared;
            _capture.DataAvailable += OnData;
            _capture.RecordingStopped += OnStopped;

            // Shared-mode WASAPI capture delivers the device mix format. The bytes in
            // DataAvailable are in that format; labeling them with the requested
            // quality format corrupts the WAV whenever the formats differ. Keep the
            // source format here. WhisperNetTranscriptionService resamples the saved
            // WAV to its required 16 kHz mono format before inference.
            var waveFormat = GetWaveFormatForCapturedData(_capture.WaveFormat);
            if (qualitySettings != null && !HasSameFormat(qualitySettings, waveFormat))
            {
                Logger.Info($"WASAPI shared-mode capture cannot apply requested recording format {qualitySettings.SampleRateHz}Hz/{qualitySettings.ChannelCount}ch/{qualitySettings.BitsPerSample}bit without conversion; recording source format {waveFormat.SampleRate}Hz/{waveFormat.Channels}ch/{waveFormat.BitsPerSample}bit instead");
            }

            _writer = new WaveFileWriter(_currentFile, waveFormat);
            Logger.Info($"Audio source: {(useLoopback ? "Loopback" : "Microphone")} | Format: {waveFormat.SampleRate}Hz, {waveFormat.Channels}ch, {waveFormat.BitsPerSample}bit");

            _capture.StartRecording();
            Logger.Info($"Recording started -> {_currentFile}");
            _startTime = DateTime.UtcNow;
            IsRecording = true;
        }

        private void OnData(object? sender, WaveInEventArgs e)
        {
            if (_writer == null || e.BytesRecorded == 0) return;

            _writer.Write(e.Buffer, 0, e.BytesRecorded);
            _writer.Flush();

            var max = CalculatePeakLevel(e.Buffer.AsSpan(0, e.BytesRecorded), _capture?.WaveFormat);
            try
            {
                LevelChanged?.Invoke(this, max);
            }
            catch (Exception ex)
            {
                // Prevent UI callback failures from killing the capture loop
                Logger.Error($"Audio level callback error: {ex.Message}");
            }
        }

        internal static WaveFormat GetWaveFormatForCapturedData(WaveFormat captureFormat) => captureFormat;

        private static bool HasSameFormat(AudioQualitySettings requested, WaveFormat captured) =>
            requested.SampleRateHz == captured.SampleRate &&
            requested.ChannelCount == captured.Channels &&
            requested.BitsPerSample == captured.BitsPerSample;

        internal static float CalculatePeakLevel(ReadOnlySpan<byte> data, WaveFormat? format)
        {
            if (format is WaveFormatExtensible extensibleFormat)
            {
                format = extensibleFormat.ToStandardWaveFormat();
            }

            if (format == null || format.BlockAlign <= 0 || format.BitsPerSample <= 0)
            {
                return 0;
            }

            var bytesPerSample = format.BitsPerSample / 8;
            if (bytesPerSample <= 0)
            {
                return 0;
            }

            var sampleCount = data.Length / bytesPerSample;
            var peak = 0f;
            for (var sampleIndex = 0; sampleIndex < sampleCount; sampleIndex++)
            {
                var offset = sampleIndex * bytesPerSample;
                float value;
                if (format.Encoding == WaveFormatEncoding.IeeeFloat && format.BitsPerSample == 32)
                {
                    value = BitConverter.ToSingle(data.Slice(offset, sizeof(float)));
                }
                else if (format.Encoding == WaveFormatEncoding.Pcm)
                {
                    value = format.BitsPerSample switch
                    {
                        8 => (data[offset] - 128) / 128f,
                        16 => BitConverter.ToInt16(data.Slice(offset, sizeof(short))) / 32768f,
                        24 => ReadInt24(data.Slice(offset, 3)) / 8388608f,
                        32 => BitConverter.ToInt32(data.Slice(offset, sizeof(int))) / 2147483648f,
                        _ => 0f
                    };
                }
                else
                {
                    continue;
                }

                if (float.IsFinite(value))
                {
                    peak = Math.Max(peak, Math.Clamp(Math.Abs(value), 0f, 1f));
                }
            }

            return peak;
        }

        private static int ReadInt24(ReadOnlySpan<byte> bytes)
        {
            var value = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16);
            return (value & 0x800000) == 0 ? value : value | unchecked((int)0xFF000000);
        }

        public void Stop()
        {
            if (!IsRecording) return;
            Logger.Info($"Recording stop requested at {DateTime.UtcNow:HH:mm:ss.fff}");
            _capture?.StopRecording();
            Logger.Info("Recording stopped (awaiting finalization)");
        }

        private void OnStopped(object? sender, StoppedEventArgs e)
        {
            if (e.Exception != null)
            {
                Logger.Error($"Recording failed: {e.Exception.Message}");
            }

            _capture?.Dispose();
            _capture = null;

            _writer?.Dispose();
            _writer = null;

            IsRecording = false;

            if (e.Exception != null)
            {
                return;
            }

            if (!string.IsNullOrEmpty(_currentFile) && File.Exists(_currentFile))
            {
                var fileInfo = new System.IO.FileInfo(_currentFile);
                Logger.Info($"Recording completed -> {_currentFile} ({fileInfo.Length} bytes)");
                RecordingCompleted?.Invoke(this, new RecordingCompletedEventArgs { FilePath = _currentFile });
            }
            else
            {
                Logger.Error($"Recording file not found or empty: {_currentFile}");
            }
        }

        public void Dispose()
        {
            _capture?.Dispose();
            _writer?.Dispose();
        }
    }
}
