using System;
using System.Linq;
using System.Management;

namespace Talkies.Windows.Services
{
    public enum GpuType
    {
        None,
        Nvidia,
        Amd,
        Intel
    }

    public static class GpuDetector
    {
        public static GpuType DetectPrimaryGpu()
        {
            try
            {
                using var searcher = new ManagementObjectSearcher("select Name from Win32_VideoController");
                var gpuNames = searcher.Get()
                    .Cast<ManagementObject>()
                    .Select(obj => obj["Name"]?.ToString())
                    .Where(name => !string.IsNullOrWhiteSpace(name))
                    .ToList();

                foreach (var name in gpuNames)
                {
                    if (name != null && name.IndexOf("NVIDIA", StringComparison.OrdinalIgnoreCase) >= 0)
                        return GpuType.Nvidia;
                    if (name != null && (name.IndexOf("AMD", StringComparison.OrdinalIgnoreCase) >= 0 || name.IndexOf("Radeon", StringComparison.OrdinalIgnoreCase) >= 0))
                        return GpuType.Amd;
                    if (name != null && name.IndexOf("Intel", StringComparison.OrdinalIgnoreCase) >= 0)
                        return GpuType.Intel;
                }
            }
            catch (Exception ex)
            {
                Logger.Warn($"GPU detection failed: {ex.Message}");
            }
            return GpuType.None;
        }

        public static string GetGpuName()
        {
            try
            {
                using var searcher = new ManagementObjectSearcher("select Name from Win32_VideoController");
                var gpuName = searcher.Get()
                    .Cast<ManagementObject>()
                    .Select(obj => obj["Name"]?.ToString())
                    .FirstOrDefault(name => !string.IsNullOrWhiteSpace(name));
                return gpuName ?? "Unknown";
            }
            catch
            {
                return "Unknown";
            }
        }

        public static bool IsDirectMlAvailable()
        {
            try
            {
                var gpuType = DetectPrimaryGpu();
                return gpuType == GpuType.Nvidia || gpuType == GpuType.Amd || gpuType == GpuType.Intel;
            }
            catch
            {
                return false;
            }
        }
    }
}
