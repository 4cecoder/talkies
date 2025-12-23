using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using Talkies.Windows.Models;
using Talkies.Windows.Services;
using Talkies.Windows.ViewModels;
using Xunit;

namespace Talkies.Windows.Tests
{
    public class MainViewModelTests
    {
        [Fact]
        public void StartStop_TogglesRecordingFlags()
        {
            var recorder = new FakeRecorder();
            var vm = new MainViewModel(recorder, new FakeTranscriber(), new FakeDevices());

            Assert.False(vm.IsRecording);

            vm.StartCommand.Execute(null);
            Assert.True(vm.IsRecording);

            vm.StopCommand.Execute(null);
            Assert.False(vm.IsRecording);
        }

        [Fact]
        public async Task RecordingComplete_PopulatesSegments()
        {
            var recorder = new FakeRecorder();
            var transcriber = new FakeTranscriber();
            var vm = new MainViewModel(recorder, transcriber, new FakeDevices());

            vm.EnhanceEnabled = false;
            vm.InsertEnabled = false;

            vm.StartCommand.Execute(null);
            recorder.RaiseCompleted("dummy.wav");

            var waitMs = 0;
            while (vm.SegmentCount == 0 && waitMs < 1000)
            {
                await Task.Delay(50);
                waitMs += 50;
            }

            Assert.Equal(1, vm.SegmentCount);
            Assert.Equal(4, vm.WordCount);
        }

        [Fact]
        public void SaveVtt_WritesFile()
        {
            var vm = new MainViewModel(new FakeRecorder(), new FakeTranscriber(), new FakeDevices());
            vm.SetVttForTest("WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nhello\n");

            vm.SaveCommand.Execute(null);

            var dir = AppContext.BaseDirectory;
            var files = Directory.GetFiles(dir, "talkies_*.vtt");
            Assert.NotEmpty(files);
            foreach (var f in files)
            {
                File.Delete(f);
            }
        }

        [Fact]
        public void SelectingEnhancementMode_UpdatesPromptEditor()
        {
            var vm = new MainViewModel(new FakeRecorder(), new FakeTranscriber(), new FakeDevices());

            vm.SelectedEnhancementMode = "Technical";

            Assert.Contains("technical writing assistant", vm.NewPromptText, StringComparison.OrdinalIgnoreCase);
        }
    }

    internal class FakeRecorder : IAudioRecorder
    {
        public event EventHandler<RecordingCompletedEventArgs>? RecordingCompleted;
        public event EventHandler<float>? LevelChanged;
        public bool IsRecording { get; private set; }
        public TimeSpan Duration => TimeSpan.Zero;
        public void Dispose() { }
        public void Start(string? deviceId = null) { IsRecording = true; }
        public void Stop() { IsRecording = false; }
        public void RaiseCompleted(string path) => RecordingCompleted?.Invoke(this, new RecordingCompletedEventArgs { FilePath = path });
    }

    internal class FakeTranscriber : ITranscriptionService
    {
        public Task<TranscriptionResult> TranscribeAsync(string filePath, string model, string language, bool vadEnabled, bool filterEnabled, bool preferGpu, GpuBackend gpuBackend, DecodingOptions? decodingOptions = null, IProgress<TranscriptionProgress>? progress = null)
        {
            progress?.Report(new TranscriptionProgress(TranscriptionStage.DownloadModel, 100, "Download complete", false));
            progress?.Report(new TranscriptionProgress(TranscriptionStage.Transcribing, 50, "Halfway", false));

            var segs = new List<TranscriptSegment>
            {
                new TranscriptSegment { Timestamp = "00:00:01.000", Text = "hello world from tests", Start = 0, End = 1 }
            };
            return Task.FromResult(new TranscriptionResult
            {
                Segments = segs,
                Text = "hello world from tests",
                Vtt = "WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nhello world from tests\n"
            });
        }

        public string ExportVtt(IEnumerable<TranscriptSegment> segments) => string.Empty;

        public string ExportSrt(IEnumerable<TranscriptSegment> segments) => string.Empty;

        public string ExportTxt(IEnumerable<TranscriptSegment> segments) => string.Empty;

        public void Dispose()
        {
        }
    }

    internal class FakeDevices : IAudioDeviceService
    {
        public List<AudioDeviceInfo> GetCaptureDevices() => new() { new AudioDeviceInfo { Id = "fake", Name = "Fake Mic" } };
        public AudioDeviceInfo? GetDefaultCaptureDevice() => new AudioDeviceInfo { Id = "fake", Name = "Fake Mic" };
    }
}
