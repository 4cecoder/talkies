using System;
using System.Runtime.InteropServices;
using System.Text;

namespace Talkies.Windows.Services
{
    public static class TextInjector
    {
        public static void InsertText(string text)
        {
            foreach (var ch in text)
            {
                SendChar(ch);
            }
        }

        private static void SendChar(char ch)
        {
            var inputs = new INPUT[2];
            inputs[0].type = 1; // INPUT_KEYBOARD
            inputs[0].U.ki.wVk = 0;
            inputs[0].U.ki.wScan = ch;
            inputs[0].U.ki.dwFlags = KEYEVENTF.UNICODE;

            inputs[1].type = 1;
            inputs[1].U.ki.wVk = 0;
            inputs[1].U.ki.wScan = ch;
            inputs[1].U.ki.dwFlags = KEYEVENTF.UNICODE | KEYEVENTF.KEYUP;

            SendInput((uint)inputs.Length, inputs, Marshal.SizeOf(typeof(INPUT)));
        }

        [DllImport("user32.dll", SetLastError = true)]
        private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

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
        }
    }
}
