using System;
using System.Diagnostics;
using System.IO;
using System.Windows;
using WpfApplication = System.Windows.Application;
using Talkies.Windows.Services;
using Talkies.Windows.Models;

namespace Talkies.Windows
{
    public partial class App : WpfApplication
    {
        private CrashReporter? _crashReporter;
        private SettingsService? _settingsService;

        protected override void OnStartup(System.Windows.StartupEventArgs e)
        {
            base.OnStartup(e);
            _settingsService = new SettingsService();
            var settings = _settingsService.Load();

            // One-time privacy consent on first launch
            if (!settings.CrashReportingPrivacyAccepted)
            {
                var privacyPolicy = File.ReadAllText("Resources/PrivacyPolicy.md");
                var result = MessageBox.Show(
                    $"{privacyPolicy}\n\nDo you consent to submit crash reports and analytics to help improve the application?",
                    "Privacy Consent",
                    MessageBoxButton.YesNo,
                    MessageBoxImage.Question);

                settings.CrashReportingPrivacyAccepted = result == MessageBoxResult.Yes;
                if (settings.CrashReportingPrivacyAccepted)
                {
                    settings.CrashReportingEnabled = true; // Enable by default after consent
                }
                _settingsService.Save(settings);
            }

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
