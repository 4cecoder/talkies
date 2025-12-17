using System;
using System.Diagnostics;
using System.Linq;
using System.Security;
using System.Windows;
using Microsoft.Win32;

namespace Talkies.Windows.Services
{
    /// <summary>
    /// Service for managing application theme (dark/light) with system theme detection support.
    /// </summary>
    public class DarkModeService
    {
        private const string RegistryKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize";
        private const string RegistryValueName = "AppsUseLightTheme";

        /// <summary>
        /// Detects if the Windows system theme is set to dark mode.
        /// </summary>
        /// <returns>True if system is set to dark theme, false otherwise or if detection fails.</returns>
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
                // Registry value: 0 = Dark, 1 = Light
                return registryValue == 0;
            }
            catch (UnauthorizedAccessException ex)
            {
                Debug.WriteLine($"DarkModeService: Access denied reading system theme: {ex.Message}");
                return false;
            }
            catch (SecurityException ex)
            {
                Debug.WriteLine($"DarkModeService: Security exception reading system theme: {ex.Message}");
                return false;
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"DarkModeService: Unexpected error reading system theme: {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// Applies a theme setting (which may be "System") by resolving and applying the actual theme.
        /// </summary>
        /// <param name="themeSetting">Theme setting: "Dark", "Light", or "System" (will auto-detect system theme).</param>
        public static void ApplyThemeSetting(string? themeSetting)
        {
            string themeToApply = themeSetting?.Equals("System", StringComparison.OrdinalIgnoreCase) == true
                ? GetSystemTheme()
                : (themeSetting ?? "Light");

            ApplyTheme(themeToApply);
        }

        /// <summary>
        /// Applies the specified theme to the application by loading the appropriate resource dictionary.
        /// </summary>
        /// <param name="themeSetting">Actual theme name: "Dark" or "Light" (not "System").</param>
        public static void ApplyTheme(string? themeSetting)
        {
            var app = System.Windows.Application.Current;
            if (app == null)
            {
                Debug.WriteLine("DarkModeService: Application.Current is null, cannot apply theme.");
                return;
            }

            // Validate and normalize theme setting
            if (string.IsNullOrWhiteSpace(themeSetting))
            {
                themeSetting = "Light";
            }

            // Validate resolved theme
            if (!IsValidTheme(themeSetting))
            {
                Debug.WriteLine($"DarkModeService: Invalid theme '{themeSetting}', falling back to 'Light'.");
                themeSetting = "Light";
            }

            try
            {
                // Remove existing theme dictionaries (more specific matching to avoid accidental removal)
                var themeDict = app.Resources.MergedDictionaries
                    .FirstOrDefault(d =>
                        d.Source?.OriginalString.EndsWith("DarkTheme.xaml", StringComparison.OrdinalIgnoreCase) == true ||
                        d.Source?.OriginalString.EndsWith("LightTheme.xaml", StringComparison.OrdinalIgnoreCase) == true);

                if (themeDict != null)
                {
                    app.Resources.MergedDictionaries.Remove(themeDict);
                }

                // Create new theme dictionary with the appropriate theme
                var themeFileName = themeSetting.Equals("Dark", StringComparison.OrdinalIgnoreCase)
                    ? "Themes/DarkTheme.xaml"
                    : "Themes/LightTheme.xaml";

                var themeUri = new Uri(themeFileName, UriKind.Relative);
                var newThemeDict = new ResourceDictionary { Source = themeUri };

                app.Resources.MergedDictionaries.Add(newThemeDict);
                Debug.WriteLine($"DarkModeService: Applied theme '{themeSetting}'.");
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"DarkModeService: Error applying theme '{themeSetting}': {ex.Message}");
            }
        }

        /// <summary>
        /// Gets the current system theme based on Windows personalization settings.
        /// </summary>
        /// <returns>"Dark" if system is in dark mode, "Light" otherwise.</returns>
        public static string GetSystemTheme()
        {
            return IsSystemDarkMode() ? "Dark" : "Light";
        }

        /// <summary>
        /// Validates if the provided theme name is a recognized theme.
        /// </summary>
        /// <param name="theme">Theme name to validate.</param>
        /// <returns>True if theme is "Dark" or "Light" (case-insensitive), false otherwise.</returns>
        private static bool IsValidTheme(string? theme)
        {
            return !string.IsNullOrWhiteSpace(theme) &&
                   (theme.Equals("Dark", StringComparison.OrdinalIgnoreCase) ||
                    theme.Equals("Light", StringComparison.OrdinalIgnoreCase));
        }
    }
}
