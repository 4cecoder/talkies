using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Net.NetworkInformation;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Talkies.Windows.Models;

namespace Talkies.Windows.Services
{
    /// <summary>
    /// Crash reporting and analytics service for Windows platform.
    /// Logs crashes and analytics events to local files and optionally sends to endpoint via background monitor.
    /// </summary>
    public class CrashReporter
    {
        private readonly string _crashLogPath;
        private readonly string _analyticsLogPath;
        private readonly string _crashDataPath;
        private static readonly HttpClient _httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
        private readonly AppSettings _settings;
        private const long MaxLogSize = 10 * 1024 * 1024; // 10MB

        public CrashReporter(AppSettings settings)
        {
            _settings = settings;
            var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            var talkiesDir = Path.Combine(appData, "Talkies");

            if (!Directory.Exists(talkiesDir))
            {
                Directory.CreateDirectory(talkiesDir);
            }

            _crashLogPath = Path.Combine(talkiesDir, "crash.log");
            _analyticsLogPath = Path.Combine(talkiesDir, "analytics.log");
            _crashDataPath = Path.Combine(talkiesDir, "crash_data.json");

            StartMonitor();

            AppDomain.CurrentDomain.UnhandledException += OnUnhandledException;
            TaskScheduler.UnobservedTaskException += OnUnobservedTaskException;
        }

