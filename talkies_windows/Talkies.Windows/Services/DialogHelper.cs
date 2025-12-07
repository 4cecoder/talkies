using System.Windows;

namespace Talkies.Windows.Services
{
    public static class DialogHelper
    {
        /// <summary>
        /// Shows an error message dialog.
        /// </summary>
        public static void ShowError(string title, string message)
        {
            MessageBox.Show(message, title, MessageBoxButton.OK, MessageBoxImage.Error);
        }

        /// <summary>
        /// Shows a warning message dialog.
        /// </summary>
        public static void ShowWarning(string title, string message)
        {
            MessageBox.Show(message, title, MessageBoxButton.OK, MessageBoxImage.Warning);
        }

        /// <summary>
        /// Shows an information message dialog.
        /// </summary>
        public static void ShowInfo(string title, string message)
        {
            MessageBox.Show(message, title, MessageBoxButton.OK, MessageBoxImage.Information);
        }

        /// <summary>
        /// Shows a confirmation dialog and returns whether the user clicked OK.
        /// </summary>
        public static bool ShowConfirmation(string title, string message)
        {
            var result = MessageBox.Show(message, title, MessageBoxButton.OKCancel, MessageBoxImage.Question);
            return result == MessageBoxResult.OK;
        }
    }
}
