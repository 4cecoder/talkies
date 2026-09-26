using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using System.Net.Http;
using System.Security.Cryptography;

namespace Talkies.Windows.Services;

/// <summary>Downloads and verifies the pinned S1-mini weights and required attribution files.</summary>
public sealed class S1MiniModelStore
{
    public const string Revision = "34add00a48a2e5d24e5a4ee5405a99620a3a240c";
    public const string ModelFileName = "s1-mini-q4_k_m.gguf";
    public const long ModelSize = 484_219_808;
    public const string ModelSha256 = "3b41ebe2502cbd03e811d5d16b022f5ab551eda58d62597d152f89535003c634";
    private static readonly HttpClient Client = new() { Timeout = TimeSpan.FromMinutes(30) };
    private readonly string _directory;
    private readonly VerifiedFileDownloader _downloader;

    public S1MiniModelStore(string? directory = null, HttpClient? client = null)
    {
        _directory = directory ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Talkies", "Models", $"S1-mini-{Revision}");
        _downloader = new VerifiedFileDownloader(client ?? Client);
    }

    public string ModelPath => Path.Combine(_directory, ModelFileName);
    public bool IsInstalled => File.Exists(ModelPath) && new FileInfo(ModelPath).Length == ModelSize;

    public async Task<string> EnsureInstalledAsync(IProgress<double>? progress = null, CancellationToken cancellationToken = default)
    {
        Directory.CreateDirectory(_directory);
        if (!IsInstalled || !await HasExpectedHashAsync(ModelPath, cancellationToken).ConfigureAwait(false))
        {
            await DownloadVerifiedFileAsync(ModelFileName, ModelPath, ModelSize, ModelSha256, progress, cancellationToken).ConfigureAwait(false);
        }

        // Keep upstream attribution beside the weights; the model's Apache-2.0 naming clause applies.
        foreach (var file in new[] { "LICENSE", "NOTICE" })
        {
            var path = Path.Combine(_directory, file);
            if (!IsNonEmptyArtifact(path))
                await DownloadVerifiedFileAsync(file, path, null, null, null, cancellationToken).ConfigureAwait(false);
        }
        return ModelPath;
    }

    internal static bool IsNonEmptyArtifact(string path) =>
        File.Exists(path) && new FileInfo(path).Length > 0;

    private async Task DownloadVerifiedFileAsync(string name, string destination, long? expectedSize, string? expectedHash, IProgress<double>? progress, CancellationToken cancellationToken)
    {
        var url = $"https://huggingface.co/superwhisper/s1-mini-GGUF/resolve/{Revision}/{Uri.EscapeDataString(name)}?download=true";
        await _downloader.DownloadAsync(new Uri(url), destination, expectedSize, expectedHash, progress, cancellationToken).ConfigureAwait(false);
    }

    private static async Task<bool> HasExpectedHashAsync(string path, CancellationToken cancellationToken)
    {
        await using var stream = File.OpenRead(path);
        var hash = await SHA256.HashDataAsync(stream, cancellationToken).ConfigureAwait(false);
        return Convert.ToHexString(hash).Equals(ModelSha256, StringComparison.OrdinalIgnoreCase);
    }

}
