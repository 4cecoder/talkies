using System;
using System.IO;
using System.Text;

namespace Talkies.Windows.Services
{
    internal static class Logger
    {
        private static readonly object Sync = new();
        private static readonly string LogPath =
            Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "talkies_win.log");

        public static void Info(string message) => Write("INFO", message);
        public static void Error(string message) => Write("ERROR", message);

        private static void Write(string level, string message)
        {
            var line = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff} [{level}] {message}";
            lock (Sync)
            {
                File.AppendAllText(LogPath, line + Environment.NewLine, Encoding.UTF8);
            }
            Console.WriteLine(line);
        }
    }
}
