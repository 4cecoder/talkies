using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
using Talkies.Windows.Models;
using Talkies.Windows.Services;

namespace Talkies.Windows.ViewModels
{
    public class MainViewModel : INotifyPropertyChanged, IDisposable
    {
        private readonly HotkeyManager _hotkey = new();
        private readonly DispatcherTimer _timer = new() { Interval = TimeSpan.FromSeconds(1) };
        private readonly IAudioRecorder _recorder;
        private readonly ITranscriptionService _transcriber;
        private readonly IAudioDeviceService _deviceService;

        private DateTime? _startTime;
        private string _lastVtt = string.Empty;

        public ObservableCollection<TranscriptSegment> Segments { get; } = new();
        public ObservableCollection<string> Models { get; } = new(new[] { "tiny", "base", "small", "medium", "large" });
        public ObservableCollection<string> Languages { get; } = new(new[] { "auto", "en", "es", "fr", "de", "it", "pt", "ja", "zh" });
        public ObservableCollection<AudioDeviceInfo> Microphones { get; } = new();

        public string SelectedModel { get => _selectedModel; set { _selectedModel = value; OnPropertyChanged(); } }
        private string _selectedModel = "base";
        public string SelectedLanguage { get => _selectedLanguage; set { _selectedLanguage = value; OnPropertyChanged(); } }
        private string _selectedLanguage = "auto";
        public bool VadEnabled { get => _vadEnabled; set { _vadEnabled = value; OnPropertyChanged(); } }
        private bool _vadEnabled = true;
        public bool FilterEnabled { get => _filterEnabled; set { _filterEnabled = value; OnPropertyChanged(); } }
        private bool _filterEnabled = true;
        public AudioDeviceInfo? SelectedMicrophone { get => _selectedMicrophone; set { _selectedMicrophone = value; OnPropertyChanged(); } }
        private AudioDeviceInfo? _selectedMicrophone;
        public string Backend { get => _backend; set { _backend = value; OnPropertyChanged(); } }
        private string _backend = "CPU";
        public string ElapsedText { get => _elapsedText; set { _elapsedText = value; OnPropertyChanged(); } }
        private string _elapsedText = "00:00";
        public string HotkeyStatus { get => _hotkeyStatus; set { _hotkeyStatus = value; OnPropertyChanged(); } }
        private string _hotkeyStatus = "Ready";

        public int SegmentCount => Segments.Count;
        public int WordCount => Segments.SelectMany(s => s.Text.Split(' ', StringSplitOptions.RemoveEmptyEntries)).Count();
        public int WordsPerMinute => CalculateWpm();

        public bool IsRecording { get => _isRecording; private set { _isRecording = value; OnPropertyChanged(); OnPropertyChanged(nameof(IsIdle)); OnPropertyChanged(nameof(CanSave)); } }
        private bool _isRecording;
        public bool IsIdle => !IsRecording;
        public bool CanSave => !string.IsNullOrEmpty(_lastVtt) && !IsRecording;

        public ICommand StartCommand { get; }
        public ICommand StopCommand { get; }
        public ICommand SaveCommand { get; }
        public ICommand ClearCommand { get; }

        public event PropertyChangedEventHandler? PropertyChanged;

        public MainViewModel()
            : this(new AudioRecorder(), new WhisperNetTranscriptionService(), new AudioDeviceService())
        {
        }

        public MainViewModel(IAudioRecorder recorder, ITranscriptionService transcriber, IAudioDeviceService deviceService)
        {
            _recorder = recorder;
            _transcriber = transcriber;
            _deviceService = deviceService;

            StartCommand = new RelayCommand(_ => StartRecording(), _ => IsIdle);
            StopCommand = new RelayCommand(_ => StopRecording(), _ => IsRecording);
            SaveCommand = new RelayCommand(_ => SaveVtt(), _ => CanSave);
            ClearCommand = new RelayCommand(_ => Clear());

            _hotkey.Tap += OnHotkeyTap;
            _hotkey.HoldStart += OnHotkeyHoldStart;
            _hotkey.HoldEnd += OnHotkeyHoldEnd;

            _recorder.RecordingCompleted += OnRecordingCompleted;
            _recorder.LevelChanged += (_, level) => { /* bind waveform later */ };

            _timer.Tick += (_, _) => UpdateElapsed();

            LoadDevices();
        }

        public void StartHotkey() => _hotkey.Start();

        private void OnHotkeyTap()
        {
            HotkeyStatus = "Tap";
            if (IsRecording) StopRecording(); else StartRecording();
        }

        private void OnHotkeyHoldStart()
        {
            HotkeyStatus = "Hold (push-to-talk)";
            if (!IsRecording) StartRecording();
        }

        private void OnHotkeyHoldEnd()
        {
            HotkeyStatus = "Hold released";
            if (IsRecording) StopRecording();
        }

