using System;
using System.IO;
using System.Net.Http;
using System.Security.Cryptography;
using System.Threading;
using System.Threading.Tasks;

namespace Talkies.Windows.Services;

/// <summary>Downloads a file to a temporary sibling and atomically installs it after integrity checks.</summary>
public sealed class VerifiedFileDownloader
{
    private readonly HttpClient _client;

    public VerifiedFileDownloader(HttpClient client) => _client = client ?? throw new ArgumentNullException(nameof(client));

    public async Task DownloadAsync(
        Uri source,
        string destination,
        long? expectedSize,
        string? expectedSha256,
        IProgress<double>? progress = null,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(source);
        ArgumentException.ThrowIfNullOrWhiteSpace(destination);

        var temporaryPath = destination + ".partial-" + Guid.NewGuid().ToString("N");
        try
        {
            using var response = await _client.GetAsync(source, HttpCompletionOption.ResponseHeadersRead, cancellationToken).ConfigureAwait(false);
            response.EnsureSuccessStatusCode();
            var total = response.Content.Headers.ContentLength;
            await using var input = await response.Content.ReadAsStreamAsync(cancellationToken).ConfigureAwait(false);
            using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
            var buffer = new byte[128 * 1024];
            long written = 0;
            await using (var output = new FileStream(temporaryPath, FileMode.CreateNew, FileAccess.Write, FileShare.None, 128 * 1024, useAsync: true))
            {
                int read;
                while ((read = await input.ReadAsync(buffer, cancellationToken).ConfigureAwait(false)) > 0)
                {
                    await output.WriteAsync(buffer.AsMemory(0, read), cancellationToken).ConfigureAwait(false);
                    hash.AppendData(buffer, 0, read);
                    written += read;
                    if (total is > 0) progress?.Report((double)written / total.Value);
                }

                await output.FlushAsync(cancellationToken).ConfigureAwait(false);
            }

            if (expectedSize.HasValue && written != expectedSize.Value)
                throw new InvalidDataException($"Downloaded file size mismatch: expected {expectedSize.Value} bytes, received {written}.");

            if (expectedSha256 is not null && !Convert.ToHexString(hash.GetHashAndReset()).Equals(expectedSha256, StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException("Downloaded file SHA-256 verification failed.");

            File.Move(temporaryPath, destination, overwrite: true);
            progress?.Report(1);
        }
        catch
        {
            TryDelete(temporaryPath);
            throw;
        }
    }

    private static void TryDelete(string path)
    {
        try { File.Delete(path); }
        catch (IOException) { }
    }
}
