using System.Windows;
using System.Windows.Controls;
using Forms = System.Windows.Forms;
using Talkies.Windows.ViewModels;
using Talkies.Windows.Services;
using System.ComponentModel;

namespace Talkies.Windows
{
    public partial class MainWindow : Window
    {
        private readonly MainViewModel _vm;
        private HotkeyOverlayWindow? _overlay;
        private Forms.NotifyIcon? _notifyIcon;
        private bool _exitRequested;

        public MainWindow()
        {
            InitializeComponent();
            _vm = new MainViewModel();
            DataContext = _vm;
            _vm.PropertyChanged += OnViewModelPropertyChanged;

            // Bind audio level to waveform visualizer
            _vm.OnAudioLevelChanged += (level) =>
            {
                Dispatcher.InvokeAsync(() => WaveformVisualizer.AudioLevel = level);
            };
            _vm.OnResetWaveform += () =>
            {
                Dispatcher.InvokeAsync(() => WaveformVisualizer.Clear());
            };

            _vm.OnOverlayShow += msg => Dispatcher.Invoke(() => ShowOverlay(msg));
            _vm.OnOverlayUpdate += msg => Dispatcher.Invoke(() => UpdateOverlay(msg));
            _vm.OnOverlayHide += () => Dispatcher.Invoke(HideOverlay);

            Loaded += (_, _) => _vm.StartHotkey();
            Loaded += (_, _) => InitTrayIcon();
            StateChanged += OnStateChanged;
            Closed += (_, _) => DisposeTray();

            // Add developer crash simulation button if enabled
            var settingsService = new SettingsService();
            var settings = settingsService.Load();
            if (settings.TalkiesTeamConfig.EnableSimulateCrashesModule)
            {
                SimulateCrashButton.Visibility = Visibility.Visible;
                SimulateCrashButton.Click += (s, e) => SimulateCrash();
            }
        }

        private void ShowOverlay(string message)
        {
            if (_overlay == null)
            {
                _overlay = new HotkeyOverlayWindow();
            }

            _overlay.SetMessage(message);
            PositionOverlay();
            _overlay.Opacity = 0;
            _overlay.Show();
            UiMotion.FadeIn(_overlay);
            _overlay.Activate();
        }

        private void UpdateOverlay(string message)
        {
            if (_overlay != null)
            {
                _overlay.SetMessage(message);
                PositionOverlay();
            }
        }

        private void HideOverlay()
        {
            if (_overlay != null)
            {
                if (SystemParameters.ClientAreaAnimation)
                {
                    var fade = new System.Windows.Media.Animation.DoubleAnimation(1, 0, TimeSpan.FromMilliseconds(150));
                    fade.Completed += (_, _) => _overlay?.Hide();
                    _overlay.BeginAnimation(UIElement.OpacityProperty, fade);
                    return;
                }

                _overlay.Opacity = 1;
                _overlay.Hide();
            }
        }

        private void OnTranscriptCardLoaded(object sender, RoutedEventArgs e)
        {
            if (sender is FrameworkElement element && element.IsVisible)
            {
                UiMotion.FadeIn(element, lift: 5);
            }
        }

        private void OnViewModelPropertyChanged(object? sender, PropertyChangedEventArgs e)
        {
            if (e.PropertyName != nameof(MainViewModel.IsRecording)) return;

            Dispatcher.InvokeAsync(() =>
            {
                var newlyEnabledButton = _vm.IsRecording ? StopRecordingButton : StartRecordingButton;
                UiMotion.Emphasize(newlyEnabledButton);
            });
        }

        private void PositionOverlay()
        {
            if (_overlay == null) return;
            var workArea = SystemParameters.WorkArea;
            _overlay.Left = workArea.Right - _overlay.Width - 24;
            _overlay.Top = workArea.Bottom - _overlay.Height - 24;
        }

        private void InitTrayIcon()
        {
            _notifyIcon = new Forms.NotifyIcon
            {
                Visible = true,
                Text = "Talkies",
                Icon = new System.Drawing.Icon(System.IO.Path.Combine(AppContext.BaseDirectory, "Resources", "talkies-app-icon.ico"))
            };

            var menu = new Forms.ContextMenuStrip();
            menu.Items.Add("Open", null, (_, __) => ShowFromTray());
            menu.Items.Add("Exit", null, (_, __) => ExitFromTray());
            _notifyIcon.ContextMenuStrip = menu;
            _notifyIcon.DoubleClick += (_, __) => ShowFromTray();
        }

        private void ShowFromTray()
        {
            Show();
            WindowState = WindowState.Normal;
            Activate();
        }

        private void ExitFromTray()
        {
            _exitRequested = true;
            _notifyIcon?.Dispose();
            System.Windows.Application.Current.Shutdown();
        }

        private void OnStateChanged(object? sender, EventArgs e)
        {
            if (_exitRequested) return;
            if (WindowState == WindowState.Minimized)
            {
                Hide();
            }
        }

        private void DisposeTray()
        {
            if (_notifyIcon != null)
            {
                _notifyIcon.Visible = false;
                _notifyIcon.Dispose();
            }
        }

        private void SimulateCrash()
        {
            // Simulate a crash by throwing an exception
            throw new InvalidOperationException("Simulated crash for testing crash reporting.");
        }
    }
}
