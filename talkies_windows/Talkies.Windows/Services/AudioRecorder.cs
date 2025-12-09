using System;
using System.IO;
using NAudio.CoreAudioApi;
using NAudio.Wave;

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
        void Start(string? deviceId = null);
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

        public void Start(string? deviceId = null)
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

            _writer = new WaveFileWriter(_currentFile, _capture.WaveFormat);
            Logger.Info($"Audio source: {(useLoopback ? "Loopback" : "Microphone")} | Format: {_capture.WaveFormat.SampleRate}Hz, {_capture.WaveFormat.Channels}ch, {_capture.WaveFormat.BitsPerSample}bit");

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

            // Level calc (RMS)
            float max = 0;
            for (int index = 0; index < e.BytesRecorded - 1; index += 2)
            {
                short sample = (short)((e.Buffer[index + 1] << 8) | e.Buffer[index]);
                var sample32 = sample / 32768f;
                if (Math.Abs(sample32) > max) max = Math.Abs(sample32);
            }
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