        private void StartRecording()
        {
            if (IsRecording) return;
            Logger.Info("UI -> StartRecording requested");
            _startTime = DateTime.UtcNow;
            ElapsedText = "00:00";
            _lastVtt = string.Empty;
            OnPropertyChanged(nameof(CanSave));
            _timer.Start();
            IsRecording = true;
            _recorder.Start(SelectedMicrophone?.Id);
        }

        private void StopRecording()
        {
            if (!IsRecording) return;
            Logger.Info("UI -> StopRecording requested");
            _timer.Stop();
            _recorder.Stop();
            IsRecording = false;
        }

        private void UpdateElapsed()
        {
            if (_startTime == null) return;
            var span = DateTime.UtcNow - _startTime.Value;
            ElapsedText = $"{(int)span.TotalMinutes:00}:{span.Seconds:00}";
            OnPropertyChanged(nameof(WordsPerMinute));
        }

        private int CalculateWpm()
        {
            if (_startTime == null) return 0;
            var elapsedMinutes = Math.Max((DateTime.UtcNow - _startTime.Value).TotalMinutes, 0.01);
            return (int)(WordCount / elapsedMinutes);
        }

        private async void OnRecordingCompleted(object? sender, RecordingCompletedEventArgs e)
        {
            HotkeyStatus = "Transcribing...";
            Logger.Info($"Recorder complete -> {e.FilePath}, starting transcription");
            try
            {
                var result = await _transcriber.TranscribeAsync(
                    e.FilePath,
                    SelectedModel,
                    SelectedLanguage,
                    VadEnabled,
                    FilterEnabled);

                var dispatcher = Application.Current?.Dispatcher ?? Dispatcher.CurrentDispatcher;
                dispatcher.Invoke(() =>
                {
                    Segments.Clear();
                    foreach (var seg in result.Segments)
                    {
                        Segments.Add(seg);
                    }
                    _lastVtt = result.Vtt;
                    OnPropertyChanged(nameof(CanSave));
                    OnPropertyChanged(nameof(SegmentCount));
                    OnPropertyChanged(nameof(WordCount));
                    OnPropertyChanged(nameof(WordsPerMinute));
                });

                Backend = "CPU";
                HotkeyStatus = "Ready";
                Logger.Info($"Transcription applied: {result.Segments.Count} segments");
            }
            catch (Exception ex)
            {
                HotkeyStatus = $"Error: {ex.Message}";
                Logger.Error($"Transcription error: {ex}");
            }
        }

        private void SaveVtt()
        {
            if (string.IsNullOrEmpty(_lastVtt)) return;
            var name = $"talkies_{DateTime.Now:yyyyMMdd_HHmmss}.vtt";
            var path = Path.Combine(AppContext.BaseDirectory, name);
            File.WriteAllText(path, _lastVtt);
        }

        private void Clear()
        {
            Segments.Clear();
            _lastVtt = string.Empty;
            OnPropertyChanged(nameof(SegmentCount));
            OnPropertyChanged(nameof(WordCount));
            OnPropertyChanged(nameof(WordsPerMinute));
            OnPropertyChanged(nameof(CanSave));
        }

        public void Dispose()
        {
            _hotkey.Dispose();
            _recorder.Dispose();
        }

        private void LoadDevices()
        {
            Microphones.Clear();
            var devices = _deviceService.GetCaptureDevices();
            foreach (var d in devices)
            {
                Microphones.Add(d);
            }

            if (Microphones.Count > 0)
            {
                SelectedMicrophone = Microphones[0];
            }
        }

        // Test helpers
        internal void InjectSegmentsForTest(IEnumerable<TranscriptSegment> segs)
        {
            Segments.Clear();
            foreach (var s in segs)
            {
                Segments.Add(s);
            }
            OnPropertyChanged(nameof(SegmentCount));
            OnPropertyChanged(nameof(WordCount));
            OnPropertyChanged(nameof(WordsPerMinute));
        }
        internal void SetVttForTest(string vtt)
        {
            _lastVtt = vtt;
            OnPropertyChanged(nameof(CanSave));
        }

        protected void OnPropertyChanged([CallerMemberName] string? name = null) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }

    public class RelayCommand : ICommand
    {
        private readonly Action<object?> _execute;
        private readonly Predicate<object?>? _canExecute;

        public RelayCommand(Action<object?> execute, Predicate<object?>? canExecute = null)
        {
            _execute = execute;
            _canExecute = canExecute;
        }

        public bool CanExecute(object? parameter) => _canExecute?.Invoke(parameter) ?? true;
        public void Execute(object? parameter) => _execute(parameter);
        public event EventHandler? CanExecuteChanged
        {
            add => CommandManager.RequerySuggested += value;
            remove => CommandManager.RequerySuggested -= value;
        }
    }
}
