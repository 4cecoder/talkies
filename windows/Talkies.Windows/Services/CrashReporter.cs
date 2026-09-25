using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;

namespace Talkies.Windows.Services
{
    /// <summary>
    /// Writes crash diagnostics to bounded local files without sending data over the network.
    /// </summary>
    public sealed class CrashReporter : IDisposable
    {
        private const long MaxLogSize = 5 * 1024 * 1024;
        private readonly string _crashLogPath;
        private bool _disposed;

        /// <summary>
        /// Creates a local crash logger under the current user's local application data directory.
        /// </summary>
        public CrashReporter()
        {
            var logDirectory = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Talkies",
                "logs");
            Directory.CreateDirectory(logDirectory);
            _crashLogPath = Path.Combine(logDirectory, "crash.log");

            AppDomain.CurrentDomain.UnhandledException += OnUnhandledException;
            TaskScheduler.UnobservedTaskException += OnUnobservedTaskException;
        }

        private void OnUnhandledException(object sender, UnhandledExceptionEventArgs args)
        {
            var exception = args.ExceptionObject as Exception;
            WriteCrash("Unhandled exception", exception?.ToString() ?? "Unknown exception", args.IsTerminating);
        }

        private void OnUnobservedTaskException(object? sender, UnobservedTaskExceptionEventArgs args)
        {
            WriteCrash("Unobserved task exception", args.Exception.ToString(), isTerminating: false);
            args.SetObserved();
        }

        private void WriteCrash(string kind, string details, bool isTerminating)
        {
            var report = $"[{DateTimeOffset.UtcNow:O}] {kind}; terminating={isTerminating}{Environment.NewLine}{details}{Environment.NewLine}{Environment.NewLine}";
            try
            {
                RotateLogIfNeeded();
                File.AppendAllText(_crashLogPath, report);
            }
            catch (Exception exception)
            {
                Debug.WriteLine($"Could not write the local Talkies crash log: {exception.Message}");
            }
        }

        private void RotateLogIfNeeded()
        {
            if (!File.Exists(_crashLogPath) || new FileInfo(_crashLogPath).Length < MaxLogSize)
            {
                return;
            }

            var firstArchive = $"{_crashLogPath}.1";
            var secondArchive = $"{_crashLogPath}.2";
            if (File.Exists(secondArchive))
            {
                File.Delete(secondArchive);
            }

            if (File.Exists(firstArchive))
            {
                File.Move(firstArchive, secondArchive);
            }

            File.Move(_crashLogPath, firstArchive);
        }

        /// <summary>
        /// Unsubscribes process-wide handlers when the application exits normally.
        /// </summary>
        public void Dispose()
        {
            if (_disposed)
            {
                return;
            }

            AppDomain.CurrentDomain.UnhandledException -= OnUnhandledException;
            TaskScheduler.UnobservedTaskException -= OnUnobservedTaskException;
            _disposed = true;
        }
    }
}
