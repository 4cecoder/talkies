using System;
using Talkies.Windows.Models;
using Xunit;

namespace Talkies.Windows.Tests.Models
{
    public class TranscriptSegmentTests
    {
        [Fact]
        public void TranscriptSegment_DefaultConstructor_SetsDefaultValues()
        {
            // Act
            var segment = new TranscriptSegment();

            // Assert
            Assert.Equal("00:00:00.000", segment.Timestamp);
            Assert.Equal(string.Empty, segment.Text);
            Assert.Equal(0, segment.Start);
            Assert.Equal(0, segment.End);
        }

        [Fact]
        public void TranscriptSegment_CanSetTimestamp()
        {
            // Arrange
            var segment = new TranscriptSegment();
            var expectedTimestamp = "00:01:23.456";

            // Act
            segment.Timestamp = expectedTimestamp;

            // Assert
            Assert.Equal(expectedTimestamp, segment.Timestamp);
        }

        [Fact]
        public void TranscriptSegment_CanSetText()
        {
            // Arrange
            var segment = new TranscriptSegment();
            var expectedText = "Hello, this is a test transcription";

            // Act
            segment.Text = expectedText;

            // Assert
            Assert.Equal(expectedText, segment.Text);
        }

        [Fact]
        public void TranscriptSegment_CanSetStart()
        {
            // Arrange
            var segment = new TranscriptSegment();
            var expectedStart = 12.5;

            // Act
            segment.Start = expectedStart;

            // Assert
            Assert.Equal(expectedStart, segment.Start);
        }

        [Fact]
        public void TranscriptSegment_CanSetEnd()
        {
            // Arrange
            var segment = new TranscriptSegment();
            var expectedEnd = 25.75;

            // Act
            segment.End = expectedEnd;

            // Assert
            Assert.Equal(expectedEnd, segment.End);
        }

        [Fact]
        public void TranscriptSegment_ObjectInitializer_SetsAllProperties()
        {
            // Act
            var segment = new TranscriptSegment
            {
                Timestamp = "00:00:05.250",
                Text = "Test segment text",
                Start = 5.25,
                End = 8.50
            };

            // Assert
            Assert.Equal("00:00:05.250", segment.Timestamp);
            Assert.Equal("Test segment text", segment.Text);
            Assert.Equal(5.25, segment.Start);
            Assert.Equal(8.50, segment.End);
        }

        [Fact]
        public void TranscriptSegment_AcceptsEmptyText()
        {
            // Act
            var segment = new TranscriptSegment
            {
                Text = ""
            };

            // Assert
            Assert.Equal(string.Empty, segment.Text);
        }

        [Fact]
        public void TranscriptSegment_AcceptsNullText()
        {
            // Act
            var segment = new TranscriptSegment
            {
                Text = null!
            };

            // Assert
            Assert.Null(segment.Text);
        }

        [Fact]
        public void TranscriptSegment_AcceptsZeroTimes()
        {
            // Act
            var segment = new TranscriptSegment
            {
                Start = 0.0,
                End = 0.0
            };

            // Assert
            Assert.Equal(0.0, segment.Start);
            Assert.Equal(0.0, segment.End);
        }

        [Fact]
        public void TranscriptSegment_AcceptsNegativeTimes()
        {
            // Act
            var segment = new TranscriptSegment
            {
                Start = -1.0,
                End = -0.5
            };

            // Assert
            Assert.Equal(-1.0, segment.Start);
            Assert.Equal(-0.5, segment.End);
        }

        [Fact]
        public void TranscriptSegment_AcceptsLargeTimes()
        {
            // Act
            var segment = new TranscriptSegment
            {
                Start = 3600.0, // 1 hour
                End = 7200.5   // 2 hours + 0.5s
            };

            // Assert
            Assert.Equal(3600.0, segment.Start);
            Assert.Equal(7200.5, segment.End);
        }

        [Fact]
        public void TranscriptSegment_AllowsEndBeforeStart()
        {
            // This tests that the model doesn't enforce logical constraints
            // (validation should be done at a higher level if needed)

            // Act
            var segment = new TranscriptSegment
            {
                Start = 10.0,
                End = 5.0
            };

            // Assert
            Assert.Equal(10.0, segment.Start);
            Assert.Equal(5.0, segment.End);
        }

        [Fact]
        public void TranscriptSegment_SupportsLongText()
        {
            // Arrange
            var longText = new string('a', 10000);

            // Act
            var segment = new TranscriptSegment
            {
                Text = longText
            };

            // Assert
            Assert.Equal(10000, segment.Text.Length);
            Assert.Equal(longText, segment.Text);
        }

        [Fact]
        public void TranscriptSegment_SupportsUnicodeText()
        {
            // Act
            var segment = new TranscriptSegment
            {
                Text = "Hello 世界 🌍 مرحبا"
            };

            // Assert
            Assert.Equal("Hello 世界 🌍 مرحبا", segment.Text);
        }

        [Fact]
        public void TranscriptSegment_SupportsSpecialCharactersInText()
        {
            // Act
            var segment = new TranscriptSegment
            {
                Text = "Line1\nLine2\tTabbed\r\nNewline"
            };

            // Assert
            Assert.Contains("\n", segment.Text);
            Assert.Contains("\t", segment.Text);
            Assert.Contains("\r\n", segment.Text);
        }

        [Fact]
        public void TranscriptSegment_MultipleInstances_AreIndependent()
        {
            // Arrange
            var segment1 = new TranscriptSegment
            {
                Timestamp = "00:00:01.000",
                Text = "First segment",
                Start = 1.0,
                End = 2.0
            };

            var segment2 = new TranscriptSegment
            {
                Timestamp = "00:00:03.000",
                Text = "Second segment",
                Start = 3.0,
                End = 4.0
            };

            // Assert
            Assert.NotEqual(segment1.Timestamp, segment2.Timestamp);
            Assert.NotEqual(segment1.Text, segment2.Text);
            Assert.NotEqual(segment1.Start, segment2.Start);
            Assert.NotEqual(segment1.End, segment2.End);
        }

        [Fact]
        public void TranscriptSegment_PropertiesAreReadWrite()
        {
            // Arrange
            var segment = new TranscriptSegment
            {
                Timestamp = "00:00:01.000",
                Text = "Initial",
                Start = 1.0,
                End = 2.0
            };

            // Act - Modify all properties
            segment.Timestamp = "00:00:05.000";
            segment.Text = "Modified";
            segment.Start = 5.0;
            segment.End = 6.0;

            // Assert
            Assert.Equal("00:00:05.000", segment.Timestamp);
            Assert.Equal("Modified", segment.Text);
            Assert.Equal(5.0, segment.Start);
            Assert.Equal(6.0, segment.End);
        }

        [Fact]
        public void TranscriptSegment_SupportsVeryPreciseTimings()
        {
            // Act
            var segment = new TranscriptSegment
            {
                Start = 1.23456789,
                End = 2.98765432
            };

            // Assert
            Assert.Equal(1.23456789, segment.Start);
            Assert.Equal(2.98765432, segment.End);
        }
    }
}
