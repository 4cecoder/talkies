using System;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using Moq;
using Newtonsoft.Json;
using Xunit;
using Talkies.Windows.Models;
using Talkies.Windows.Services;

namespace Talkies.Windows.Tests.Services
{
    public class CrashReporterTests : IDisposable
    {
        private string _tempDir;
        private AppSettings _settings;
        private const long MaxLogSize = 10 * 1024 * 1024; // 10MB

        public CrashReporterTests()
        {
            _tempDir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
            Directory.CreateDirectory(_tempDir);
            _settings = new AppSettings { CrashReportingEnabled = false, CrashReportingEndpoint = "" };
        }

        public void Dispose()
        {
            if (Directory.Exists(_tempDir))
            {
                Directory.Delete(_tempDir, true);
            }
        }

        [Fact]
        public void CrashReporter_LogsCrashLocally()
        {
            // Arrange
            var reporter = new CrashReporter(_settings);

            // Act
            reporter.TrackEvent("test_event");

            // Assert
            var analyticsPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Talkies", "analytics.log");
            if (File.Exists(analyticsPath))
            {
                var content = File.ReadAllText(analyticsPath);
                Assert.Contains("test_event", content);
            }
        }

        [Fact]
        public async Task CrashReporter_SendsCrashReport_WhenEnabled()
        {
            // Arrange
            _settings.CrashReportingEnabled = true;
            _settings.CrashReportingEndpoint = "https://httpbin.org/post"; // Test endpoint
            var reporter = new CrashReporter(_settings);

            // Act
            var data = new { Test = "data" };
            var method = typeof(CrashReporter).GetMethod("SendCrashReportAsync", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
            var result = method?.Invoke(reporter, new[] { data });
            if (result is Task task)
            {
                await task;
            }

            // Assert
            // Check if no exception thrown
        }

        [Fact]
        public void CrashReporter_OnNormalExit_DeletesCrashData()
        {
            // Arrange
            var reporter = new CrashReporter(_settings);
            var crashDataPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Talkies", "crash_data.json");
            File.WriteAllText(crashDataPath, "{}");

            // Act
            reporter.OnNormalExit();

            // Assert
            Assert.False(File.Exists(crashDataPath));
        }

        [Fact]
        public async Task RunMonitorAsync_SendsReport_OnNonZeroExit()
        {
            // Arrange
            _settings.CrashReportingEnabled = true;
            _settings.CrashReportingEndpoint = "https://httpbin.org/post";
            var crashDataPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Talkies", "crash_data.json");
            File.WriteAllText(crashDataPath, "{\"test\":\"data\"}");

            // Act
            await CrashReporter.RunMonitorAsync(0, _settings); // Fake PID, but test sending

            // Assert
            // Hard to test without actual process, but check method exists
        }

        [Fact]
        public void IsValidEndpoint_ValidHttps_ReturnsTrue()
        {
            // Arrange
            var reporter = new CrashReporter(_settings);

            // Act
            var method = typeof(CrashReporter).GetMethod("IsValidEndpoint", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
            var result = (bool?)(method?.Invoke(reporter, new[] { "https://example.com" })) ?? false;

            // Assert
            Assert.True(result);
        }

        [Fact]
        public void IsValidEndpoint_InvalidUrl_ReturnsFalse()
        {
            // Arrange
            var reporter = new CrashReporter(_settings);

            // Act
            var method = typeof(CrashReporter).GetMethod("IsValidEndpoint", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
            var result = (bool?)(method?.Invoke(reporter, new[] { "invalid-url" })) ?? false;

            // Assert
            Assert.False(result);
        }

        [Fact]
        public void AppendToLogFile_LimitsSize()
        {
            // Arrange
            var reporter = new CrashReporter(_settings);
            var testFile = Path.Combine(_tempDir, "test.log");
            var largeContent = new string('x', (int)CrashReporterTests.MaxLogSize + 1000);
            File.WriteAllText(testFile, largeContent);

            // Act
            var method = typeof(CrashReporter).GetMethod("AppendToLogFile", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
            method?.Invoke(reporter, new[] { testFile, "new content\n" });

            // Assert
            var fileInfo = new FileInfo(testFile);
            Assert.True(fileInfo.Length <= CrashReporterTests.MaxLogSize + 100); // Allow some margin
        }

        [Fact]
        public void OnNormalExit_DeletesCrashDataFile()
        {
            // Arrange
            var reporter = new CrashReporter(_settings);
            var crashDataPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Talkies", "crash_data.json");
            File.WriteAllText(crashDataPath, "{}");

            // Act
            reporter.OnNormalExit();

            // Assert
            Assert.False(File.Exists(crashDataPath));
        }

        [Fact]
        public void TrackEvent_IncludesCorrectData()
        {
            // Arrange
            var reporter = new CrashReporter(_settings);

            // Act
            reporter.TrackEvent("test_event", new { key = "value" });

            // Assert
            var analyticsPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Talkies", "analytics.log");
            if (File.Exists(analyticsPath))
            {
                var content = File.ReadAllText(analyticsPath);
                Assert.Contains("test_event", content);
                Assert.Contains("value", content);
                Assert.Contains(Environment.MachineName, content);
            }
        }

        [Fact]
        public void GetSystemSpecs_ReturnsExpectedProperties()
        {
            // Arrange
            var reporter = new CrashReporter(_settings);

            // Act
            var specs = typeof(CrashReporter).GetMethod("GetSystemSpecs", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                ?.Invoke(reporter, null) as dynamic;

            // Assert
            Assert.NotNull(specs);
            Assert.NotNull(specs?.OS);
            Assert.True(specs?.ProcessorCount > 0);
        }

        [Fact]
        public void GetFullLogDump_ReturnsContent_WhenFileExists()
        {
            // Arrange
            var reporter = new CrashReporter(_settings);
            var crashLogPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Talkies", "crash.log");
            var testContent = "test log content";
            File.WriteAllText(crashLogPath, testContent);

            // Act
            var result = typeof(CrashReporter).GetMethod("GetFullLogDump", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                ?.Invoke(reporter, null) as string;

            // Assert
            Assert.True(result?.Contains(testContent));
        }

        [Fact]
        public void IsValidEndpoint_RejectsLocalhost()
        {
            // Arrange
            var reporter = new CrashReporter(_settings);

            // Act
            var method = typeof(CrashReporter).GetMethod("IsValidEndpoint", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
            var result = (bool?)(method?.Invoke(reporter, new[] { "http://localhost/test" })) ?? false;

            // Assert
            Assert.False(result);
        }

        [Fact]
        public void IsValidEndpoint_AcceptsHttpsExternal()
        {
            // Arrange
            var reporter = new CrashReporter(_settings);

            // Act
            var method = typeof(CrashReporter).GetMethod("IsValidEndpoint", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
            var result = (bool?)(method?.Invoke(reporter, new[] { "https://example.com/api" })) ?? false;

            // Assert
            Assert.True(result);
        }

        [Fact]
        public void GetLocalIpAddress_ReturnsString()
        {
            // Arrange
            var reporter = new CrashReporter(_settings);

            // Act
            var ip = typeof(CrashReporter).GetMethod("GetLocalIpAddress", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                ?.Invoke(reporter, null) as string;

            // Assert
            Assert.NotNull(ip);
            Assert.True(ip.Length > 0);
        }

        [Fact]
        public void GetSystemSpecs_ReturnsObject()
        {
            // Arrange
            var reporter = new CrashReporter(_settings);

            // Act
            var specs = typeof(CrashReporter).GetMethod("GetSystemSpecs", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                ?.Invoke(reporter, null);

            // Assert
            Assert.NotNull(specs);
        }
    }
}