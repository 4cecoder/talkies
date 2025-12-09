using System;
using System.Runtime.InteropServices;
using System.Text;

namespace Talkies.Windows.Services
{
    /// <summary>
    /// Handles text injection into the active window.
    /// On Windows, this uses SendInput API with UNICODE flag for character-by-character insertion.
    /// Note: For some applications (like UWP), you may need to enable "Use the clipboard to paste" in Accessibility settings.
    /// </summary>
    public static class TextInjector
    {
        /// <summary>
        /// Inserts text character by character into the active window.
        /// </summary>
        /// <param name="text">The text to insert.</param>
        /// <param name="delayMs">Optional delay between characters in milliseconds (for slower injection).</param>
        /// <returns>True if successful, false otherwise.</returns>
        public static bool TryInsertText(string text, int delayMs = 0)
        {
            try
            {
                if (string.IsNullOrEmpty(text))
                {
                    return true;
                }

                // Check if we have focus on a valid window
                var foregroundWindow = GetForegroundWindow();
                if (foregroundWindow == IntPtr.Zero)
                {
                    Logger.Error("TextInjector: No foreground window found. Cannot inject text.");
                    return false;
                }

                Logger.Info($"TextInjector: Injecting {text.Length} characters into active window");

                foreach (var ch in text)
                {
                    if (!SendChar(ch))
                    {
                        Logger.Error($"TextInjector: Failed to send character '{ch}' (U+{(int)ch:X4})");
                        return false;
                    }

                    if (delayMs > 0)
                    {
                        System.Threading.Thread.Sleep(delayMs);
                    }
                }

                Logger.Info("TextInjector: Text injection completed successfully");
                return true;
            }
            catch (Exception ex)
            {
                Logger.Error($"TextInjector: Exception during text injection: {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// Inserts text into the active window (throws on error).
        /// </summary>
        public static void InsertText(string text)
        {
            if (!TryInsertText(text))
            {
                throw new InvalidOperationException("Failed to insert text. Check logs for details.");
            }
        }

        /// <summary>
        /// Sends Ctrl+V to paste clipboard contents into the active window.
        /// </summary>
        public static bool PasteClipboard()
        {
            try
            {
                // Use keybd_event for reliability with modifiers
                keybd_event(Keys.ControlKey, 0, 0, UIntPtr.Zero);
                keybd_event(Keys.V, 0, 0, UIntPtr.Zero);
                keybd_event(Keys.V, 0, KEYEVENTF.KEYUP, UIntPtr.Zero);
                keybd_event(Keys.ControlKey, 0, KEYEVENTF.KEYUP, UIntPtr.Zero);
                return true;
            }
            catch (Exception ex)
            {
                Logger.Error($"TextInjector: Exception sending Ctrl+V: {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// Checks if text injection is likely to work by testing accessibility.
        /// Note: Full permission checks are OS-level and may require admin privileges on some systems.
        /// </summary>
        public static bool CanInjectText()
        {
            try
            {
                // Check if there's a foreground window
                var foregroundWindow = GetForegroundWindow();
                if (foregroundWindow == IntPtr.Zero)
                {
                    Logger.Warn("TextInjector: No foreground window available");
                    return false;
                }

                // Get window title to verify it's accessible
                var sb = new StringBuilder(256);
                if (GetWindowText(foregroundWindow, sb, sb.Capacity) == 0)
                {
                    Logger.Warn("TextInjector: Cannot read foreground window title");
                    return false;
                }

                Logger.Info($"TextInjector: Active window is '{sb}' - injection should work");
                return true;
            }
            catch (Exception ex)
            {
                Logger.Error($"TextInjector: Permission check failed: {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// Gets information about the current accessibility support.
        /// </summary>
        public static string GetAccessibilityInfo()
        {
            var sb = new StringBuilder();
            sb.AppendLine("TextInjector Accessibility Information:");
            sb.AppendLine($"- IsAdmin: {IsRunningAsAdmin()}");
            sb.AppendLine($"- CanInjectText: {CanInjectText()}");
            sb.AppendLine("- Method: Windows SendInput API (UNICODE flag)");
            sb.AppendLine("- Note: Some applications may require enabling 'Use the clipboard to paste' in Accessibility settings");

            return sb.ToString();
        }

        private static bool IsRunningAsAdmin()
        {
            try
            {
                var identity = System.Security.Principal.WindowsIdentity.GetCurrent();
                var principal = new System.Security.Principal.WindowsPrincipal(identity);
                return principal.IsInRole(System.Security.Principal.WindowsBuiltInRole.Administrator);
            }
            catch
            {
                return false;
            }
        }

        private static bool SendChar(char ch)
        {
            try
            {
                var inputs = new INPUT[2];

                // Key down
                inputs[0].type = 1; // INPUT_KEYBOARD
                inputs[0].U.ki.wVk = 0;
                inputs[0].U.ki.wScan = ch;
                inputs[0].U.ki.dwFlags = KEYEVENTF.UNICODE;
                inputs[0].U.ki.time = 0;
                inputs[0].U.ki.dwExtraInfo = IntPtr.Zero;

                // Key up
                inputs[1].type = 1;
                inputs[1].U.ki.wVk = 0;
                inputs[1].U.ki.wScan = ch;
                inputs[1].U.ki.dwFlags = KEYEVENTF.UNICODE | KEYEVENTF.KEYUP;
                inputs[1].U.ki.time = 0;
                inputs[1].U.ki.dwExtraInfo = IntPtr.Zero;

                var result = SendInput((uint)inputs.Length, inputs, Marshal.SizeOf(typeof(INPUT)));

                if (result == 0)
                {
                    var error = Marshal.GetLastWin32Error();
                    Logger.Warn($"TextInjector: SendInput returned 0 for '{ch}' (Error: {error})");
                    return false;
                }

                return true;
            }
            catch (Exception ex)
            {
                Logger.Error($"TextInjector: Exception in SendChar: {ex.Message}");
                return false;
            }
        }

        [DllImport("user32.dll", SetLastError = true)]
        private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        private static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

        private struct INPUT
        {
            public int type;
            public InputUnion U;
        }

        [StructLayout(LayoutKind.Explicit)]
        private struct InputUnion
        {
            [FieldOffset(0)] public KEYBDINPUT ki;
        }

        private struct KEYBDINPUT
        {
            public ushort wVk;
            public ushort wScan;
            public uint dwFlags;
            public uint time;
            public IntPtr dwExtraInfo;
        }

        private static class KEYEVENTF
        {
            public const uint KEYUP = 0x0002;
            public const uint UNICODE = 0x0004;
            public const uint SCANCODE = 0x0008;
        }

        private static class Keys
        {
            public const byte ControlKey = 0x11;
            public const byte V = 0x56;
        }

        [DllImport("user32.dll", SetLastError = true)]
        private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    }
}
