using System.Windows;
using Talkies.Windows.Services;
using WpfApplication = System.Windows.Application;

namespace Talkies.Windows
{
    public partial class App : WpfApplication
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);

            // Load settings and apply theme
            var settingsService = new SettingsService();
            var settings = settingsService.Load();

            // Apply theme based on user setting (which may be "System" for auto-detection)
            DarkModeService.ApplyThemeSetting(settings.Theme);
        }
    }
}
