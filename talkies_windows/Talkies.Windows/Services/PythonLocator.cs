using System;
using System.IO;

namespace Talkies.Windows.Services
{
    internal static class PythonLocator
    {
        public static string ResolvePython()
        {
            // Prefer local venv to ensure sounddevice/faster-whisper are available
            var baseDir = AppDomain.CurrentDomain.BaseDirectory;

            // Try env var override first
            var envPython = Environment.GetEnvironmentVariable("TALKIES_PYTHON");
            if (!string.IsNullOrWhiteSpace(envPython) && File.Exists(envPython))
            {
                return envPython!;
            }

            // Check .venv relative to repo root (bin is typically 3 levels under talkies_windows/Talkies.Windows/bin/Debug/...)
            var probe = new[]
            {
                Path.Combine(baseDir, @"..\..\", @".venv", "Scripts", "python.exe"),
                Path.Combine(baseDir, @"..\", @".venv", "Scripts", "python.exe"),
                Path.Combine(baseDir, @".venv", "Scripts", "python.exe")
            };
            foreach (var candidate in probe)
            {
                if (File.Exists(candidate))
                {
                    return Path.GetFullPath(candidate);
                }
            }

            // Fallback to PATH
            return "python";
        }
    }
}