        private void StartMonitor()
        {
            try
            {
                var exePath = Process.GetCurrentProcess().MainModule?.FileName;
                if (exePath != null)
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = exePath,
                        Arguments = $"monitor {Process.GetCurrentProcess().Id}",
                        UseShellExecute = false,
                        CreateNoWindow = true,
                        RedirectStandardOutput = true,
                        RedirectStandardError = true
                    });
                }
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to start crash monitor: {ex.Message}");
            }
        }

        private void OnUnhandledException(object sender, UnhandledExceptionEventArgs e)
        {
            var crashData = new
            {
                Timestamp = DateTime.UtcNow.ToString("O"),
                PcName = Environment.MachineName,
                Ip = GetLocalIpAddress(),
                Specs = GetSystemSpecs(),
                Exception = e.ExceptionObject?.ToString() ?? "Unknown exception",
                IsTerminating = e.IsTerminating,
                Platform = "windows",
                Version = GetType().Assembly.GetName().Version?.ToString() ?? "unknown",
                FullLogDump = GetFullLogDump()
            };

            LogCrash(crashData);
            SaveCrashDataForMonitor(crashData);
        }

        private void OnUnobservedTaskException(object sender, UnobservedTaskExceptionEventArgs e)
        {
            var crashData = new
            {
                Timestamp = DateTime.UtcNow.ToString("O"),
                PcName = Environment.MachineName,
                Ip = GetLocalIpAddress(),
                Specs = GetSystemSpecs(),
                Exception = e.Exception?.ToString() ?? "Unknown task exception",
                Platform = "windows",
                Version = GetType().Assembly.GetName().Version?.ToString() ?? "unknown",
                FullLogDump = GetFullLogDump()
            };

            LogCrash(crashData);
            SaveCrashDataForMonitor(crashData);
            e.SetObserved();
        }

        private void SaveCrashDataForMonitor(object data)
        {
            try
            {
                var json = JsonSerializer.Serialize(data);
                File.WriteAllText(_crashDataPath, json);
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to save crash data: {ex.Message}");
            }
        }

        private void LogCrash(object data)
        {
            try
            {
                var json = JsonSerializer.Serialize(data, new JsonSerializerOptions { WriteIndented = true });
                AppendToLogFile(_crashLogPath, json + Environment.NewLine);
                Logger.Error($"Crash logged: {json}");
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to log crash: {ex.Message}");
            }
        }

        private async Task SendCrashReportAsync(object data)
        {
            if (!IsValidEndpoint(_settings.CrashReportingEndpoint))
            {
                Logger.Warn("Invalid endpoint URL for crash reporting");
                return;
            }

            try
            {
                var json = JsonSerializer.Serialize(data);
                var content = new StringContent(json, Encoding.UTF8, "application/json");
                using var response = await _httpClient.PostAsync(_settings.CrashReportingEndpoint, content);
                if (response.IsSuccessStatusCode)
                {
                    Logger.Info("Crash report sent successfully");
                }
                else
                {
                    Logger.Warn($"Failed to send crash report: {response.StatusCode}");
                }
            }
            catch (Exception ex)
            {
                Logger.Error($"Error sending crash report: {ex.Message}");
            }
        }

        public void OnNormalExit()
        {
            try
            {
                if (File.Exists(_crashDataPath))
                {
                    File.Delete(_crashDataPath);
                }
            }
            catch
            {
                // Ignore
            }
        }

        private string GetLocalIpAddress()
        {
            try
            {
                foreach (var ni in NetworkInterface.GetAllNetworkInterfaces())
                {
                    if (ni.OperationalStatus == OperationalStatus.Up)
                    {
                        foreach (var ip in ni.GetIPProperties().UnicastAddresses)
                        {
                            if (ip.Address.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork)
                            {
                                return ip.Address.ToString();
                            }
                        }
                    }
                }
            }
            catch
            {
                // Ignore
            }
            return "unknown";
        }

        private object GetSystemSpecs()
        {
            return new
            {
                OS = Environment.OSVersion.ToString(),
                ProcessorCount = Environment.ProcessorCount,
                MachineName = Environment.MachineName,
                UserName = Environment.UserName
            };
        }

        private string GetFullLogDump()
        {
            try
            {
                if (File.Exists(_crashLogPath))
                {
                    return File.ReadAllText(_crashLogPath);
                }
            }
            catch
            {
                // Ignore
            }
            return "No previous logs";
        }

        /// <summary>
        /// Tracks an analytics event.
        /// </summary>
        public void TrackEvent(string eventName, object? data = null)
        {
            var eventData = new
            {
                Timestamp = DateTime.UtcNow.ToString("O"),
                PcName = Environment.MachineName,
                Ip = GetLocalIpAddress(),
                Event = eventName,
                Data = data,
                Platform = "windows"
            };

            try
            {
                var json = JsonSerializer.Serialize(eventData);
                AppendToLogFile(_analyticsLogPath, json + Environment.NewLine);
                if (_settings.CrashReportingEnabled && IsValidEndpoint(_settings.CrashReportingEndpoint))
                {
                    _ = SendAnalyticsAsync(eventData); // Fire and forget
                }
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to track event: {ex.Message}");
            }
        }

        private async Task SendAnalyticsAsync(object data)
        {
            if (!IsValidEndpoint(_settings.CrashReportingEndpoint))
            {
                Logger.Warn("Invalid endpoint URL for analytics");
                return;
            }

            try
            {
                var json = JsonSerializer.Serialize(data);
                var content = new StringContent(json, Encoding.UTF8, "application/json");
                using var response = await _httpClient.PostAsync(_settings.CrashReportingEndpoint, content);
                if (!response.IsSuccessStatusCode)
                {
                    Logger.Warn($"Failed to send analytics: {response.StatusCode}");
                }
            }
            catch (Exception ex)
            {
                Logger.Error($"Error sending analytics: {ex.Message}");
            }
        }

        private void AppendToLogFile(string filePath, string content)
        {
            try
            {
                var fileInfo = new FileInfo(filePath);
                if (fileInfo.Exists && fileInfo.Length > MaxLogSize)
                {
                    // Rotate log: archive old log and start fresh to avoid memory issues
                    var archivePath = $"{filePath}.{DateTime.UtcNow:yyyyMMddHHmmss}.old";
                    File.Move(filePath, archivePath);

                    // Optional: clean up old archives (keep only last 3)
                    try
                    {
                        var directory = Path.GetDirectoryName(filePath);
                        if (directory != null)
                        {
                            var archives = Directory.GetFiles(directory, $"{Path.GetFileName(filePath)}.*.old")
                                .OrderByDescending(f => f)
                                .Skip(3)
                                .ToArray();
                            foreach (var archive in archives)
                            {
                                File.Delete(archive);
                            }
                        }
                    }
                    catch
                    {
                        // Ignore archive cleanup errors
                    }
                }
                File.AppendAllText(filePath, content);
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to append to log file: {ex.Message}");
            }
        }

        private bool IsValidEndpoint(string url)
        {
            if (string.IsNullOrWhiteSpace(url) || !Uri.TryCreate(url, UriKind.Absolute, out var uri))
                return false;

            // Require HTTPS only for security
            if (uri.Scheme != Uri.UriSchemeHttps)
                return false;

            // Block localhost and loopback
            if (uri.Host == "localhost" || uri.Host == "127.0.0.1" || uri.Host == "::1" || uri.Host == "0.0.0.0")
                return false;

            // Block private IP ranges (RFC 1918)
            if (uri.Host.StartsWith("10.") ||
                uri.Host.StartsWith("192.168.") ||
                uri.Host.StartsWith("172.16.") || uri.Host.StartsWith("172.17.") ||
                uri.Host.StartsWith("172.18.") || uri.Host.StartsWith("172.19.") ||
                uri.Host.StartsWith("172.20.") || uri.Host.StartsWith("172.21.") ||
                uri.Host.StartsWith("172.22.") || uri.Host.StartsWith("172.23.") ||
                uri.Host.StartsWith("172.24.") || uri.Host.StartsWith("172.25.") ||
                uri.Host.StartsWith("172.26.") || uri.Host.StartsWith("172.27.") ||
                uri.Host.StartsWith("172.28.") || uri.Host.StartsWith("172.29.") ||
                uri.Host.StartsWith("172.30.") || uri.Host.StartsWith("172.31."))
                return false;

            return true;
        }

        public static async Task RunMonitorAsync(int pid, AppSettings settings)
        {
            try
            {
                var process = Process.GetProcessById(pid);
                process.WaitForExit();

                if (process.ExitCode != 0)
                {
                    var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                    var crashDataPath = Path.Combine(appData, "Talkies", "crash_data.json");

                    if (File.Exists(crashDataPath))
                    {
                        var json = File.ReadAllText(crashDataPath);
                        var crashData = JsonSerializer.Deserialize<object>(json);

                        if (settings.CrashReportingEnabled && !string.IsNullOrEmpty(settings.CrashReportingEndpoint))
                        {
                            using var httpClient = new HttpClient();
                            var content = new StringContent(json, Encoding.UTF8, "application/json");
                            var response = await httpClient.PostAsync(settings.CrashReportingEndpoint, content);
                            if (response.IsSuccessStatusCode)
                            {
                                Logger.Info("Crash report sent by monitor");
                            }
                            else
                            {
                                Logger.Warn($"Monitor failed to send crash report: {response.StatusCode}");
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Logger.Error($"Monitor error: {ex.Message}");
            }
        }
    }
}