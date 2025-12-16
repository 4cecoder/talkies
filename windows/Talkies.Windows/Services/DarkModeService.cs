using System;
using System.Linq;
using System.Windows;
using Microsoft.Win32;

namespace Talkies.Windows.Services
{
    public class DarkModeService
    {
        private const string RegistryKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize";
        private const string RegistryValueName = "AppsUseLightTheme";

        public static bool IsSystemDarkMode()
        {
            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(RegistryKeyPath);
                var registryValueObject = key?.GetValue(RegistryValueName);
                if (registryValueObject == null)
                {
                    return false;
                }

                var registryValue = (int)registryValueObject;
                return registryValue <= 0;
            }
            catch
            {
                return false;
            }
        }

        public static void ApplyTheme(string theme)
        {
            var app = Application.Current;
            if (app == null) return;

            // Remove existing theme dictionaries
            var themeDict = app.Resources.MergedDictionaries
                .FirstOrDefault(d => d.Source?.OriginalString.Contains("Theme") == true);
            if (themeDict != null)
            {
                app.Resources.MergedDictionaries.Remove(themeDict);
            }

            // Add new theme dictionary
            var themeUri = theme.ToLower() == "dark"
                ? new Uri("Themes/DarkTheme.xaml", UriKind.Relative)
                : new Uri("Themes/LightTheme.xaml", UriKind.Relative);

            app.Resources.MergedDictionaries.Add(new ResourceDictionary { Source = themeUri });
        }

        public static string GetSystemTheme()
        {
            return IsSystemDarkMode() ? "Dark" : "Light";
        }
    }
}
