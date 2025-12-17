using System;
using System.Diagnostics;
using WpfApplication = System.Windows.Application;
using Talkies.Windows.Services;
using Talkies.Windows.Models;

namespace Talkies.Windows
{
    public partial class App : WpfApplication
    {
        private CrashReporter? _crashReporter;
        private SettingsService? _settingsService;

        [STAThread]
        public static void Main()
        {
            var args = Environment.GetCommandLineArgs();
            if (args.Length > 1 && args[1] == "monitor" && int.TryParse(args[2], out int pid))
            {
                var settingsService = new SettingsService();
                var settings = settingsService.Load();
                CrashReporter.RunMonitorAsync(pid, settings).Wait();
                return;
            }

            var app = new App();
            app.Run();
        }

        protected override void OnStartup(System.Windows.StartupEventArgs e)
        {
            base.OnStartup(e);
            _settingsService = new SettingsService();
            var settings = _settingsService.Load();
            _crashReporter = new CrashReporter(settings);
        }

        protected override void OnExit(System.Windows.ExitEventArgs e)
        {
            _crashReporter?.OnNormalExit();
            base.OnExit(e);
            Environment.ExitCode = 0;
        }
    }
}
