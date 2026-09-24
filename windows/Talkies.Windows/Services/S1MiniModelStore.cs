using System.Security.Cryptography;
using System.Net.Http;

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

    public S1MiniModelStore(string? directory = null)
    {
        _directory = directory ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Talkies", "Models", $"S1-mini-{Revision}");
    }

    public string ModelPath => Path.Combine(_directory, ModelFileName);
    public bool IsInstalled => File.Exists(ModelPath) && new FileInfo(ModelPath).Length == ModelSize;

    public async Task<string> EnsureInstalledAsync(IProgress<double>? progress = null, CancellationToken cancellationToken = default)
    {
        Directory.CreateDirectory(_directory);
        if (!IsInstalled || !await HasExpectedHashAsync(ModelPath, cancellationToken).ConfigureAwait(false))
        {
            TryDelete(ModelPath);
            await DownloadVerifiedFileAsync(ModelFileName, ModelPath, ModelSize, ModelSha256, progress, cancellationToken).ConfigureAwait(false);
        }

        // Keep upstream attribution beside the weights; the model's Apache-2.0 naming clause applies.
        foreach (var file in new[] { "LICENSE", "NOTICE" })
        {
            var path = Path.Combine(_directory, file);
            if (!File.Exists(path))
                await DownloadVerifiedFileAsync(file, path, null, null, null, cancellationToken).ConfigureAwait(false);
        }
        return ModelPath;
    }

    private async Task DownloadVerifiedFileAsync(string name, string destination, long? expectedSize, string? expectedHash, IProgress<double>? progress, CancellationToken cancellationToken)
    {
        var url = $"https://huggingface.co/superwhisper/s1-mini-GGUF/resolve/{Revision}/{Uri.EscapeDataString(name)}?download=true";
        var partial = destination + ".partial";
        try
        {
            using var response = await Client.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, cancellationToken).ConfigureAwait(false);
            response.EnsureSuccessStatusCode();
            var total = response.Content.Headers.ContentLength;
            await using var input = await response.Content.ReadAsStreamAsync(cancellationToken).ConfigureAwait(false);
            await using var output = new FileStream(partial, FileMode.Create, FileAccess.Write, FileShare.None, 128 * 1024, useAsync: true);
            using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
            var buffer = new byte[128 * 1024];
            long written = 0;
            int read;
            while ((read = await input.ReadAsync(buffer, cancellationToken).ConfigureAwait(false)) > 0)
            {
                await output.WriteAsync(buffer.AsMemory(0, read), cancellationToken).ConfigureAwait(false);
                hash.AppendData(buffer, 0, read);
                written += read;
                if (total is > 0) progress?.Report((double)written / total.Value);
            }
            await output.FlushAsync(cancellationToken).ConfigureAwait(false);
            if (expectedSize.HasValue && written != expectedSize.Value) throw new InvalidDataException($"S1-mini model size mismatch: expected {expectedSize.Value} bytes, received {written}.");
            if (expectedHash is not null && !Convert.ToHexString(hash.GetHashAndReset()).Equals(expectedHash, StringComparison.OrdinalIgnoreCase)) throw new InvalidDataException("S1-mini model SHA-256 verification failed.");
            File.Move(partial, destination, overwrite: true);
        }
        catch
        {
            TryDelete(partial);
            throw;
        }
    }

    private static async Task<bool> HasExpectedHashAsync(string path, CancellationToken cancellationToken)
    {
        await using var stream = File.OpenRead(path);
        var hash = await SHA256.HashDataAsync(stream, cancellationToken).ConfigureAwait(false);
        return Convert.ToHexString(hash).Equals(ModelSha256, StringComparison.OrdinalIgnoreCase);
    }

    private static void TryDelete(string path) { try { File.Delete(path); } catch (IOException) { } }
}
