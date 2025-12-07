using System.Windows;
using Talkies.Windows.ViewModels;

namespace Talkies.Windows
{
    public partial class MainWindow : Window
    {
        private readonly MainViewModel _vm;

        public MainWindow()
        {
            InitializeComponent();
            _vm = new MainViewModel();
            DataContext = _vm;

            // Bind audio level to waveform visualizer
            _vm.OnAudioLevelChanged += (level) =>
            {
                Dispatcher.InvokeAsync(() => WaveformVisualizer.AudioLevel = level);
            };

            Loaded += (_, _) => _vm.StartHotkey();
            Closed += (_, _) => _vm.Dispose();
        }
    }
}
