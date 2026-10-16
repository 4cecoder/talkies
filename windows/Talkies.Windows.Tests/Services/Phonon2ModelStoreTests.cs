using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Talkies.Windows.Services;
using Xunit;

namespace Talkies.Windows.Tests.Services;

public sealed class Phonon2ModelStoreTests
{
    [Fact]
    public void DownloadUris_UseThePinnedRevision()
    {
        var uri = Phonon2ModelStore.GetDownloadUri(Phonon2ModelStore.ModelFileName);

        Assert.Equal(
            "https://huggingface.co/cstr/phonon2-GGUF/resolve/3ed3e6ad6e7ce63affffeede37328ff756efaa2f/phonon2-q8_0.gguf?download=true",
            uri.AbsoluteUri);
        Assert.Equal(Uri.UriSchemeHttps, uri.Scheme);
    }

    [Fact]
    public void Pins_AreFullSha256Values()
    {
        Assert.Equal(64, Phonon2ModelStore.ModelSha256.Length);
        Assert.Equal(new[] { "LICENSE", "NOTICE" }, Phonon2ModelStore.AttributionFiles.Select(file => file.Name));
        Assert.All(Phonon2ModelStore.AttributionFiles, file =>
        {
            Assert.Equal(64, file.Sha256.Length);
            Assert.True(file.Size > 0);
        });
    }

    [Fact]
    public async Task EmptyDirectory_IsNotInstalledAndDoesNotVerify()
    {
        using var directory = new TemporaryDirectory();
        var store = new Phonon2ModelStore(directory.Path);

        Assert.False(store.IsInstalled);
        Assert.False(await store.VerifyInstalledAsync());
    }

    [Fact]
    public void AttributionWithoutWeights_IsNotInstalled()
    {
        using var directory = new TemporaryDirectory();
        foreach (var file in Phonon2ModelStore.AttributionFiles)
            File.WriteAllBytes(Path.Combine(directory.Path, file.Name), new byte[file.Size]);
        File.WriteAllBytes(Path.Combine(directory.Path, Phonon2ModelStore.ModelFileName), new byte[16]);

        Assert.False(new Phonon2ModelStore(directory.Path).IsInstalled);
    }

    [Fact]
    public void Recognizer_ReportsMissingModelWithoutDownloading()
    {
        using var directory = new TemporaryDirectory();
        using var recognizer = new Phonon2Recognizer(new Phonon2ModelStore(directory.Path));

        Assert.NotNull(recognizer.GetUnavailableReason());
        Assert.Empty(Directory.GetFiles(directory.Path));
    }

    [Fact]
    public void BuildResult_ConvertsCentisecondsAndSkipsBlankSegments()
    {
        var result = Phonon2Recognizer.BuildResult(new[]
        {
            new CrispAsrSegment(" Hello world. ", 0, 125),
            new CrispAsrSegment("   ", 125, 130),
            new CrispAsrSegment("Second line", 130, 410),
        });

        Assert.Equal("Hello world. Second line", result.Text);
        Assert.Equal(2, result.Segments.Count);
        Assert.Equal(1.25, result.Segments[0].End, 3);
        Assert.Equal(1.30, result.Segments[1].Start, 3);
        Assert.Equal("00:00:01.300", result.Segments[1].Timestamp);
        Assert.StartsWith("WEBVTT", result.Vtt, StringComparison.Ordinal);
    }

    [Fact]
    public void WorkerThreads_StayWithinMachineAndCap()
    {
        var threads = Phonon2Recognizer.WorkerThreads();

        Assert.InRange(threads, 1, Math.Min(8, Environment.ProcessorCount));
    }

    private sealed class TemporaryDirectory : IDisposable
    {
        public string Path { get; } = System.IO.Path.Combine(System.IO.Path.GetTempPath(), Guid.NewGuid().ToString("N"));
        public TemporaryDirectory() => Directory.CreateDirectory(Path);
        public void Dispose() => Directory.Delete(Path, recursive: true);
    }
}
