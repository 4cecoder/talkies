using System;
using System.IO;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using Talkies.Windows.Plugins;
using Talkies.Windows.Services;
using Xunit;

namespace Talkies.Windows.Tests.Plugins;

public sealed class OfflineDictationAcceptanceTests
{
    [ModelIntegrationFact("TALKIES_TEST_WHISPER_MODEL_DIR")]
    [Trait("Category", "ModelIntegration")]
    public async Task CachedAsrCleanupAndInsertionBoundaryCompleteWithoutNetworkAccess()
    {
        var whisperDirectory = Environment.GetEnvironmentVariable("TALKIES_TEST_WHISPER_MODEL_DIR")
            ?? throw new InvalidOperationException("The cached Whisper model directory is required.");
        var cleanupDirectory = Environment.GetEnvironmentVariable("TALKIES_TEST_S1_MINI_MODEL_DIR")
            ?? throw new InvalidOperationException("The cached S1-mini model directory is required.");

        // Verify/provision models before creating clients that reject every request.
        var whisperPath = await new WhisperModelStore(whisperDirectory).EnsureAvailableAsync("tiny");
        var cleanupPath = await new S1MiniModelStore(cleanupDirectory).EnsureInstalledAsync();
        Assert.True(File.Exists(whisperPath));
        Assert.True(File.Exists(cleanupPath));

        using var networkDeniedClient = new HttpClient(new NetworkDeniedHandler());
        using var recognizer = new WhisperNetTranscriptionService(
            new WhisperModelStore(whisperDirectory, networkDeniedClient));
        using var cleaner = new S1MiniProvider(
            new S1MiniModelStore(cleanupDirectory, networkDeniedClient));

        var fixturePath = Path.Combine(AppContext.BaseDirectory, "Fixtures", "jfk.wav");
        Assert.True(File.Exists(fixturePath), $"Missing speech fixture: {fixturePath}");
        var raw = await recognizer.TranscribeAsync(
            fixturePath,
            "tiny",
            "en",
            vadEnabled: false,
            filterEnabled: false);
        Assert.Contains("ask not what your country", raw.Text, StringComparison.OrdinalIgnoreCase);

        var cleaned = await cleaner.EnhanceAsync(raw.Text, EnhancementMode.Grammar);
        Assert.False(string.IsNullOrWhiteSpace(cleaned));

        var insertionBoundary = new FakeInsertionBoundary();
        Assert.True(insertionBoundary.Insert(cleaned));
        Assert.Equal(cleaned, insertionBoundary.InsertedText);
    }

    private sealed class NetworkDeniedHandler : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken) =>
            Task.FromException<HttpResponseMessage>(new InvalidOperationException(
                $"Unexpected network request during offline dictation acceptance: {request.RequestUri}"));
    }

    private sealed class FakeInsertionBoundary
    {
        public string? InsertedText { get; private set; }

        public bool Insert(string text)
        {
            if (string.IsNullOrWhiteSpace(text)) return false;
            InsertedText = text;
            return true;
        }
    }
}
