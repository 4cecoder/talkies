using System;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;

namespace Talkies.Windows.Services
{
    public class HotkeyManager : IDisposable
    {
        private const int WH_KEYBOARD_LL = 13;
        private const int WM_KEYDOWN = 0x0100;
        private const int WM_KEYUP = 0x0101;
        private const int WM_SYSKEYDOWN = 0x0104;
        private const int WM_SYSKEYUP = 0x0105;
        private const int VK_RMENU = 0xA5; // Right Alt

        private IntPtr _hookId = IntPtr.Zero;
        private LowLevelKeyboardProc? _proc;
        private bool _isPressed;
        private bool _holdFired;
        private readonly TimeSpan _threshold = TimeSpan.FromMilliseconds(150);
        private CancellationTokenSource? _cts;

        public event Action? Tap;
        public event Action? HoldStart;
        public event Action? HoldEnd;

        public void Start()
        {
            if (_hookId != IntPtr.Zero) return;
            _proc = HookCallback;
            _hookId = SetHook(_proc);
            Logger.Info("HotkeyManager: hook registered for Right Alt (RMENU)");
        }

        public void Dispose()
        {
            if (_hookId != IntPtr.Zero)
            {
                UnhookWindowsHookEx(_hookId);
                _hookId = IntPtr.Zero;
            }
            _cts?.Cancel();
        }

        private IntPtr SetHook(LowLevelKeyboardProc proc)
        {
            using var curProcess = System.Diagnostics.Process.GetCurrentProcess();
            using var curModule = curProcess.MainModule!;
            return SetWindowsHookEx(WH_KEYBOARD_LL, proc,
                GetModuleHandle(curModule.ModuleName), 0);
        }

        private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
        {
            if (nCode >= 0)
            {
                int vkCode = Marshal.ReadInt32(lParam);
                if (vkCode == VK_RMENU)
                {
                    if (wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN)
                    {
                        Logger.Debug("HotkeyManager: Right Alt DOWN");
                        if (!_isPressed)
                        {
                            _isPressed = true;
                            _holdFired = false;
                            _cts?.Cancel();
                            _cts = new CancellationTokenSource();
                            var token = _cts.Token;
                            Task.Run(async () =>
                            {
                                try
                                {
                                    await Task.Delay(_threshold, token);
                                    if (!token.IsCancellationRequested && _isPressed)
                                    {
                                        _holdFired = true;
                                        Logger.Debug("HotkeyManager: HoldStart fired");
                                        HoldStart?.Invoke();
                                    }
                                }
                                catch (TaskCanceledException) { }
                            }, token);
                        }
                    }
                    else if (wParam == (IntPtr)WM_KEYUP || wParam == (IntPtr)WM_SYSKEYUP)
                    {
                        _cts?.Cancel();
                        if (_isPressed)
                        {
                            if (_holdFired)
                            {
                                Logger.Debug("HotkeyManager: HoldEnd fired");
                                HoldEnd?.Invoke();
                            }
                            else
                            {
                                Logger.Debug("HotkeyManager: Tap fired");
                                Tap?.Invoke();
                            }
                        }
                        else
                        {
                            Logger.Debug("HotkeyManager: Right Alt UP with no pressed flag");
                        }
                        _isPressed = false;
                        _holdFired = false;
                    }
                }
            }
            return CallNextHookEx(_hookId, nCode, wParam, lParam);
        }

        private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool UnhookWindowsHookEx(IntPtr hhk);

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr GetModuleHandle(string lpModuleName);
    }
}
