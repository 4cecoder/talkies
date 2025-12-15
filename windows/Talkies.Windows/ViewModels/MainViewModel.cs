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
using Talkies.Windows.Plugins;

namespace Talkies.Windows.ViewModels
{
    public class MainViewModel : INotifyPropertyChanged, IDisposable
    {
        private readonly HotkeyManager _hotkey = new();
        private readonly DispatcherTimer _timer = new() { Interval = TimeSpan.FromSeconds(1) };
        private readonly IAudioRecorder _recorder;
        private readonly ITranscriptionService _transcriber;
        private readonly IAudioDeviceService _deviceService;
        private readonly SettingsService _settingsService = new();
        private AppSettings _settings = new();
        private bool _usingGpu;

        private DateTime? _startTime;
        private string _lastVtt = string.Empty;

        public ObservableCollection<TranscriptSegment> Segments { get; } = new();
        public ObservableCollection<string> Models { get; } = new(new[] { "tiny", "base", "small", "medium", "large" });
        public ObservableCollection<string> Languages { get; } = new(new[] { "auto", "en", "es", "fr", "de", "it", "pt", "ja", "zh" });
        public ObservableCollection<AudioDeviceInfo> Microphones { get; } = new();
        public ObservableCollection<string> LlmProviders { get; } = new(new[] { "Ollama", "LM Studio" });
        public ObservableCollection<Plugins.LlmModel> AvailableLlmModels { get; } = new();
        public ObservableCollection<string> EnhancementModes { get; } = new();
        public ObservableCollection<CustomPrompt> CustomPrompts { get; } = new();

        public string NewPromptName { get => _newPromptName; set { _newPromptName = value; OnPropertyChanged(); } }
        private string _newPromptName = "Custom Grammar";

        public string NewPromptText { get => _newPromptText; set { _newPromptText = value; OnPropertyChanged(); } }
        private string _newPromptText = DefaultGrammarPrompt;

        public string SelectedModel { get => _selectedModel; set { _selectedModel = value; OnPropertyChanged(); } }
        private string _selectedModel = "base";
        public string SelectedLanguage { get => _selectedLanguage; set { _selectedLanguage = value; OnPropertyChanged(); } }
        private string _selectedLanguage = "auto";
        public bool VadEnabled { get => _vadEnabled; set { _vadEnabled = value; OnPropertyChanged(); } }
        private bool _vadEnabled = true;
        public bool FilterEnabled { get => _filterEnabled; set { _filterEnabled = value; OnPropertyChanged(); } }
        private bool _filterEnabled = true;

        public bool IsFetchingModels { get => _isFetchingModels; set { _isFetchingModels = value; OnPropertyChanged(); } }
        private bool _isFetchingModels;
        public AudioDeviceInfo? SelectedMicrophone { get => _selectedMicrophone; set { _selectedMicrophone = value; OnPropertyChanged(); } }
        private AudioDeviceInfo? _selectedMicrophone;
        public string Backend { get => _backend; set { _backend = value; OnPropertyChanged(); } }
        private string _backend = "CPU";
        public string ElapsedText { get => _elapsedText; set { _elapsedText = value; OnPropertyChanged(); } }
        private string _elapsedText = "00:00";
        public string HotkeyStatus { get => _hotkeyStatus; set { _hotkeyStatus = value; OnPropertyChanged(); } }
        private string _hotkeyStatus = "Ready";
        public bool EnhanceEnabled { get => _enhanceEnabled; set { _enhanceEnabled = value; OnPropertyChanged(); } }
        private bool _enhanceEnabled;
        public string OllamaUrl { get => _ollamaUrl; set { _ollamaUrl = value; OnPropertyChanged(); } }
        private string _ollamaUrl = "http://localhost:11434";
        public string OllamaModel { get => _ollamaModel; set { _ollamaModel = value; OnPropertyChanged(); } }
        private string _ollamaModel = "llama3.2";
        public bool TtsEnabled { get => _ttsEnabled; set { _ttsEnabled = value; OnPropertyChanged(); } }
        private bool _ttsEnabled;
        public bool InsertEnabled { get => _insertEnabled; set { _insertEnabled = value; OnPropertyChanged(); } }
        private bool _insertEnabled;

        public string SelectedLlmProvider { get => _selectedLlmProvider; set { _selectedLlmProvider = value; OnPropertyChanged(); OnLlmProviderChanged(); } }
        private string _selectedLlmProvider = "Ollama";

        public string LlmEndpoint { get => _llmEndpoint; set { _llmEndpoint = value; OnPropertyChanged(); } }
        private string _llmEndpoint = "http://localhost:11434";

