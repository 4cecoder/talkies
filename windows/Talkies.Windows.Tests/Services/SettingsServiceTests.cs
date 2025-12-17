using System.IO;
using NUnit.Framework;
using Talkies.Windows.Models;
using Talkies.Windows.Services;

namespace Talkies.Windows.Tests.Services
{
    [TestFixture]
    public class SettingsServiceTests
    {
        private string _tempDir;
        private SettingsService _settingsService;

        [SetUp]
        public void Setup()
        {
            _tempDir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
            Directory.CreateDirectory(_tempDir);
            // Mock the settings path
            Environment.SetEnvironmentVariable("TALKIES_CONFIG_PATH", Path.Combine(_tempDir, "config.json"));
            _settingsService = new SettingsService();
        }

        [TearDown]
        public void TearDown()
        {
            Environment.SetEnvironmentVariable("TALKIES_CONFIG_PATH", null);
            if (Directory.Exists(_tempDir))
            {
                Directory.Delete(_tempDir, true);
            }
        }

        [Test]
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
            Assert.IsFalse(result);
        }

        [Test]
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
            Assert.IsTrue(result);
        }

        [Test]
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
            Assert.IsTrue(result);
        }
    }
}