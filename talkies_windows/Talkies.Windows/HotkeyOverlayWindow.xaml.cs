using System.Windows;

namespace Talkies.Windows
{
    public partial class HotkeyOverlayWindow : Window
    {
        public HotkeyOverlayWindow()
        {
            InitializeComponent();
        }

        public void SetMessage(string message)
        {
            MessageBlock.Text = message;
        }
    }
}
