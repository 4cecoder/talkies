using System;
using System.IO;
using System.Linq;
using System.Management;
using System.Runtime.InteropServices;
using System.Collections.Generic;

namespace Talkies.Windows.Services
{
    public static class CudaDetector
    {
        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        private static extern IntPtr LoadLibrary(string lpFileName);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool FreeLibrary(IntPtr hModule);

        public static bool IsNvidiaCudaAvailable(out string reason)
        {
            reason = string.Empty;
            try
            {
                var gpus = GetGpuNames();
                var nvidiaGpu = gpus.FirstOrDefault(name => name.IndexOf("NVIDIA", StringComparison.OrdinalIgnoreCase) >= 0);
                if (nvidiaGpu == null)
                {
                    reason = $"No NVIDIA GPU detected. Found: {string.Join(", ", gpus)}";
                    return false;
                }

                var candidates = new[]
                {
                    Path.Combine(Environment.SystemDirectory, "nvcuda.dll"), // System32 for 64-bit
                    Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.SystemX86), "nvcuda.dll"), // SysWOW64 for 32-bit proc
                    "nvcuda.dll"
                };

                var foundPath = candidates.FirstOrDefault(File.Exists);
                if (string.IsNullOrEmpty(foundPath))
                {
                    reason = "NVIDIA driver/CUDA runtime not found (nvcuda.dll missing). Install the latest NVIDIA Game Ready or Studio driver.";
                    return false;
                }

                if (!TryLoadDll(foundPath))
                {
                    reason = $"CUDA runtime found at {foundPath} but could not be loaded. Ensure matching 64-bit driver and reboot if newly installed.";
                    return false;
                }

                reason = $"Detected GPU: {nvidiaGpu}; CUDA runtime: {foundPath}";
                return true;
            }
            catch (Exception ex)
            {
                reason = $"GPU detection failed: {ex.Message}";
                return false;
            }
        }

        private static List<string> GetGpuNames()
        {
            var names = new List<string>();
            try
            {
                using var searcher = new ManagementObjectSearcher("select Name from Win32_VideoController");
                foreach (var obj in searcher.Get().Cast<ManagementObject>())
                {
                    var name = obj["Name"]?.ToString() ?? string.Empty;
                    if (!string.IsNullOrWhiteSpace(name))
                    {
                        names.Add(name);
                    }
                }
            }
            catch
            {
                // ignore and return what we have
            }
            return names;
        }

        private static bool TryLoadDll(string pathOrName)
        {
            var handle = LoadLibrary(pathOrName);
            if (handle == IntPtr.Zero) return false;
            FreeLibrary(handle);
            return true;
        }
    }
}
