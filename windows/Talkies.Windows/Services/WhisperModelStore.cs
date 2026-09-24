using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Security.Cryptography;
using System.Threading;
using System.Threading.Tasks;
using Talkies.Windows.Models;

namespace Talkies.Windows.Services;

/// <summary>Manages revision-pinned, integrity-checked local Whisper models.</summary>
public sealed class WhisperModelStore
{
    public const string Revision = "5359861c739e955e79d9a303bcbc70fb988958b1";
    private const string Repository = "https://huggingface.co/ggerganov/whisper.cpp";
    private static readonly HttpClient SharedClient = new() { Timeout = TimeSpan.FromMinutes(30) };
    private static readonly IReadOnlyDictionary<string, ModelInfo> Catalog = new Dictionary<string, ModelInfo>(StringComparer.OrdinalIgnoreCase)
    {
        ["tiny"] = new("ggml-tiny.bin", 77_691_713, "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21"),
        ["base"] = new("ggml-base.bin", 147_951_465, "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe"),
        ["small"] = new("ggml-small.bin", 487_601_967, "1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b"),
        ["medium"] = new("ggml-medium.bin", 1_533_763_059, "6c14d5adee5f86394037b4e4e8b59f1673b6cee10e3cf0b11bbdbee79c156208"),
        ["large"] = new("ggml-large-v3.bin", 3_095_033_483, "64d182b440b98d5203c4f9bd541544d84c605196c4f7b845dfa11fb23594d1e2")
    };

    private readonly string _directory;
    private readonly VerifiedFileDownloader _downloader;

    public WhisperModelStore(string? directory = null, HttpClient? client = null)
    {
        _directory = directory ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".talkies", "models");
        _downloader = new VerifiedFileDownloader(client ?? SharedClient);
    }

    public string GetModelPath(string model)
    {
        if (!Catalog.TryGetValue(model, out var metadata))
            throw new ArgumentOutOfRangeException(nameof(model), model, "Unsupported Whisper model.");
        return Path.Combine(_directory, metadata.FileName);
    }

    public async Task<string> EnsureAvailableAsync(
        string model,
        IProgress<TranscriptionProgress>? progress = null,
        CancellationToken cancellationToken = default)
    {
        if (!Catalog.TryGetValue(model, out var metadata))
            throw new ArgumentOutOfRangeException(nameof(model), model, "Unsupported Whisper model.");

        Directory.CreateDirectory(_directory);
        var path = Path.Combine(_directory, metadata.FileName);
        if (await IsVerifiedAsync(path, metadata, cancellationToken).ConfigureAwait(false)) return path;

        progress?.Report(new TranscriptionProgress(TranscriptionStage.DownloadModel, 0, $"Downloading {metadata.FileName}...", IsIndeterminate: true));
        var url = new Uri($"{Repository}/resolve/{Revision}/{Uri.EscapeDataString(metadata.FileName)}?download=true");
        await _downloader.DownloadAsync(url, path, metadata.Size, metadata.Sha256, new Progress<double>(fraction =>
            progress?.Report(new TranscriptionProgress(TranscriptionStage.DownloadModel, fraction * 100, $"Downloading {metadata.FileName}... {fraction:P0}", IsIndeterminate: false))), cancellationToken).ConfigureAwait(false);
        progress?.Report(new TranscriptionProgress(TranscriptionStage.DownloadModel, 100, "Whisper model ready", IsIndeterminate: false));
        return path;
    }

    private static async Task<bool> IsVerifiedAsync(string path, ModelInfo metadata, CancellationToken cancellationToken)
    {
        if (!File.Exists(path) || new FileInfo(path).Length != metadata.Size) return false;
        await using var stream = File.OpenRead(path);
        var hash = await SHA256.HashDataAsync(stream, cancellationToken).ConfigureAwait(false);
        return Convert.ToHexString(hash).Equals(metadata.Sha256, StringComparison.OrdinalIgnoreCase);
    }

    private sealed record ModelInfo(string FileName, long Size, string Sha256);
}
