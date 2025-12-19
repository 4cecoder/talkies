using System;
using System.Collections.Generic;
using System.Linq;
using Talkies.Windows.Models;
using Talkies.Windows.Services;
using Xunit;

namespace Talkies.Windows.Tests.Services
{
    public class ExportTests
    {
        private readonly WhisperNetTranscriptionService _service;
        private readonly List<TranscriptSegment> _testSegments;

        public ExportTests()
        {
            _service = new WhisperNetTranscriptionService();
            _testSegments = new List<TranscriptSegment>
            {
                new TranscriptSegment
                {
                    Timestamp = "00:00:00.000",
                    Start = 0.0,
                    End = 2.5,
                    Text = "Hello world"
                },
                new TranscriptSegment
                {
                    Timestamp = "00:00:02.500",
                    Start = 2.5,
                    End = 5.0,
                    Text = "This is a test"
                },
                new TranscriptSegment
                {
                    Timestamp = "00:00:05.000",
                    Start = 5.0,
                    End = 8.750,
                    Text = "Testing export formats"
                }
            };
        }

        [Fact]
        public void ExportVtt_ProducesValidVttFormat()
        {
            // Act
            var result = _service.ExportVtt(_testSegments);

            // Assert
            Assert.NotNull(result);
            Assert.NotEmpty(result);
            Assert.StartsWith("WEBVTT", result);
            Assert.Contains("00:00:00.000 --> 00:00:02.500", result);
            Assert.Contains("Hello world", result);
        }

        [Fact]
        public void ExportVtt_ContainsAllSegments()
        {
            // Act
            var result = _service.ExportVtt(_testSegments);

            // Assert
            Assert.Contains("Hello world", result);
            Assert.Contains("This is a test", result);
            Assert.Contains("Testing export formats", result);
        }

        [Fact]
        public void ExportVtt_HasCorrectTimestampFormat()
        {
            // Act
            var result = _service.ExportVtt(_testSegments);

            // Assert
            // VTT uses format: HH:MM:SS.mmm
            Assert.Contains("00:00:00.000 --> 00:00:02.500", result);
            Assert.Contains("00:00:02.500 --> 00:00:05.000", result);
            Assert.Contains("00:00:05.000 --> 00:00:08.750", result);
        }

        [Fact]
        public void ExportVtt_EmptySegments_ReturnsHeaderOnly()
        {
            // Arrange
            var emptySegments = new List<TranscriptSegment>();

            // Act
            var result = _service.ExportVtt(emptySegments);

            // Assert
            Assert.NotNull(result);
            Assert.StartsWith("WEBVTT", result);
            Assert.DoesNotContain("-->", result.Substring(7)); // No timestamps after header
        }

        [Fact]
        public void ExportSrt_ProducesValidSrtFormat()
        {
            // Act
            var result = _service.ExportSrt(_testSegments);

            // Assert
            Assert.NotNull(result);
            Assert.NotEmpty(result);
            // SRT should start with sequence number 1
            Assert.StartsWith("1", result.TrimStart());
            Assert.Contains("Hello world", result);
        }

        [Fact]
        public void ExportSrt_ContainsSequenceNumbers()
        {
            // Act
            var result = _service.ExportSrt(_testSegments);

            // Assert
            // Should have sequence numbers 1, 2, 3
            var lines = result.Split(new[] { Environment.NewLine }, StringSplitOptions.None);
            Assert.Contains("1", lines);
            Assert.Contains("2", lines);
            Assert.Contains("3", lines);
        }

        [Fact]
        public void ExportSrt_HasCorrectTimestampFormat()
        {
            // Act
            var result = _service.ExportSrt(_testSegments);

            // Assert
            // SRT uses format: HH:MM:SS,mmm (comma instead of period)
            Assert.Contains("00:00:00,000 --> 00:00:02,500", result);
            Assert.Contains("00:00:02,500 --> 00:00:05,000", result);
            Assert.Contains("00:00:05,000 --> 00:00:08,750", result);
        }

