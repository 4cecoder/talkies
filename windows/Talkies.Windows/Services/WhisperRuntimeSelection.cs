using System.Collections.Generic;
using System.Linq;
using Whisper.net.LibraryLoader;

namespace Talkies.Windows.Services
{
    /// <summary>
    /// Configures Whisper.net's supported automatic GPU-to-CPU runtime order.
    /// </summary>
    public static class WhisperRuntimeSelection
    {
        private static readonly RuntimeLibrary[] preferredLibraries =
        {
            RuntimeLibrary.Cuda,
            RuntimeLibrary.Cuda12,
            RuntimeLibrary.Vulkan,
            RuntimeLibrary.Cpu,
            RuntimeLibrary.CpuNoAvx
        };

        /// <summary>
        /// Gets the supported runtime order used by Talkies. Whisper.net still
        /// checks whether a runtime is compatible before loading it.
        /// </summary>
        public static IReadOnlyList<RuntimeLibrary> PreferredLibraries => preferredLibraries;

        /// <summary>
        /// Sets Whisper.net's runtime order before its first factory is created.
        /// </summary>
        public static void ConfigureAutomaticFallback()
        {
            RuntimeOptions.RuntimeLibraryOrder = preferredLibraries.ToList();
        }

        /// <summary>
        /// Returns a label for the runtime Whisper.net actually loaded.
        /// </summary>
        public static string GetDisplayName(RuntimeLibrary? runtime) => runtime switch
        {
            RuntimeLibrary.Cuda => "GPU (CUDA 13)",
            RuntimeLibrary.Cuda12 => "GPU (CUDA 12)",
            RuntimeLibrary.Vulkan => "GPU (Vulkan)",
            RuntimeLibrary.Cpu => "CPU",
            RuntimeLibrary.CpuNoAvx => "CPU (compatibility)",
            _ => "Whisper runtime"
        };
    }
}