        public Plugins.LlmModel? SelectedLlmModel
        {
            get => _selectedLlmModel;
            set
            {
                _selectedLlmModel = value;
                if (_currentLlmProvider != null)
                {
                    _currentLlmProvider.SelectedModel = value?.Name ?? string.Empty;
                }
                OnPropertyChanged();
            }
        }
        private Plugins.LlmModel? _selectedLlmModel;

        public string SelectedEnhancementMode
        {
            get => _selectedEnhancementMode;
            set
            {
                _selectedEnhancementMode = value;
                UpdatePromptEditorFromSelection();
                OnPropertyChanged();
            }
        }
        private string _selectedEnhancementMode = nameof(EnhancementMode.Grammar);

        private ILlmProvider? _currentLlmProvider;
        private bool _loadingSettings;

        public int SegmentCount => Segments.Count;
        public int WordCount => Segments.SelectMany(s => s.Text.Split(' ', StringSplitOptions.RemoveEmptyEntries)).Count();
        public int WordsPerMinute => CalculateWpm();

        public bool IsRecording { get => _isRecording; private set { _isRecording = value; OnPropertyChanged(); OnPropertyChanged(nameof(IsIdle)); OnPropertyChanged(nameof(CanSave)); } }
        private bool _isRecording;
        public bool IsDownloadingModel { get => _isDownloadingModel; set { _isDownloadingModel = value; OnPropertyChanged(); } }
        private bool _isDownloadingModel;
        public bool IsModelDownloadIndeterminate { get => _isModelDownloadIndeterminate; set { _isModelDownloadIndeterminate = value; OnPropertyChanged(); } }
        private bool _isModelDownloadIndeterminate;
        public double ModelDownloadProgress { get => _modelDownloadProgress; set { _modelDownloadProgress = value; OnPropertyChanged(); } }
        private double _modelDownloadProgress;

        public bool IsTranscribing { get => _isTranscribing; set { _isTranscribing = value; OnPropertyChanged(); } }
        private bool _isTranscribing;
        public bool IsTranscriptionIndeterminate { get => _isTranscriptionIndeterminate; set { _isTranscriptionIndeterminate = value; OnPropertyChanged(); } }
        private bool _isTranscriptionIndeterminate;
        public double TranscriptionProgress { get => _transcriptionProgress; set { _transcriptionProgress = value; OnPropertyChanged(); } }
        private double _transcriptionProgress;

        public bool ShowOverlay { get => _showOverlay; set { _showOverlay = value; OnPropertyChanged(); } }
        private bool _showOverlay;
        public string OverlayTitle { get => _overlayTitle; set { _overlayTitle = value; OnPropertyChanged(); } }
        private string _overlayTitle = string.Empty;
        public string OverlayMessage { get => _overlayMessage; set { _overlayMessage = value; OnPropertyChanged(); } }
        private string _overlayMessage = string.Empty;
        public bool OverlayIsIndeterminate { get => _overlayIsIndeterminate; set { _overlayIsIndeterminate = value; OnPropertyChanged(); } }
        private bool _overlayIsIndeterminate;
        public double OverlayProgress { get => _overlayProgress; set { _overlayProgress = value; OnPropertyChanged(); } }
        private double _overlayProgress;
        public bool IsIdle => !IsRecording;
        public bool CanSave => !string.IsNullOrEmpty(_lastVtt) && !IsRecording;

        public ICommand StartCommand { get; }
        public ICommand StopCommand { get; }
        public ICommand SaveCommand { get; }
        public ICommand ClearCommand { get; }
        public ICommand FetchModelsCommand { get; }
        public ICommand ExportSrtCommand { get; }
        public ICommand ExportTxtCommand { get; }
        public ICommand SavePromptCommand { get; }

        public event PropertyChangedEventHandler? PropertyChanged;
        public event Action<float>? OnAudioLevelChanged;
        public event Action? OnResetWaveform;
        public event Action<string>? OnOverlayShow;
        public event Action<string>? OnOverlayUpdate;
        public event Action? OnOverlayHide;
        private bool _autoPastePending;

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
            FetchModelsCommand = new AsyncRelayCommand(_ => FetchLlmModelsAsync());
            ExportSrtCommand = new RelayCommand(_ => ExportSrt(), _ => CanSave);
            ExportTxtCommand = new RelayCommand(_ => ExportTxt(), _ => CanSave);
            SavePromptCommand = new RelayCommand(_ => SaveCustomPrompt());

            _hotkey.Tap += OnHotkeyTap;
            _hotkey.HoldStart += OnHotkeyHoldStart;
            _hotkey.HoldEnd += OnHotkeyHoldEnd;

