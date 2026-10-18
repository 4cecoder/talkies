using System.ComponentModel;
using System.Windows;
using Talkies.Windows.ViewModels;

namespace Talkies.Windows.Views
{
    public partial class HistoryWindow : Window
    {
        private readonly HistoryViewModel _viewModel;

        public HistoryWindow(HistoryViewModel viewModel)
        {
            InitializeComponent();
            _viewModel = viewModel;
            DataContext = _viewModel;
            Icon = System.Windows.Application.Current?.MainWindow?.Icon;
            _viewModel.PropertyChanged += OnViewModelPropertyChanged;
            Loaded += (_, _) => SearchBox.Focus();
            Closed += (_, _) =>
            {
                _viewModel.PropertyChanged -= OnViewModelPropertyChanged;
                _viewModel.Dispose();
            };
        }

        private void OnViewModelPropertyChanged(object? sender, PropertyChangedEventArgs e)
        {
            // A new page or search result starts at the top of the list.
            if (e.PropertyName == nameof(HistoryViewModel.PageLabel)) ResultsScroller.ScrollToTop();
        }

        private void Close_Click(object sender, RoutedEventArgs e) => Close();
    }
}
