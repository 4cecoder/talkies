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
        public ObservableCollection<string> ErrorMessages { get; } = new();

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
        private string _selectedLlmProvider = "LM Studio";

        public string LlmEndpoint { get => _llmEndpoint; set { _llmEndpoint = value; OnPropertyChanged(); } }
        private string _llmEndpoint = "http://127.0.0.1:1234";

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

        public string SelectedEnhancementMode { get => _selectedEnhancementMode; set { _selectedEnhancementMode = value; OnPropertyChanged(); } }
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
        public bool HasErrors => ErrorMessages.Count > 0;

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
        public ICommand ShowPluginsCommand { get; }

        public event PropertyChangedEventHandler? PropertyChanged;
        public event Action<float>? OnAudioLevelChanged;
        public event Action<string>? OnOverlayShow;
        public event Action<string>? OnOverlayUpdate;
        public event Action? OnOverlayHide;
        private bool _autoPastePending;
        private const string DefaultLlmModel = "openai/gpt-oss-20b";

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
            ShowPluginsCommand = new RelayCommand(_ => ShowPluginsWindow());

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
            ErrorMessages.CollectionChanged += (_, _) => OnPropertyChanged(nameof(HasErrors));

            LoadSettings();
            LoadDevices();
            InitializeLlmProvider();
            RefreshEnhancementModes();
            DetectBackend();
            InitializePlugins();
            AutoFetchLlmModelsAsync();
        }

        private void InitializePlugins()
        {
            // Initialize TTS plugin if not already set
            PluginManager.TtsSynthesizer ??= new AdvancedTtsPlugin() { IsEnabled = true };

            // Initialize text enhancer plugins
            if (PluginManager.TextEnhancer == null)
            {
                PluginManager.TextEnhancer = new SentimentAnalyzerPlugin() { IsEnabled = true };
            }
        }

        private async void AutoFetchLlmModelsAsync()
        {
            try
            {
                if (AvailableLlmModels.Count == 0)
                {
                    await FetchLlmModelsAsync();
                }
            }
            catch (Exception ex)
            {
                Logger.Warn($"Auto-fetch LLM models failed: {ex.Message}");
            }
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
            _autoPastePending = true;
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
            _currentLlmProvider = new LmStudioProvider { Endpoint = LlmEndpoint, SelectedModel = "openai/gpt-oss-20b" };
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
                    _currentLlmProvider = new LmStudioProvider { Endpoint = LlmEndpoint, SelectedModel = _settings.SelectedLlmModelName ?? DefaultLlmModel };
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

                // Auto-select remembered model or first available
                if (AvailableLlmModels.Count > 0)
                {
                    var remembered = _settings.SelectedLlmModelName;
                    var match = AvailableLlmModels.FirstOrDefault(m => m.Name == remembered);
                    SelectedLlmModel = match ?? AvailableLlmModels[0];
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
                        AddUserError("Text enhancement failed. Please retry or disable LLM enhancement.");
                    }
                }

                // Apply text enhancer plugins (sentiment analysis, etc.)
                if (PluginManager.TextEnhancer != null && PluginManager.TextEnhancer.IsEnabled)
                {
                    try
                    {
                        Logger.OperationStart("Text enhancement with plugins");
                        var enhancedWithPlugins = await PluginManager.TextEnhancer.EnhanceAsync(finalText);
                        if (!string.IsNullOrWhiteSpace(enhancedWithPlugins) && enhancedWithPlugins != finalText)
                        {
                            finalText = enhancedWithPlugins;

                            // Update segments with plugin-enhanced text
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
                                    Text = enhancedWithPlugins
                                }
                            };
                            finalVtt = TranscriptExporter.ExportToVtt(finalSegments);
                        }
                        Logger.OperationComplete("Text enhancement with plugins");
                    }
                    catch (Exception ex)
                    {
                        Logger.Error($"Plugin text enhancement failed: {ex.Message}");
                        AddUserError("A text enhancement plugin encountered an error and was skipped.");
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
                        var tts = PluginManager.TtsSynthesizer ?? (PluginManager.TtsSynthesizer = new AdvancedTtsPlugin());

                        // If the configured plugin is disabled, fall back to basic System.Speech so the checkbox still works
                        if (!tts.IsEnabled)
                        {
                            var fallbackTts = new SystemSpeechTtsPlugin();
                            await fallbackTts.SynthesizeAndPlayAsync(finalText);
                            Logger.OperationComplete("Text-to-speech (fallback)");
                        }
                        else
                        {
                            await tts.SynthesizeAndPlayAsync(finalText);
                            Logger.OperationComplete("Text-to-speech");
                        }
                    }
                    catch (Exception ex)
                    {
                        Logger.OperationFailed("Text-to-speech", ex.Message);
                        AddUserError("Speaking the response failed. Please check your TTS settings.");
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

                if (_autoPastePending && !string.IsNullOrWhiteSpace(finalText))
                {
                    try
                    {
                        Logger.OperationStart("Auto-paste (clipboard + Ctrl+V)");
                        var set = TextInjector.TrySetClipboardText(finalText);
                        if (set)
                        {
                            var pasted = TextInjector.PasteClipboard();
                            if (pasted)
                            {
                                Logger.OperationComplete("Auto-paste");
                            }
                            else
                            {
                                Logger.OperationFailed("Auto-paste", "Ctrl+V failed");
                            }
                        }
                        else
                        {
                            Logger.OperationFailed("Auto-paste", "Clipboard busy");
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
                AddUserError("Transcription failed. Please try again or check your audio setup.");
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
            var name = $"talkies_{DateTime.Now:yyyyMMdd_HHmmss}.vtt";
            var path = Path.Combine(AppContext.BaseDirectory, name);
            File.WriteAllText(path, _lastVtt);
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
            OnPropertyChanged(nameof(SegmentCount));
            OnPropertyChanged(nameof(WordCount));
            OnPropertyChanged(nameof(WordsPerMinute));
            OnPropertyChanged(nameof(CanSave));
            ErrorMessages.Clear();
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
            if (string.IsNullOrWhiteSpace(_settings.SelectedLlmModelName))
            {
                _settings.SelectedLlmModelName = DefaultLlmModel;
            }

            SelectedLlmProvider = _settings.SelectedLlmProvider ?? "LM Studio";
            LlmEndpoint = _settings.LlmEndpoint ?? "http://127.0.0.1:1234";
            SelectedEnhancementMode = _settings.SelectedEnhancementMode ?? "Grammar";

            // Load Advanced TTS settings
            _settings.AdvancedTts ??= new AdvancedTtsSettings();
            var adv = PluginManager.TtsSynthesizer as AdvancedTtsPlugin 
                      ?? (AdvancedTtsPlugin)(PluginManager.TtsSynthesizer = new AdvancedTtsPlugin());
            adv.IsEnabled = _settings.AdvancedTts.IsEnabled;
            adv.SelectedVoice = _settings.AdvancedTts.SelectedVoice;
            adv.Rate = _settings.AdvancedTts.Rate;
            adv.Pitch = _settings.AdvancedTts.Pitch;
            adv.Volume = _settings.AdvancedTts.Volume;

            // Load Sentiment plugin settings
            _settings.Sentiment ??= new SentimentSettings();
            if (PluginManager.TextEnhancer is SentimentAnalyzerPlugin sentiment)
            {
                sentiment.IsEnabled = _settings.Sentiment.IsEnabled;
                sentiment.Endpoint = _settings.Sentiment.Endpoint;
                sentiment.Model = _settings.Sentiment.Model;
            }

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

            // Persist Advanced TTS plugin settings
            if (PluginManager.TtsSynthesizer is AdvancedTtsPlugin adv)
            {
                _settings.AdvancedTts ??= new AdvancedTtsSettings();
                _settings.AdvancedTts.IsEnabled = adv.IsEnabled;
                _settings.AdvancedTts.SelectedVoice = adv.SelectedVoice;
                _settings.AdvancedTts.Rate = adv.Rate;
                _settings.AdvancedTts.Pitch = adv.Pitch;
                _settings.AdvancedTts.Volume = adv.Volume;
            }

            // Persist Sentiment plugin settings
            if (PluginManager.TextEnhancer is SentimentAnalyzerPlugin sentiment)
            {
                _settings.Sentiment ??= new SentimentSettings();
                _settings.Sentiment.IsEnabled = sentiment.IsEnabled;
                _settings.Sentiment.Endpoint = sentiment.Endpoint;
                _settings.Sentiment.Model = sentiment.Model;
            }
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

        private void AddUserError(string message)
        {
            var dispatcher = System.Windows.Application.Current?.Dispatcher ?? Dispatcher.CurrentDispatcher;
            dispatcher.Invoke(() =>
            {
                ErrorMessages.Insert(0, message);
                while (ErrorMessages.Count > 5)
                {
                    ErrorMessages.RemoveAt(ErrorMessages.Count - 1);
                }
                OnPropertyChanged(nameof(HasErrors));
            });
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

        private void ShowPluginsWindow()
        {
            var pluginsWindow = new Views.PluginsManagementWindow();
            pluginsWindow.ShowDialog();
        }

        private static string ToTimestamp(double seconds)
        {
            var ts = TimeSpan.FromSeconds(seconds);
            return $"{(int)ts.TotalHours:00}:{ts.Minutes:00}:{ts.Seconds:00}.{ts.Milliseconds:000}";
        }

        private const string DefaultGrammarPrompt = "You are a grammar and clarity assistant. Fix grammar errors, improve clarity, and correct spelling while preserving the user's intent and tone. Keep the meaning exactly the same. Return ONLY the corrected text, nothing else.";
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
