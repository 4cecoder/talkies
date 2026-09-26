using Talkies.Windows.Services;
using Whisper.net.LibraryLoader;
using Xunit;

namespace Talkies.Windows.Tests.Services;

public sealed class WhisperRuntimeSelectionTests
{
    [Fact]
    public void AutomaticRuntimeOrderPrefersCudaThenVulkanAndKeepsCpuFallbacks()
    {
        Assert.Equal(
            new[]
            {
                RuntimeLibrary.Cuda,
                RuntimeLibrary.Cuda12,
                RuntimeLibrary.Vulkan,
                RuntimeLibrary.Cpu,
                RuntimeLibrary.CpuNoAvx
            },
            WhisperRuntimeSelection.PreferredLibraries);

        WhisperRuntimeSelection.ConfigureAutomaticFallback();

        Assert.Equal(WhisperRuntimeSelection.PreferredLibraries, RuntimeOptions.RuntimeLibraryOrder);
    }

    [Theory]
    [InlineData(RuntimeLibrary.Cuda, "GPU (CUDA 13)")]
    [InlineData(RuntimeLibrary.Cuda12, "GPU (CUDA 12)")]
    [InlineData(RuntimeLibrary.Vulkan, "GPU (Vulkan)")]
    [InlineData(RuntimeLibrary.Cpu, "CPU")]
    [InlineData(RuntimeLibrary.CpuNoAvx, "CPU (compatibility)")]
    public void BackendLabelDescribesWhisperNetLoadedRuntime(RuntimeLibrary runtime, string expected)
    {
        Assert.Equal(expected, WhisperRuntimeSelection.GetDisplayName(runtime));
    }

    [Fact]
    public void UnknownRuntimeHasNeutralLabel()
    {
        Assert.Equal("Whisper runtime", WhisperRuntimeSelection.GetDisplayName(null));
    }
}
