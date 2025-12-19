using System.Windows;
using Talkies.Windows.Services;
using Talkies.Windows.ViewModels;

namespace Talkies.Windows.Views
{
    public partial class PluginsManagementWindow : Window
    {
        private readonly PluginsManagementViewModel _viewModel;

        public PluginsManagementWindow()
        {
            InitializeComponent();
            // Create shared SettingsService at the composition root to prevent state conflicts
            var settingsService = new SettingsService();
            _viewModel = new PluginsManagementViewModel(Close, settingsService);
            DataContext = _viewModel;
        }
    }
}
