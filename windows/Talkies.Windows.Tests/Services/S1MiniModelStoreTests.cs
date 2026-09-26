using System;
using System.IO;
using Talkies.Windows.Services;
using Xunit;

namespace Talkies.Windows.Tests.Services;

public sealed class S1MiniModelStoreTests
{
    [Fact]
    public void IsNonEmptyArtifact_RejectsMissingAndEmptyFiles()
    {
        var directory = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(directory);
        try
        {
            var missingPath = Path.Combine(directory, "missing.LICENSE");
            var emptyPath = Path.Combine(directory, "empty.NOTICE");
            var populatedPath = Path.Combine(directory, "valid.NOTICE");
            File.WriteAllBytes(emptyPath, Array.Empty<byte>());
            File.WriteAllText(populatedPath, "required attribution");

            Assert.False(S1MiniModelStore.IsNonEmptyArtifact(missingPath));
            Assert.False(S1MiniModelStore.IsNonEmptyArtifact(emptyPath));
            Assert.True(S1MiniModelStore.IsNonEmptyArtifact(populatedPath));
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }
}
