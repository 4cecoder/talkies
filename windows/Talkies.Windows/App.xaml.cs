using System;
using System.Windows;
using WpfApplication = System.Windows.Application;
using Talkies.Windows.Services;

namespace Talkies.Windows
{
    public partial class App : WpfApplication
    {
        private CrashReporter? _crashReporter;

        protected override void OnStartup(System.Windows.StartupEventArgs e)
        {
            base.OnStartup(e);
            _crashReporter = new CrashReporter();
        }

        protected override void OnExit(System.Windows.ExitEventArgs e)
        {
            _crashReporter?.Dispose();
            base.OnExit(e);
            Environment.ExitCode = 0;
        }
    }
}
