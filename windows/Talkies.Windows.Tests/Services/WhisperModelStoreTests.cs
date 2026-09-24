using System.IO;
using Talkies.Windows.Services;
using Xunit;

namespace Talkies.Windows.Tests.Services;

public sealed class WhisperModelStoreTests
{
    [Fact]
    public void ModelCatalogUsesStablePinnedFilenames()
    {
        var store = new WhisperModelStore("test-models");

        Assert.Equal(Path.Combine("test-models", "ggml-tiny.bin"), store.GetModelPath("tiny"));
        Assert.Equal(Path.Combine("test-models", "ggml-base.bin"), store.GetModelPath("base"));
        Assert.Equal(Path.Combine("test-models", "ggml-large-v3.bin"), store.GetModelPath("large"));
    }

    [Fact]
    public void UnknownModelNamesAreRejectedInsteadOfSilentlyUsingAnotherModel()
    {
        var store = new WhisperModelStore("test-models");

        Assert.Throws<System.ArgumentOutOfRangeException>(() => store.GetModelPath("unknown"));
    }
}
