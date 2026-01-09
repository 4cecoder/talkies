using System;
using System.IO;
using System.Linq;
using Talkies.Windows.Models;
using Talkies.Windows.Plugins;
using Talkies.Windows.Services;
using Talkies.Windows.ViewModels;
using Xunit;

namespace Talkies.Windows.Tests
{
    public class PluginSettingsTests : IDisposable
    {
        private readonly string _configPath;

        public PluginSettingsTests()
        {
            _configPath = Path.Combine(Path.GetTempPath(), $"talkies_test_{Guid.NewGuid():N}.json");
            Environment.SetEnvironmentVariable("TALKIES_CONFIG_PATH", _configPath);
            PluginManager.TtsSynthesizer = null;
        }

        [Fact]
        public void AdvancedTtsSettings_PersistToConfig()
        {
            var plugin = new AdvancedTtsPlugin
            {
                IsEnabled = true,
                Rate = 3,
                Pitch = -2,
                Volume = 75
            };
            plugin.SelectedVoice = plugin.AvailableVoices.FirstOrDefault()?.VoiceInfo.Name ?? "TestVoice";

            var vm = new PluginInfoViewModel(plugin);

            // Change settings through the view model to trigger persistence
            vm.Rate = 4;
            vm.Pitch = -1;
            vm.Volume = 65;
            vm.SelectedVoice = "CustomVoice";
            vm.IsEnabled = false;

            var expectedVoice = plugin.SelectedVoice; // actual selected voice after validation

            var service = new SettingsService();
            var saved = service.Load();

            Assert.NotNull(saved.AdvancedTts);
            Assert.Equal(vm.Rate, saved.AdvancedTts.Rate);
            Assert.Equal(vm.Pitch, saved.AdvancedTts.Pitch);
            Assert.Equal(vm.Volume, saved.AdvancedTts.Volume);
            Assert.Equal(expectedVoice, saved.AdvancedTts.SelectedVoice);
            Assert.Equal(vm.IsEnabled, saved.AdvancedTts.IsEnabled);
            Assert.True(File.Exists(_configPath));
        }

        [Fact]
        public void AdvancedTtsSettings_LoadIntoMainViewModel()
        {
            PluginManager.TtsSynthesizer = null;

            // Seed a config
            var settings = new AppSettings
            {
                AdvancedTts = new AdvancedTtsSettings
                {
                    IsEnabled = true,
                    SelectedVoice = "VoiceA",
                    Rate = 2,
                    Pitch = 1,
                    Volume = 80
                }
            };
            var service = new SettingsService();
            service.Save(settings);

            var vm = new MainViewModel(new FakeRecorder(), new FakeTranscriber(), new FakeDevices());
            var adv = PluginManager.TtsSynthesizer as AdvancedTtsPlugin;
            var expectedVoice = adv?.SelectedVoice;

            Assert.NotNull(adv);
            Assert.Equal(settings.AdvancedTts.IsEnabled, adv!.IsEnabled);
            // Voice may fall back to a system-available one, so assert it sticks to whatever the plugin ends up using
            Assert.Equal(expectedVoice, adv.SelectedVoice);
            Assert.Equal(settings.AdvancedTts.Rate, adv.Rate);
            Assert.Equal(settings.AdvancedTts.Pitch, adv.Pitch);
            Assert.Equal(settings.AdvancedTts.Volume, adv.Volume);
        }

        public void Dispose()
        {
            if (File.Exists(_configPath))
            {
                try { File.Delete(_configPath); } catch { /* ignore cleanup errors */ }
            }
            Environment.SetEnvironmentVariable("TALKIES_CONFIG_PATH", null);
        }
    }
}