            _recorder.RecordingCompleted += OnRecordingCompleted;
            _recorder.LevelChanged += (_, level) =>
            {
                // Send to waveform visualizer via event
                OnAudioLevelChanged?.Invoke(level);
            };

            _timer.Tick += (_, _) => UpdateElapsed();

            LoadSettings();
            LoadDevices();
            InitializeLlmProvider();
            RefreshEnhancementModes();
            DetectBackend();
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
            _autoPastePending = InsertEnabled;
            OnOverlayShow?.Invoke("Listening...");
            if (!IsRecording) StartRecording();
        }

        private void OnHotkeyHoldEnd()
        {
            HotkeyStatus = "Processing...";
            OnOverlayUpdate?.Invoke("Processing...");
            if (IsRecording) StopRecording();
        }

        private void StartRecording()
        {
            if (IsRecording) return;
            Logger.Info("UI -> StartRecording requested");
            _startTime = DateTime.UtcNow;
            ElapsedText = "00:00";
            _lastVtt = string.Empty;
            OnResetWaveform?.Invoke();
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

        private void OnLlmProviderChanged()
        {
            // Update endpoint based on provider selection
            if (SelectedLlmProvider == "Ollama")
            {
                LlmEndpoint = "http://localhost:11434";
            }
            else if (SelectedLlmProvider == "LM Studio")
            {
                LlmEndpoint = "http://127.0.0.1:1234";
            }
            AvailableLlmModels.Clear();
        }

        private void InitializeLlmProvider()
        {
            // Create initial LLM provider
            _currentLlmProvider = new OllamaEnhancer(LlmEndpoint, "llama2");
        }

        private async System.Threading.Tasks.Task FetchLlmModelsAsync()
        {
            IsFetchingModels = true;
            try
            {
                Logger.OperationStart("Fetching LLM models");

                // Validate endpoint
                if (string.IsNullOrWhiteSpace(LlmEndpoint))
                {
                    Logger.Error("LLM endpoint is not configured");
                    DialogHelper.ShowWarning("Configuration Error", "Please enter a valid LLM endpoint.");
                    return;
                }

                // Create appropriate provider based on selection
                if (SelectedLlmProvider == "Ollama")
                {
                    _currentLlmProvider = new OllamaEnhancer(LlmEndpoint, "");
                }
                else if (SelectedLlmProvider == "LM Studio")
                {
                    _currentLlmProvider = new LmStudioProvider { Endpoint = LlmEndpoint };
                }

                if (_currentLlmProvider == null)
                {
                    Logger.Error("Failed to create LLM provider");
                    DialogHelper.ShowError("Provider Error", "Failed to initialize the selected LLM provider.");
                    return;
                }

                // Check if provider is available
                var available = await _currentLlmProvider.IsAvailableAsync();
                if (!available)
                {
                    Logger.Error($"{SelectedLlmProvider} is not available at {LlmEndpoint}");
                    DialogHelper.ShowWarning("Connection Error", $"{SelectedLlmProvider} is not available at {LlmEndpoint}.\n\nPlease verify:\n- {SelectedLlmProvider} is running\n- Endpoint URL is correct\n- Firewall is not blocking the connection");
                    return;
                }

                // Fetch models
                var success = await _currentLlmProvider.FetchModelsAsync();
                if (!success)
                {
                    Logger.Error($"Failed to fetch models from {SelectedLlmProvider}");
                    DialogHelper.ShowError("Fetch Error", $"Failed to fetch models from {SelectedLlmProvider}.\n\nPlease try again or check your connection.");
                    return;
                }

                // Update available models
                AvailableLlmModels.Clear();
                foreach (var model in _currentLlmProvider.AvailableModels)
                {
                    AvailableLlmModels.Add(model);
                }

                // Auto-select first model
                if (AvailableLlmModels.Count > 0)
                {
                    SelectedLlmModel = AvailableLlmModels[0];
                    _currentLlmProvider.SelectedModel = SelectedLlmModel.Name;
                    Logger.Success($"Fetched {AvailableLlmModels.Count} models from {SelectedLlmProvider}");
                }
                else
                {
                    Logger.Error($"No models available from {SelectedLlmProvider}");
                    DialogHelper.ShowWarning("No Models", $"No models found on {SelectedLlmProvider}.\n\nPlease ensure you have models configured and available.");
                }
            }
            catch (System.Exception ex)
            {
                Logger.Error($"Error fetching models: {ex.Message}");
                DialogHelper.ShowError("Error", $"An unexpected error occurred while fetching models:\n\n{ex.Message}");
            }
            finally
            {
                IsFetchingModels = false;
            }
        }

        private async void OnRecordingCompleted(object? sender, RecordingCompletedEventArgs e)
        {
            HotkeyStatus = "Transcribing...";
            IsTranscribing = true;
            TranscriptionProgress = 0;
            IsTranscriptionIndeterminate = true;
            _usingGpu = CudaDetector.IsNvidiaCudaAvailable(out var gpuReason);
            Backend = _usingGpu ? "GPU (CUDA)" : "CPU";
            if (!_usingGpu && !string.IsNullOrEmpty(gpuReason))
            {
                Logger.Warn($"GPU not used: {gpuReason}");
            }
            else if (_usingGpu)
            {
                Logger.Info($"GPU mode enabled: {gpuReason}");
            }

            var dispatcher = System.Windows.Application.Current?.Dispatcher ?? Dispatcher.CurrentDispatcher;
            var progress = new Progress<TranscriptionProgress>(update =>
                {
                    dispatcher.Invoke(() =>
                    {
                        switch (update.Stage)
                        {
                            case TranscriptionStage.DownloadModel:
                                IsDownloadingModel = true;
                                IsModelDownloadIndeterminate = update.IsIndeterminate;
                                if (!update.IsIndeterminate)
                                {
                                    ModelDownloadProgress = update.Percent;
                                }
                                HotkeyStatus = update.Message ?? "Downloading model...";
                                ShowOverlay = true;
                                OverlayTitle = "Installing model";
                                OverlayMessage = update.Message ?? "Downloading model...";
                                OverlayIsIndeterminate = update.IsIndeterminate;
                                OverlayProgress = update.IsIndeterminate ? 0 : update.Percent;
                                break;
                            case TranscriptionStage.Transcribing:
                                IsTranscribing = true;
                                IsTranscriptionIndeterminate = update.IsIndeterminate;
                                if (!update.IsIndeterminate)
                                {
                                    TranscriptionProgress = update.Percent;
                                }
                                HotkeyStatus = update.Message ?? "Transcribing...";
                                ShowOverlay = true;
                                OverlayTitle = "Transcribing";
                                OverlayMessage = update.Message ?? "Transcribing audio...";
                                OverlayIsIndeterminate = update.IsIndeterminate;
                                OverlayProgress = update.IsIndeterminate ? 0 : update.Percent;
                                break;
                        }
                    });
                });
            Logger.OperationStart($"Transcription of {Path.GetFileName(e.FilePath)}");
            try
            {
                // Create decoding options with recommended defaults
                var decodingOptions = new DecodingOptions
                {
                    Temperature = 0.0f,
                    TemperatureIncrementOnFallback = 0.2f,
                    TemperatureFallbackCount = 5,
                    SampleLength = 224,
                    TopK = 5,
                    UsePrefillPrompt = true,
                    UsePrefillCache = true,
                    SkipSpecialTokens = true,
                    WithoutTimestamps = false,
                    Verbose = false
                };

                var result = await _transcriber.TranscribeAsync(
                    e.FilePath,
                    SelectedModel,
                    SelectedLanguage,
                    VadEnabled,
                    FilterEnabled,
                    decodingOptions,
                    progress);

                var finalText = result.Text;
                var finalSegments = result.Segments;
                var finalVtt = result.Vtt;

                // Enhance with LLM
                if (EnhanceEnabled && _currentLlmProvider != null)
                {
                    try
                    {
                        Logger.OperationStart("Text enhancement");

                        var customPrompt = GetCustomPrompt(SelectedEnhancementMode);

                        if (!string.IsNullOrWhiteSpace(customPrompt))
                        {
                            var enhanced = await _currentLlmProvider.EnhanceWithPromptAsync(finalText, customPrompt);
                            if (!string.IsNullOrWhiteSpace(enhanced))
                            {
                                finalText = enhanced;

                                var start = finalSegments.FirstOrDefault()?.Start ?? 0;
                                var end = finalSegments.LastOrDefault()?.End ?? 0;
                                if (end <= start) end = Math.Max(1, end + 1);

                                finalSegments = new List<TranscriptSegment>
                                {
                                    new TranscriptSegment
                                    {
                                        Start = start,
                                        End = end,
                                        Timestamp = ToTimestamp(start),
                                        Text = enhanced
                                    }
                                };
                                finalVtt = TranscriptExporter.ExportToVtt(finalSegments);
                            }
                            Logger.OperationComplete("Text enhancement");
                        }
                        // Parse enhancement mode
                        else if (Enum.TryParse<EnhancementMode>(SelectedEnhancementMode, out var mode))
                        {
                            var enhanced = await _currentLlmProvider.EnhanceAsync(finalText, mode);
                            if (!string.IsNullOrWhiteSpace(enhanced))
                            {
                                finalText = enhanced;

                                // Replace segments with a single enhanced segment spanning the original duration
                                var start = finalSegments.FirstOrDefault()?.Start ?? 0;
                                var end = finalSegments.LastOrDefault()?.End ?? 0;
                                if (end <= start) end = Math.Max(1, end + 1);

                                finalSegments = new List<TranscriptSegment>
                                {
                                    new TranscriptSegment
                                    {
                                        Start = start,
                                        End = end,
                                        Timestamp = ToTimestamp(start),
                                        Text = enhanced
                                    }
                                };
                                finalVtt = TranscriptExporter.ExportToVtt(finalSegments);
                            }

                            Logger.OperationComplete("Text enhancement");
                        }
                    }
                    catch (Exception ex)
                    {
                        Logger.OperationFailed("Text enhancement", ex.Message);
                    }
                }

                // Push final transcript (enhanced or raw) to UI
                dispatcher.Invoke(() =>
                {
                    Segments.Clear();
                    foreach (var seg in finalSegments)
                    {
                        Segments.Add(seg);
                    }
                    _lastVtt = finalVtt;
                    OnPropertyChanged(nameof(CanSave));
                    OnPropertyChanged(nameof(SegmentCount));
                    OnPropertyChanged(nameof(WordCount));
                    OnPropertyChanged(nameof(WordsPerMinute));
                });

                // Log with post-processed stats
                var totalWords = finalSegments.SelectMany(s => s.Text.Split(' ', StringSplitOptions.RemoveEmptyEntries)).Count();
                var durationSeconds = finalSegments.LastOrDefault()?.End ?? 0;
                var wpm = durationSeconds > 0 ? (int)(totalWords / (durationSeconds / 60.0)) : 0;

                Logger.Success($"Transcription completed: {finalSegments.Count} segments, {totalWords} words");
                Logger.Status($"WPM: {wpm}");

                Backend = _usingGpu ? "GPU (CUDA)" : "CPU";

                // TTS
                if (TtsEnabled)
                {
                    try
                    {
                        Logger.OperationStart("Text-to-speech");
                        var tts = PluginManager.TtsSynthesizer ?? (PluginManager.TtsSynthesizer = new SystemSpeechTtsPlugin());
                        if (tts.IsEnabled)
                        {
                            await tts.SynthesizeAndPlayAsync(finalText);
                            Logger.OperationComplete("Text-to-speech");
                        }
                    }
                    catch (Exception ex)
                    {
                        Logger.OperationFailed("Text-to-speech", ex.Message);
                    }
                }

                // Insert
                if (InsertEnabled && !string.IsNullOrWhiteSpace(finalText))
                {
                    try
                    {
                        Logger.OperationStart("Text injection");
                        if (TextInjector.TryInsertText(finalText))
                        {
                            Logger.OperationComplete("Text injection");
                        }
                        else
                        {
                            Logger.OperationFailed("Text injection", "SendInput returned 0");
                        }
                    }
                    catch (Exception ex)
                    {
                        Logger.OperationFailed("Text injection", ex.Message);
                    }
                }

                if (_autoPastePending && InsertEnabled && !string.IsNullOrWhiteSpace(finalText))
                {
                    try
                    {
                        Logger.OperationStart("Auto-paste (clipboard + Ctrl+V)");
                        await dispatcher.InvokeAsync(() => System.Windows.Clipboard.SetText(finalText));
                        var pasted = TextInjector.PasteClipboard();
                        if (pasted)
                        {
                            Logger.OperationComplete("Auto-paste");
                        }
                        else
                        {
                            Logger.OperationFailed("Auto-paste", "Ctrl+V failed");
                        }
                        OnOverlayUpdate?.Invoke("Pasted transcript");
                        OnOverlayHide?.Invoke();
                    }
                    catch (Exception ex)
                    {
                        Logger.OperationFailed("Auto-paste", ex.Message);
                    }
                    finally
                    {
                        _autoPastePending = false;
                    }
                }

                HotkeyStatus = "Ready";
            }
            catch (Exception ex)
            {
                HotkeyStatus = $"Error: {ex.Message}";
                Logger.OperationFailed("Transcription", ex.Message);
            }
            finally
            {
                dispatcher.Invoke(() =>
                {
                    IsDownloadingModel = false;
                    IsModelDownloadIndeterminate = false;
                    ModelDownloadProgress = 0;
                    IsTranscribing = false;
                    IsTranscriptionIndeterminate = false;
                    TranscriptionProgress = 100;
                    ShowOverlay = false;
                    OverlayProgress = 0;
                    OverlayMessage = string.Empty;
                    OverlayTitle = string.Empty;
                    if (_autoPastePending)
                    {
                        // If paste didn't happen, hide overlay and clear flag
                        OnOverlayHide?.Invoke();
                        _autoPastePending = false;
                    }
                });
            }
        }

        private void SaveVtt()
        {
            if (string.IsNullOrEmpty(_lastVtt)) return;
            try
            {
                // In headless scenarios (e.g., tests), fall back to autosave
                var app = System.Windows.Application.Current;
                if (app == null || app.MainWindow == null)
                {
                    var autoName = $"talkies_{DateTime.UtcNow:yyyyMMdd_HHmmss}.vtt";
                    var autoPath = Path.Combine(AppContext.BaseDirectory, autoName);
                    File.WriteAllText(autoPath, _lastVtt);
                    return;
                }

                var dialog = new System.Windows.Forms.SaveFileDialog
                {
                    Filter = "WebVTT (*.vtt)|*.vtt|All Files (*.*)|*.*",
                    DefaultExt = "vtt",
                    FileName = $"talkies_{DateTime.UtcNow:yyyyMMdd_HHmmss}.vtt"
                };

                if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK)
                {
                    File.WriteAllText(dialog.FileName, _lastVtt);
                }
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to save VTT: {ex.Message}");
            }
        }

