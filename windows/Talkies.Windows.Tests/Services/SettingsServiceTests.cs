using System.IO;
using System;
using Xunit;
using Talkies.Windows.Models;
using Talkies.Windows.Services;

namespace Talkies.Windows.Tests.Services
{
    public class SettingsServiceTests : IDisposable
    {
        private string _tempDir;
        private SettingsService _settingsService;

        public SettingsServiceTests()
        {
            _tempDir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
            Directory.CreateDirectory(_tempDir);
            // Mock the settings path
            Environment.SetEnvironmentVariable("TALKIES_CONFIG_PATH", Path.Combine(_tempDir, "config.json"));
            _settingsService = new SettingsService();
        }

        public void Dispose()
        {
            // Clean up
            Environment.SetEnvironmentVariable("TALKIES_CONFIG_PATH", null);
            if (Directory.Exists(_tempDir))
            {
                Directory.Delete(_tempDir, true);
            }
        }

        [Fact]
        public void Load_ReturnsDefaultSettings_WhenFileDoesNotExist()
        {
            // Act
            var settings = _settingsService.Load();

            // Assert
            Assert.NotNull(settings);
            Assert.Equal("tiny", settings.Model);
        }

        [Fact]
        public void SaveAndLoad_PreservesSettings()
        {
            // Arrange
            var originalSettings = new AppSettings
            {
                Model = "base",
                Language = "en"
            };

            // Act
            _settingsService.Save(originalSettings);
            var loadedSettings = _settingsService.Load();

            // Assert
            Assert.Equal(originalSettings.Model, loadedSettings.Model);
            Assert.Equal(originalSettings.Language, loadedSettings.Language);
        }

        [Fact]
        public void ValidateCrashReportingSettings_ReturnsFalse_WhenEnabledButNotAccepted()
        {
            // Arrange
            var settings = new AppSettings
            {
                CrashReportingEnabled = true,
                CrashReportingPrivacyAccepted = false
            };

            // Act
            var result = typeof(SettingsService).GetMethod("ValidateCrashReportingSettings", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                ?.Invoke(_settingsService, new[] { settings }) as bool?;

            // Assert
            Assert.False(result);
        }

        [Fact]
        public void ValidateCrashReportingSettings_ReturnsTrue_WhenEnabledAndAccepted()
        {
            // Arrange
            var settings = new AppSettings
            {
                CrashReportingEnabled = true,
                CrashReportingPrivacyAccepted = true
            };

            // Act
            var result = typeof(SettingsService).GetMethod("ValidateCrashReportingSettings", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                ?.Invoke(_settingsService, new[] { settings }) as bool?;

            // Assert
            Assert.True(result);
        }

        [Fact]
        public void ValidateCrashReportingSettings_ReturnsTrue_WhenDisabled()
        {
            // Arrange
            var settings = new AppSettings
            {
                CrashReportingEnabled = false,
                CrashReportingPrivacyAccepted = false
            };

            // Act
            var result = typeof(SettingsService).GetMethod("ValidateCrashReportingSettings", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                ?.Invoke(_settingsService, new[] { settings }) as bool?;

            // Assert
            Assert.True(result);
        }
    }
}