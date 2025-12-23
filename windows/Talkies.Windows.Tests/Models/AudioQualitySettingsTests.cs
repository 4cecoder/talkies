using Xunit;
using Talkies.Windows.Models;

namespace Talkies.Windows.Tests.Models
{
    public class AudioQualitySettingsTests
    {
        [Fact]
        public void FromPreset_Low_ReturnsCorrectSettings()
        {
            // Act
            var settings = AudioQualitySettings.FromPreset(AudioQualityPreset.Low);

            // Assert
            Assert.Equal(AudioQualityPreset.Low, settings.Preset);
            Assert.Equal(16000, settings.SampleRateHz);
            Assert.Equal(16, settings.BitsPerSample);
            Assert.Equal(1, settings.ChannelCount);
        }

        [Fact]
        public void FromPreset_Medium_ReturnsCorrectSettings()
        {
            // Act
            var settings = AudioQualitySettings.FromPreset(AudioQualityPreset.Medium);

            // Assert
            Assert.Equal(AudioQualityPreset.Medium, settings.Preset);
            Assert.Equal(22050, settings.SampleRateHz);
            Assert.Equal(16, settings.BitsPerSample);
            Assert.Equal(1, settings.ChannelCount);
        }

        [Fact]
        public void FromPreset_High_ReturnsCorrectSettings()
        {
            // Act
            var settings = AudioQualitySettings.FromPreset(AudioQualityPreset.High);

            // Assert
            Assert.Equal(AudioQualityPreset.High, settings.Preset);
            Assert.Equal(44100, settings.SampleRateHz);
            Assert.Equal(16, settings.BitsPerSample);
            Assert.Equal(1, settings.ChannelCount);
        }

        [Fact]
        public void FromPreset_Studio_ReturnsCorrectSettings()
        {
            // Act
            var settings = AudioQualitySettings.FromPreset(AudioQualityPreset.Studio);

            // Assert
            Assert.Equal(AudioQualityPreset.Studio, settings.Preset);
            Assert.Equal(48000, settings.SampleRateHz);
            Assert.Equal(24, settings.BitsPerSample);
            Assert.Equal(2, settings.ChannelCount);
        }

        [Fact]
        public void GetEstimatedSizePerMinuteMB_LowQuality_ReturnsSmallSize()
        {
            // Arrange
            var settings = AudioQualitySettings.FromPreset(AudioQualityPreset.Low);

            // Act
            var sizeMB = settings.GetEstimatedSizePerMinuteMB();

            // Assert
            Assert.True(sizeMB < 1.0); // Should be less than 1 MB per minute
        }

        [Fact]
        public void GetEstimatedSizePerMinuteMB_StudioQuality_ReturnsLargeSize()
        {
            // Arrange
            var settings = AudioQualitySettings.FromPreset(AudioQualityPreset.Studio);

            // Act
            var sizeMB = settings.GetEstimatedSizePerMinuteMB();

            // Assert
            Assert.True(sizeMB > 5.0); // Should be more than 5 MB per minute
        }

        [Fact]
        public void GetEstimatedSizeDisplay_ReturnsFormattedString()
        {
            // Arrange
            var settings = AudioQualitySettings.FromPreset(AudioQualityPreset.High);

            // Act
            var display = settings.GetEstimatedSizeDisplay();

            // Assert
            Assert.Contains("MB/min", display);
            Assert.Contains("~", display);
        }
    }
}