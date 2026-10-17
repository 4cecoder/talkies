using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Security.Cryptography;
using System.Threading;
using System.Threading.Tasks;

namespace Talkies.Windows.Services;

/// <summary>
/// Downloads and verifies the revision-pinned Phonon-2 GGUF weights (Fermion Research's compressed
/// NVIDIA Parakeet TDT 0.6B v3, CC-BY-4.0) and keeps the upstream LICENSE and NOTICE beside them.
/// Downloads happen only through <see cref="EnsureInstalledAsync"/>, which the user starts explicitly.
/// </summary>
public sealed class Phonon2ModelStore
{
    public const string Repository = "cstr/phonon2-GGUF";
    public const string Revision = "3ed3e6ad6e7ce63affffeede37328ff756efaa2f";
    public const string ModelFileName = "phonon2-q8_0.gguf";
    public const long ModelSize = 674_342_560;
    public const string ModelSha256 = "a8c4a874195b83604ceb5d87c0e9b5ddf641ef1d5ec2d8e1ca2a040d25b2563a";

    /// <summary>Attribution files required by CC-BY-4.0, pinned to the same revision as the weights.</summary>
    internal static readonly IReadOnlyList<PinnedFile> AttributionFiles = new[]
    {
        new PinnedFile("LICENSE", 18_657, "9ba9550ad48438d0836ddab3da480b3b69ffa0aac7b7878b5a0039e7ab429411"),
        new PinnedFile("NOTICE", 2_741, "00624a5043e7ce74029317b024132ca5286116d6fbf3191d226374bc8273789f"),
    };

    private static readonly HttpClient Client = new() { Timeout = TimeSpan.FromMinutes(30) };
    private readonly string _directory;
    private readonly VerifiedFileDownloader _downloader;

    public Phonon2ModelStore(string? directory = null, HttpClient? client = null)
    {
        _directory = directory ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Talkies", "Models", $"Phonon-2-{Revision}");
        _downloader = new VerifiedFileDownloader(client ?? Client);
    }

    public string Directory => _directory;
    public string ModelPath => Path.Combine(_directory, ModelFileName);

    /// <summary>Cheap presence check (sizes only). Hashes are verified on install and before each first load.</summary>
    public bool IsInstalled =>
        HasExpectedSize(ModelPath, ModelSize) &&
        AttributionFiles.All(file => HasExpectedSize(Path.Combine(_directory, file.Name), file.Size));

    internal static Uri GetDownloadUri(string fileName) =>
        new($"https://huggingface.co/{Repository}/resolve/{Revision}/{Uri.EscapeDataString(fileName)}?download=true");

    public async Task<string> EnsureInstalledAsync(IProgress<double>? progress = null, CancellationToken cancellationToken = default)
    {
        System.IO.Directory.CreateDirectory(_directory);
        if (!HasExpectedSize(ModelPath, ModelSize) || !await HasExpectedHashAsync(ModelPath, ModelSha256, cancellationToken).ConfigureAwait(false))
        {
            await _downloader.DownloadAsync(GetDownloadUri(ModelFileName), ModelPath, ModelSize, ModelSha256, progress, cancellationToken).ConfigureAwait(false);
        }

        // Keep the upstream CC-BY-4.0 attribution beside the weights.
        foreach (var file in AttributionFiles)
        {
            var path = Path.Combine(_directory, file.Name);
            if (!HasExpectedSize(path, file.Size) || !await HasExpectedHashAsync(path, file.Sha256, cancellationToken).ConfigureAwait(false))
                await _downloader.DownloadAsync(GetDownloadUri(file.Name), path, file.Size, file.Sha256, null, cancellationToken).ConfigureAwait(false);
        }

        return ModelPath;
    }

    /// <summary>Verifies the installed weights and attribution against their pinned SHA-256 values.</summary>
    public async Task<bool> VerifyInstalledAsync(CancellationToken cancellationToken = default)
    {
        if (!IsInstalled) return false;
        if (!await HasExpectedHashAsync(ModelPath, ModelSha256, cancellationToken).ConfigureAwait(false)) return false;
        foreach (var file in AttributionFiles)
        {
            if (!await HasExpectedHashAsync(Path.Combine(_directory, file.Name), file.Sha256, cancellationToken).ConfigureAwait(false))
                return false;
        }
        return true;
    }

    private static bool HasExpectedSize(string path, long size) =>
        File.Exists(path) && new FileInfo(path).Length == size;

    private static async Task<bool> HasExpectedHashAsync(string path, string expectedSha256, CancellationToken cancellationToken)
    {
        await using var stream = File.OpenRead(path);
        var hash = await SHA256.HashDataAsync(stream, cancellationToken).ConfigureAwait(false);
        return Convert.ToHexString(hash).Equals(expectedSha256, StringComparison.OrdinalIgnoreCase);
    }

    internal sealed record PinnedFile(string Name, long Size, string Sha256);
}
