using System;
using System.IO;
using System.Text;

namespace Talkies.Windows.Services
{
    /// <summary>
    /// Logging service for the Talkies application.
    /// Logs messages to both console and a file with timestamps and severity levels.
    /// </summary>
    internal static class Logger
    {
        private static readonly object Sync = new();
        private static readonly string LogPath =
            Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "talkies_win.log");

        // Event for UI to subscribe to log messages
        public static event EventHandler<LogEventArgs>? LogMessage;

        /// <summary>
        /// Log levels for filtering and display.
        /// </summary>
        public enum LogLevel
        {
            Debug,
            Info,
            Warn,
            Error
        }

        /// <summary>
        /// Arguments passed to log subscribers.
        /// </summary>
        public class LogEventArgs : EventArgs
        {
            public LogLevel Level { get; set; }
            public string Message { get; set; } = string.Empty;
            public DateTime Timestamp { get; set; } = DateTime.Now;
        }

        /// <summary>
        /// Logs a debug message.
        /// </summary>
        public static void Debug(string message) => Write(LogLevel.Debug, message);

        /// <summary>
        /// Logs an informational message.
        /// </summary>
        public static void Info(string message) => Write(LogLevel.Info, message);

        /// <summary>
        /// Logs a warning message.
        /// </summary>
        public static void Warn(string message) => Write(LogLevel.Warn, message);

        /// <summary>
        /// Logs an error message.
        /// </summary>
        public static void Error(string message) => Write(LogLevel.Error, message);

        /// <summary>
        /// Logs a status message (alias for Info with user-friendly formatting).
        /// </summary>
        public static void Status(string message) => Write(LogLevel.Info, $"📌 {message}");

        /// <summary>
        /// Logs a success message.
        /// </summary>
        public static void Success(string message) => Write(LogLevel.Info, $"✅ {message}");

        /// <summary>
        /// Logs an operation starting.
        /// </summary>
        public static void OperationStart(string operationName) =>
            Write(LogLevel.Info, $"🚀 Starting: {operationName}");

        /// <summary>
        /// Logs an operation completing.
        /// </summary>
        public static void OperationComplete(string operationName) =>
            Write(LogLevel.Info, $"✓ Completed: {operationName}");

        /// <summary>
        /// Logs an operation failing.
        /// </summary>
        public static void OperationFailed(string operationName, string reason) =>
            Write(LogLevel.Error, $"✗ Failed: {operationName} - {reason}");

        private static void Write(LogLevel level, string message)
        {
            var levelName = level switch
            {
                LogLevel.Debug => "DEBUG",
                LogLevel.Info => "INFO",
                LogLevel.Warn => "WARN",
                LogLevel.Error => "ERROR",
                _ => "UNKNOWN"
            };

            var line = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff} [{levelName}] {message}";

            lock (Sync)
            {
                try
                {
                    File.AppendAllText(LogPath, line + Environment.NewLine, Encoding.UTF8);
                }
                catch
                {
                    // Ignore file write errors to avoid crashes
                }
            }

            // Write to console
            var originalColor = Console.ForegroundColor;
            try
            {
                Console.ForegroundColor = level switch
                {
                    LogLevel.Debug => ConsoleColor.Gray,
                    LogLevel.Info => ConsoleColor.White,
                    LogLevel.Warn => ConsoleColor.Yellow,
                    LogLevel.Error => ConsoleColor.Red,
                    _ => ConsoleColor.White
                };

                Console.WriteLine(line);
            }
            finally
            {
                Console.ForegroundColor = originalColor;
            }

            // Raise event for UI subscribers
            LogMessage?.Invoke(null, new LogEventArgs
            {
                Level = level,
                Message = message,
                Timestamp = DateTime.Now
            });
        }

        /// <summary>
        /// Clears the log file.
        /// </summary>
        public static void ClearLog()
        {
            lock (Sync)
            {
                try
                {
                    File.Delete(LogPath);
                }
                catch
                {
                    // Ignore errors
                }
            }
        }

        /// <summary>
        /// Gets the path to the log file.
        /// </summary>
        public static string GetLogPath() => LogPath;
    }
}
