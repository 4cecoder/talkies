using System;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Security.Cryptography;
using System.Threading;
using System.Threading.Tasks;
using Talkies.Windows.Services;
using Xunit;

namespace Talkies.Windows.Tests.Services;

public sealed class VerifiedFileDownloaderTests
{
    [Fact]
    public async Task DownloadAsync_InstallsFileAfterSizeAndHashMatch()
    {
        using var directory = new TemporaryDirectory();
        var payload = new byte[] { 1, 4, 9, 16, 25 };
        var progress = new RecordingProgress();
        var downloader = CreateDownloader(payload);
        var destination = Path.Combine(directory.Path, "model.gguf");

        await downloader.DownloadAsync(new Uri("https://models.example/model"), destination, payload.Length, Hash(payload), progress);

        Assert.Equal(payload, await File.ReadAllBytesAsync(destination));
        Assert.Equal(1, progress.Values.Last());
        Assert.Empty(Directory.GetFiles(directory.Path, "*.partial-*"));
    }

    [Fact]
    public async Task DownloadAsync_RejectsHashMismatchAndPreservesPreviousFile()
    {
        using var directory = new TemporaryDirectory();
        var destination = Path.Combine(directory.Path, "model.gguf");
        var previous = new byte[] { 42, 43 };
        await File.WriteAllBytesAsync(destination, previous);
        var downloader = CreateDownloader(new byte[] { 1, 2, 3 });

        await Assert.ThrowsAsync<InvalidDataException>(() => downloader.DownloadAsync(
            new Uri("https://models.example/model"), destination, 3, new string('0', 64)));

        Assert.Equal(previous, await File.ReadAllBytesAsync(destination));
        Assert.Empty(Directory.GetFiles(directory.Path, "*.partial-*"));
    }

    [Fact]
    public async Task DownloadAsync_RejectsSizeMismatchWithoutLeavingPartialFile()
    {
        using var directory = new TemporaryDirectory();
        var destination = Path.Combine(directory.Path, "model.gguf");
        var downloader = CreateDownloader(new byte[] { 1, 2, 3 });

        await Assert.ThrowsAsync<InvalidDataException>(() => downloader.DownloadAsync(
            new Uri("https://models.example/model"), destination, 4, null));

        Assert.False(File.Exists(destination));
        Assert.Empty(Directory.GetFiles(directory.Path));
    }

    [Fact]
    public async Task DownloadAsync_RejectsEmptyUnhashedAttributionFile()
    {
        using var directory = new TemporaryDirectory();
        var destination = Path.Combine(directory.Path, "LICENSE");
        var downloader = CreateDownloader(Array.Empty<byte>());

        await Assert.ThrowsAsync<InvalidDataException>(() => downloader.DownloadAsync(
            new Uri("https://models.example/LICENSE"), destination, null, null));

        Assert.False(File.Exists(destination));
        Assert.Empty(Directory.GetFiles(directory.Path));
    }

    private static VerifiedFileDownloader CreateDownloader(byte[] payload) =>
        new(new HttpClient(new StaticResponseHandler(payload)));

    private static string Hash(byte[] payload) => Convert.ToHexString(SHA256.HashData(payload));

    private sealed class StaticResponseHandler(byte[] payload) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) =>
            Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new ByteArrayContent(payload) });
    }

    private sealed class RecordingProgress : IProgress<double>
    {
        public System.Collections.Generic.List<double> Values { get; } = new();
        public void Report(double value) => Values.Add(value);
    }

    private sealed class TemporaryDirectory : IDisposable
    {
        public string Path { get; } = System.IO.Path.Combine(System.IO.Path.GetTempPath(), Guid.NewGuid().ToString("N"));
        public TemporaryDirectory() => Directory.CreateDirectory(Path);
        public void Dispose() => Directory.Delete(Path, recursive: true);
    }
}