        [Fact]
        public void ExportSrt_ContainsAllSegments()
        {
            // Act
            var result = _service.ExportSrt(_testSegments);

            // Assert
            Assert.Contains("Hello world", result);
            Assert.Contains("This is a test", result);
            Assert.Contains("Testing export formats", result);
        }

        [Fact]
        public void ExportSrt_EmptySegments_ReturnsEmptyString()
        {
            // Arrange
            var emptySegments = new List<TranscriptSegment>();

            // Act
            var result = _service.ExportSrt(emptySegments);

            // Assert
            Assert.NotNull(result);
            Assert.Empty(result);
        }

        [Fact]
        public void ExportTxt_ProducesPlainText()
        {
            // Act
            var result = _service.ExportTxt(_testSegments);

            // Assert
            Assert.NotNull(result);
            Assert.NotEmpty(result);
            Assert.Contains("Hello world", result);
            Assert.Contains("This is a test", result);
            Assert.Contains("Testing export formats", result);
        }

        [Fact]
        public void ExportTxt_NoTimestamps()
        {
            // Act
            var result = _service.ExportTxt(_testSegments);

            // Assert
            // Plain text should not contain timestamps
            Assert.DoesNotContain("00:00:", result);
            Assert.DoesNotContain("-->", result);
        }

        [Fact]
        public void ExportTxt_HasNewlineSeparatedSegments()
        {
            // Act
            var result = _service.ExportTxt(_testSegments);

            // Assert
            var lines = result.Split(new[] { Environment.NewLine }, StringSplitOptions.RemoveEmptyEntries);
            Assert.Equal(3, lines.Length);
            Assert.Equal("Hello world", lines[0]);
            Assert.Equal("This is a test", lines[1]);
            Assert.Equal("Testing export formats", lines[2]);
        }

        [Fact]
        public void ExportTxt_EmptySegments_ReturnsEmptyString()
        {
            // Arrange
            var emptySegments = new List<TranscriptSegment>();

            // Act
            var result = _service.ExportTxt(emptySegments);

            // Assert
            Assert.NotNull(result);
            Assert.Empty(result);
        }

        [Fact]
        public void ExportTxt_PreservesSegmentOrder()
        {
            // Act
            var result = _service.ExportTxt(_testSegments);

            // Assert
            var indexHello = result.IndexOf("Hello world");
            var indexTest = result.IndexOf("This is a test");
            var indexExport = result.IndexOf("Testing export formats");

            Assert.True(indexHello < indexTest);
            Assert.True(indexTest < indexExport);
        }

        [Fact]
        public void ExportVtt_SingleSegment_FormatsCorrectly()
        {
            // Arrange
            var singleSegment = new List<TranscriptSegment>
            {
                new TranscriptSegment
                {
                    Timestamp = "00:00:00.000",
                    Start = 0.0,
                    End = 1.0,
                    Text = "Single segment"
                }
            };

            // Act
            var result = _service.ExportVtt(singleSegment);

            // Assert
            Assert.Contains("WEBVTT", result);
            Assert.Contains("00:00:00.000 --> 00:00:01.000", result);
            Assert.Contains("Single segment", result);
        }

        [Fact]
        public void ExportSrt_SingleSegment_FormatsCorrectly()
        {
            // Arrange
            var singleSegment = new List<TranscriptSegment>
            {
                new TranscriptSegment
                {
                    Timestamp = "00:00:00.000",
                    Start = 0.0,
                    End = 1.0,
                    Text = "Single segment"
                }
            };

            // Act
            var result = _service.ExportSrt(singleSegment);

            // Assert
            Assert.StartsWith("1", result.TrimStart());
            Assert.Contains("00:00:00,000 --> 00:00:01,000", result);
            Assert.Contains("Single segment", result);
        }
    }
}
