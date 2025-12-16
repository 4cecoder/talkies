using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.Windows.Input;
using Talkies.Windows.Models;
using Talkies.Windows.Plugins;
using Talkies.Windows.Services;

namespace Talkies.Windows.ViewModels
{
    public class PluginInfoViewModel : ViewModelBase
    {
        private readonly IPlugin _plugin;
        private readonly SettingsService _settingsService;
        private string _status = "Ready";
        private bool _hasSettings;
        private string _selectedVoice = string.Empty;
        private int _rate;
        private int _pitch;
        private int _volume;

        public string Name => _plugin.Name;
        public string Description { get; set; } = string.Empty;
        public string Icon { get; set; } = "PLG";
        public bool IsAdvancedTts => _plugin is AdvancedTtsPlugin;
        public ObservableCollection<string> Voices { get; } = new();

        public bool IsEnabled
        {
            get => _plugin.IsEnabled;
            set
            {
                _plugin.IsEnabled = value;
                if (_plugin is AdvancedTtsPlugin)
                {
                    PersistAdvancedTtsSettings();
                }
                if (_plugin is SentimentAnalyzerPlugin)
                {
                    PersistSentimentSettings();
                }
            }
        }

        public string Status
        {
            get => _status;
            set => SetProperty(ref _status, value);
        }

        public bool HasSettings
        {
            get => _hasSettings;
            set => SetProperty(ref _hasSettings, value);
        }

        public string SelectedVoice
        {
            get => _selectedVoice;
            set
            {
                if (SetProperty(ref _selectedVoice, value) && _plugin is AdvancedTtsPlugin adv)
                {
                    adv.SelectedVoice = value;
                    PersistAdvancedTtsSettings();
                }
            }
        }

        public int Rate
        {
            get => _rate;
            set
            {
                if (SetProperty(ref _rate, value) && _plugin is AdvancedTtsPlugin adv)
                {
                    adv.Rate = value;
                    PersistAdvancedTtsSettings();
                }
            }
        }

        public int Pitch
        {
            get => _pitch;
            set
            {
                if (SetProperty(ref _pitch, value) && _plugin is AdvancedTtsPlugin adv)
                {
                    adv.Pitch = value;
                    PersistAdvancedTtsSettings();
                }
            }
        }

        public int Volume
        {
            get => _volume;
            set
            {
                if (SetProperty(ref _volume, value) && _plugin is AdvancedTtsPlugin adv)
                {
                    adv.Volume = value;
                    PersistAdvancedTtsSettings();
                }
            }
        }

        public ICommand ConfigureCommand { get; }

        public PluginInfoViewModel(IPlugin plugin, SettingsService settingsService)
        {
            _plugin = plugin;
            _settingsService = settingsService;
            ConfigureCommand = new RelayCommand(_ => Configure());

            // Set icon based on plugin type (Description is set by LoadPlugins via GetPluginDescription)
            if (plugin is ITtsSynthesizer)
            {
                Icon = "TTS";

                if (plugin is AdvancedTtsPlugin)
                {
                    Icon = "TTS+";

                    // Initialize advanced controls
                    var adv = (AdvancedTtsPlugin)plugin;
                    foreach (var v in adv.AvailableVoices.Select(v => v.VoiceInfo.Name))
                    {
                        Voices.Add(v);
                    }

                    SelectedVoice = adv.SelectedVoice;
                    Rate = adv.Rate;
                    Pitch = adv.Pitch;
                    Volume = adv.Volume;
                }
            }
            else if (plugin is ITextEnhancer enhancer)
            {
                if (enhancer is OllamaEnhancer)
                {
                    Icon = "LLM";
                }
                else if (enhancer is SentimentAnalyzerPlugin)
                {
                    Icon = "SENT";
                }
                else
                {
                    Icon = "TXT";
                }
            }
        }

        private void Configure()
        {
            // Placeholder until per-plugin settings UIs are added
            Status = "Ready to configure";
        }

        private void PersistAdvancedTtsSettings()
        {
            if (_plugin is not AdvancedTtsPlugin adv)
            {
                return;
            }

            try
            {
                var settings = _settingsService.Load();
                settings.AdvancedTts ??= new AdvancedTtsSettings();
                settings.AdvancedTts.IsEnabled = adv.IsEnabled;
                settings.AdvancedTts.SelectedVoice = adv.SelectedVoice;
                settings.AdvancedTts.Rate = adv.Rate;
                settings.AdvancedTts.Pitch = adv.Pitch;
                settings.AdvancedTts.Volume = adv.Volume;
                _settingsService.Save(settings);
            }
            catch
            {
                // Ignore persistence errors in UI layer
            }
        }

        private void PersistSentimentSettings()
        {
            if (_plugin is not SentimentAnalyzerPlugin sentiment)
            {
                return;
            }

            try
            {
                var settings = _settingsService.Load();
                settings.Sentiment ??= new SentimentSettings();
                settings.Sentiment.IsEnabled = sentiment.IsEnabled;
                settings.Sentiment.Endpoint = sentiment.Endpoint;
                settings.Sentiment.Model = sentiment.Model;
                _settingsService.Save(settings);
            }
            catch
            {
                // Ignore persistence errors in UI layer
            }
        }
    }

    public class PluginsManagementViewModel : ViewModelBase
    {
        private readonly Action _closeAction;
        private readonly SettingsService _settingsService;

        public ObservableCollection<PluginInfoViewModel> Plugins { get; } = new();

        public ICommand CloseCommand { get; }

        public PluginsManagementViewModel(Action closeAction, SettingsService settingsService)
        {
            _closeAction = closeAction;
            _settingsService = settingsService;
            CloseCommand = new RelayCommand(_ => Close());

            LoadPlugins();
        }

        private void LoadPlugins()
        {
            var plugins = PluginManager.All().ToList();

            foreach (var plugin in plugins)
            {
                // Inject shared SettingsService to prevent state inconsistency
                var pluginInfo = new PluginInfoViewModel(plugin, _settingsService)
                {
                    Description = GetPluginDescription(plugin),
                    HasSettings = HasConfigurationOptions(plugin)
                };

                Plugins.Add(pluginInfo);
            }
        }

        private static string GetPluginDescription(IPlugin plugin)
        {
            return plugin switch
            {
                ITtsSynthesizer tts => $"TTS Engine: {tts.Name}",
                ITextEnhancer enhancer when enhancer is OllamaEnhancer => "LLM-powered text enhancement with multiple modes",
                ITextEnhancer enhancer when enhancer is SentimentAnalyzerPlugin => "Analyzes emotional tone (requires LM Studio sentiment model)",
                ITextEnhancer enhancer => $"Text Enhancer: {enhancer.GetType().Name}",
                _ => plugin.Name
            };
        }

        private static bool HasConfigurationOptions(IPlugin plugin)
        {
            // Hook for future plugin-specific settings pages
            return plugin switch
            {
                OllamaEnhancer => true,
                AdvancedTtsPlugin => true,
                SystemSpeechTtsPlugin => false,
                SentimentAnalyzerPlugin => false,
                _ => false
            };
        }

        private void Close()
        {
            _closeAction();
        }
    }
}
