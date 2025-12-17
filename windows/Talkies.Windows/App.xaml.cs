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

            ApplyTheme(settings.Theme);
        }

        private void ApplyTheme(string themeSetting)
        {
            string themeToApply;

            if (themeSetting == "System")
            {
                themeToApply = DarkModeService.GetSystemTheme();
            }
            else
            {
                themeToApply = themeSetting;
            }

            DarkModeService.ApplyTheme(themeToApply);
        }
    }
}
