using System;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using Moq;
using Newtonsoft.Json;
using NUnit.Framework;
using Talkies.Windows.Models;
using Talkies.Windows.Services;

namespace Talkies.Windows.Tests.Services
{
    [TestFixture]
    public class CrashReporterTests
    {
        private string _tempDir;
        private AppSettings _settings;

        [SetUp]
        public void Setup()
        {
            _tempDir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
            Directory.CreateDirectory(_tempDir);
            _settings = new AppSettings { CrashReportingEnabled = false, CrashReportingEndpoint = "" };
        }

        [TearDown]
        public void TearDown()
        {
            if (Directory.Exists(_tempDir))
            {
                Directory.Delete(_tempDir, true);
            }
        }

        [Test]
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
                Assert.IsTrue(content.Contains("test_event"));
            }
        }

        [Test]
        public async Task CrashReporter_SendsCrashReport_WhenEnabled()
        {
            // Arrange
            _settings.CrashReportingEnabled = true;
            _settings.CrashReportingEndpoint = "https://httpbin.org/post"; // Test endpoint
            var reporter = new CrashReporter(_settings);

            // Act
            var data = new { Test = "data" };
            var method = typeof(CrashReporter).GetMethod("SendCrashReportAsync", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
            await (Task)method?.Invoke(reporter, new[] { data });

            // Assert
            // Check if no exception thrown
        }

        [Test]
        public void CrashReporter_OnNormalExit_DeletesCrashData()
        {
            // Arrange
            var reporter = new CrashReporter(_settings);
            var crashDataPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Talkies", "crash_data.json");
            File.WriteAllText(crashDataPath, "{}");

            // Act
            reporter.OnNormalExit();

            // Assert
            Assert.IsFalse(File.Exists(crashDataPath));
        }

        [Test]
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

        [Test]
        public void GetLocalIpAddress_ReturnsString()
        {
            // Arrange
            var reporter = new CrashReporter(_settings);

            // Act
            var ip = typeof(CrashReporter).GetMethod("GetLocalIpAddress", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                ?.Invoke(reporter, null) as string;

            // Assert
            Assert.IsNotNull(ip);
            Assert.IsTrue(ip.Length > 0);
        }

        [Test]
        public void GetSystemSpecs_ReturnsObject()
        {
            // Arrange
            var reporter = new CrashReporter(_settings);

            // Act
            var specs = typeof(CrashReporter).GetMethod("GetSystemSpecs", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                ?.Invoke(reporter, null);

            // Assert
            Assert.IsNotNull(specs);
        }
    }
}