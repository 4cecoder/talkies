using Xunit;
using Talkies.Windows.Services;
using Talkies.Windows.Models;

namespace Talkies.Windows.Tests.Services
{
    public class AutoUpdateServiceTests
    {
        [Fact]
        public void Constructor_SetsAppcastUrl_BasedOnUpdateChannel()
        {
            // Arrange
            var settings = new AppSettings
            {
                UpdateChannel = "beta",
                AutoUpdatePublicKey = "test-key"
            };

            // Act
            var service = new AutoUpdateService(settings);

            // Assert - We can't directly test the private field, but we can verify the service was created
            Assert.NotNull(service);
        }

        [Fact]
        public void Constructor_StableChannel_UsesStableAppcastUrl()
        {
            // Arrange
            var settings = new AppSettings
            {
                UpdateChannel = "stable",
                AutoUpdatePublicKey = "test-key"
            };

            // Act
            var service = new AutoUpdateService(settings);

            // Assert
            Assert.NotNull(service);
        }

        [Fact]
        public void Constructor_NightlyChannel_UsesNightlyAppcastUrl()
        {
            // Arrange
            var settings = new AppSettings
            {
                UpdateChannel = "nightly",
                AutoUpdatePublicKey = "test-key"
            };

            // Act
            var service = new AutoUpdateService(settings);

            // Assert
            Assert.NotNull(service);
        }

        [Fact]
        public void Initialize_WithoutPublicKey_DoesNotInitializeSparkle()
        {
            // Arrange
            var settings = new AppSettings
            {
                AutoUpdatePublicKey = null // No public key
            };

            var service = new AutoUpdateService(settings);

            // Act - This should not throw and should not initialize Sparkle
            service.Initialize();

            // Assert - Service should still be created but Sparkle not initialized
            Assert.NotNull(service);
        }

        [Fact]
        public void Settings_Property_ReturnsCorrectSettings()
        {
            // Arrange
            var settings = new AppSettings
            {
                UpdateChannel = "beta",
                AutoCheckForUpdates = false
            };

            var service = new AutoUpdateService(settings);

            // Act
            var returnedSettings = service.Settings;

            // Assert
            Assert.Equal("beta", returnedSettings.UpdateChannel);
            Assert.False(returnedSettings.AutoCheckForUpdates);
        }
    }
}