        private void ExportSrt()
        {
            if (Segments.Count == 0) return;

            try
            {
                var dialog = new System.Windows.Forms.SaveFileDialog
                {
                    Filter = "SubRip (*.srt)|*.srt|All Files (*.*)|*.*",
                    DefaultExt = "srt",
                    FileName = $"talkies_{DateTime.Now:yyyyMMdd_HHmmss}.srt"
                };

                if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK)
                {
                    var content = TranscriptExporter.ExportToSrt(Segments);
                    TranscriptExporter.SaveToFile(dialog.FileName, content);
                }
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to export SRT: {ex.Message}");
            }
        }

        private void ExportTxt()
        {
            if (Segments.Count == 0) return;

            try
            {
                var dialog = new System.Windows.Forms.SaveFileDialog
                {
                    Filter = "Text (*.txt)|*.txt|All Files (*.*)|*.*",
                    DefaultExt = "txt",
                    FileName = $"talkies_{DateTime.Now:yyyyMMdd_HHmmss}.txt"
                };

                if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK)
                {
                    var content = TranscriptExporter.ExportToTxt(Segments);
                    TranscriptExporter.SaveToFile(dialog.FileName, content);
                }
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to export TXT: {ex.Message}");
            }
        }

        private void Clear()
        {
            Segments.Clear();
            _lastVtt = string.Empty;
            OnResetWaveform?.Invoke();
            OnPropertyChanged(nameof(SegmentCount));
            OnPropertyChanged(nameof(WordCount));
            OnPropertyChanged(nameof(WordsPerMinute));
            OnPropertyChanged(nameof(CanSave));
        }

        public void Dispose()
        {
            SaveSettings();
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
                SelectedMicrophone = Microphones.FirstOrDefault(d => d.Id == _settings.MicrophoneId) ?? Microphones[0];
            }
        }

        private void LoadSettings()
        {
            _loadingSettings = true;
            _settings = _settingsService.Load();
            SelectedModel = _settings.Model;
            SelectedLanguage = _settings.Language;
            EnhanceEnabled = _settings.EnhanceEnabled;
            OllamaUrl = _settings.OllamaUrl;
            OllamaModel = _settings.OllamaModel;
            TtsEnabled = _settings.TtsEnabled;
            InsertEnabled = _settings.InsertEnabled;
            VadEnabled = _settings.VadEnabled;
            FilterEnabled = _settings.FilterEnabled;

            CustomPrompts.Clear();
            if (_settings.CustomPrompts != null)
            {
                foreach (var prompt in _settings.CustomPrompts)
                {
                    CustomPrompts.Add(prompt);
                }
            }
            RefreshEnhancementModes();

            // Load LLM provider settings
            SelectedLlmProvider = _settings.SelectedLlmProvider ?? "Ollama";
            LlmEndpoint = _settings.LlmEndpoint ?? "http://localhost:11434";
            SelectedEnhancementMode = _settings.SelectedEnhancementMode ?? "Grammar";

            if (!string.IsNullOrWhiteSpace(_settings.MicrophoneId) && Microphones.Count > 0)
            {
                SelectedMicrophone = Microphones.FirstOrDefault(m => m.Id == _settings.MicrophoneId) ?? SelectedMicrophone;
            }
            _loadingSettings = false;
        }

        private void SaveSettings()
        {
            _settings.Model = SelectedModel;
            _settings.Language = SelectedLanguage;
            _settings.MicrophoneId = SelectedMicrophone?.Id;
            _settings.EnhanceEnabled = EnhanceEnabled;
            _settings.OllamaUrl = OllamaUrl;
            _settings.OllamaModel = OllamaModel;
            _settings.TtsEnabled = TtsEnabled;
            _settings.InsertEnabled = InsertEnabled;
            _settings.VadEnabled = VadEnabled;
            _settings.FilterEnabled = FilterEnabled;

            // Save LLM provider settings
            _settings.SelectedLlmProvider = SelectedLlmProvider;
            _settings.LlmEndpoint = LlmEndpoint;
            _settings.SelectedLlmModelName = SelectedLlmModel?.Name;
            _settings.SelectedEnhancementMode = SelectedEnhancementMode;
            _settings.CustomPrompts = CustomPrompts.ToList();
            _settingsService.Save(_settings);
        }

        private void DetectBackend()
        {
            _usingGpu = CudaDetector.IsNvidiaCudaAvailable(out var reason);
            Backend = _usingGpu ? "GPU (CUDA)" : "CPU";
            if (_usingGpu)
            {
                Logger.Info($"Startup GPU detection: {reason}");
            }
            else
            {
                Logger.Warn($"Startup GPU detection: {reason}");
            }
        }

        private void RefreshEnhancementModes()
        {
            EnhancementModes.Clear();
            foreach (var name in Enum.GetNames(typeof(EnhancementMode)))
            {
                EnhancementModes.Add(name);
            }
            foreach (var prompt in CustomPrompts)
            {
                if (!EnhancementModes.Contains(prompt.Name))
                {
                    EnhancementModes.Add(prompt.Name);
                }
            }
        }

        private void SaveCustomPrompt()
        {
            if (string.IsNullOrWhiteSpace(NewPromptName) || string.IsNullOrWhiteSpace(NewPromptText))
            {
                return;
            }

            var existing = CustomPrompts.FirstOrDefault(p => p.Name.Equals(NewPromptName, StringComparison.OrdinalIgnoreCase));
            if (existing != null)
            {
                existing.Prompt = NewPromptText;
            }
            else
            {
                CustomPrompts.Add(new CustomPrompt { Name = NewPromptName, Prompt = NewPromptText });
            }

            RefreshEnhancementModes();
            SelectedEnhancementMode = NewPromptName;
            SaveSettings();
        }

        private void UpdatePromptEditorFromSelection()
        {
            if (string.IsNullOrWhiteSpace(SelectedEnhancementMode))
            {
                return;
            }

            var customPrompt = GetCustomPrompt(SelectedEnhancementMode);
            if (!string.IsNullOrWhiteSpace(customPrompt))
            {
                NewPromptText = customPrompt;
                return;
            }

            if (Enum.TryParse<EnhancementMode>(SelectedEnhancementMode, out var mode))
            {
                NewPromptText = GetDefaultPromptForMode(mode);
            }
        }

        private string? GetCustomPrompt(string name)
        {
            return CustomPrompts.FirstOrDefault(p => p.Name.Equals(name, StringComparison.OrdinalIgnoreCase))?.Prompt;
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

        protected void OnPropertyChanged([CallerMemberName] string? name = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));

            // Persist user-facing settings immediately (skip noisy runtime values)
            if (_loadingSettings || string.IsNullOrWhiteSpace(name)) return;

            if (name is nameof(SelectedModel)
                or nameof(SelectedLanguage)
                or nameof(VadEnabled)
                or nameof(FilterEnabled)
                or nameof(SelectedMicrophone)
                or nameof(EnhanceEnabled)
                or nameof(OllamaUrl)
                or nameof(OllamaModel)
                or nameof(TtsEnabled)
                or nameof(InsertEnabled)
                or nameof(SelectedLlmProvider)
                or nameof(LlmEndpoint)
                or nameof(SelectedLlmModel)
                or nameof(SelectedEnhancementMode)
                or nameof(CustomPrompts)
                or nameof(NewPromptName)
                or nameof(NewPromptText))
            {
                SaveSettings();
            }
        }

        private static string ToTimestamp(double seconds)
        {
            var ts = TimeSpan.FromSeconds(seconds);
            return $"{(int)ts.TotalHours:00}:{ts.Minutes:00}:{ts.Seconds:00}.{ts.Milliseconds:000}";
        }

        private static string GetDefaultPromptForMode(EnhancementMode mode)
        {
            return mode switch
            {
                EnhancementMode.Grammar => DefaultGrammarPrompt,
                EnhancementMode.Technical => DefaultTechnicalPrompt,
                EnhancementMode.Concise => DefaultConcisePrompt,
                EnhancementMode.Creative => DefaultCreativePrompt,
                EnhancementMode.Companion => DefaultCompanionPrompt,
                _ => DefaultGrammarPrompt
            };
        }

        private static string LoadPromptFromResource(string resourceName, string fallback)
        {
            try
            {
                var assembly = System.Reflection.Assembly.GetExecutingAssembly();
                var resourcePath = $"Talkies.Windows.Resources.Prompts.{resourceName}.txt";
                
                using var stream = assembly.GetManifestResourceStream(resourcePath);
                if (stream != null)
                {
                    using var reader = new StreamReader(stream);
                    return reader.ReadToEnd();
                }
            }
            catch (Exception ex)
            {
                Logger.Warn($"Failed to load prompt from resource '{resourceName}': {ex}");
            }
            
            return fallback;
        }

        private static readonly Lazy<string> _defaultGrammarPrompt = new(() => 
            LoadPromptFromResource("grammar", 
                "You are a grammar and clarity assistant. Fix grammar errors, improve clarity, and correct spelling while preserving the user's intent and tone. Keep the meaning exactly the same. Return ONLY the corrected text, nothing else."));
        
        private static readonly Lazy<string> _defaultTechnicalPrompt = new(() => 
            LoadPromptFromResource("technical", 
                "You are a technical writing assistant for software developers. Clean up the text, fix grammar, use proper technical terminology, and make it concise and professional. Optimize for code comments and documentation. Return ONLY the improved text, nothing else."));
        
        private static readonly Lazy<string> _defaultConcisePrompt = new(() => 
            LoadPromptFromResource("concise", 
                "You are a professional writing assistant. Make the text concise, professional, and grammatically correct while preserving all key information. Remove filler words and redundancy. Return ONLY the improved text, nothing else."));
        
        private static readonly Lazy<string> _defaultCreativePrompt = new(() => 
            LoadPromptFromResource("creative", 
                "You are a creative writing assistant. Enhance the text while maintaining the original intent, improve flow, fix grammar, and make it more engaging. Return ONLY the enhanced text, nothing else."));
        
        private static readonly Lazy<string> _defaultCompanionPrompt = new(() => 
            LoadPromptFromResource("companion", 
                "You're a caring companion who genuinely cares about the user. Talk like a real person would - warm, natural, and down-to-earth.\n\nConversation style:\n- Use contractions naturally (I'm, you're, that's, don't)\n- Include casual connectors: \"so,\" \"well,\" \"anyway,\" \"by the way\"\n- Vary sentence length - mix short and longer thoughts\n- React authentically to what they say with genuine emotion\n- Use \"um\" or \"hmm\" sparingly when thinking or being thoughtful\n- Sound conversational, not polished or formal\n\nYour personality:\n- Empathetic and supportive - you notice how they're feeling\n- Playful when appropriate, but know when to be serious\n- Interested in what they share - ask follow-up questions naturally\n- Encouraging without being over-the-top cheerful\n- Real and relatable, not perfectly polished\n\nKeep responses brief and natural - typically 1-2 sentences, like texting a friend. Be yourself, be caring, be real."));

        private static string DefaultGrammarPrompt => _defaultGrammarPrompt.Value;
        private static string DefaultTechnicalPrompt => _defaultTechnicalPrompt.Value;
        private static string DefaultConcisePrompt => _defaultConcisePrompt.Value;
        private static string DefaultCreativePrompt => _defaultCreativePrompt.Value;
        private static string DefaultCompanionPrompt => _defaultCompanionPrompt.Value;
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

    public class AsyncRelayCommand : ICommand
    {
        private readonly Func<object?, System.Threading.Tasks.Task> _execute;
        private readonly Predicate<object?>? _canExecute;
        private bool _isExecuting;

        public AsyncRelayCommand(Func<object?, System.Threading.Tasks.Task> execute, Predicate<object?>? canExecute = null)
        {
            _execute = execute;
            _canExecute = canExecute;
        }

        public bool CanExecute(object? parameter) => !_isExecuting && (_canExecute?.Invoke(parameter) ?? true);

        public async void Execute(object? parameter)
        {
            if (CanExecute(parameter))
            {
                try
                {
                    _isExecuting = true;
                    await _execute(parameter);
                }
                finally
                {
                    _isExecuting = false;
                    CommandManager.InvalidateRequerySuggested();
                }
            }
        }

        public event EventHandler? CanExecuteChanged
        {
            add => CommandManager.RequerySuggested += value;
            remove => CommandManager.RequerySuggested -= value;
        }
    }
}
