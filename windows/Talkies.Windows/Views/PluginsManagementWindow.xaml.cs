using System.Windows;
using Talkies.Windows.ViewModels;

namespace Talkies.Windows.Views
{
    public partial class PluginsManagementWindow : Window
    {
        private readonly PluginsManagementViewModel _viewModel;

        public PluginsManagementWindow()
        {
            InitializeComponent();
            _viewModel = new PluginsManagementViewModel(Close);
            DataContext = _viewModel;
        }
    }
}
