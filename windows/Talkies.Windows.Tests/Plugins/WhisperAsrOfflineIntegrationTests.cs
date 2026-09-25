using System;
using System.IO;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using Talkies.Windows.Services;
using Xunit;

namespace Talkies.Windows.Tests.Plugins;

public sealed class WhisperAsrOfflineIntegrationTests
{
    [ModelIntegrationFact("TALKIES_TEST_WHISPER_MODEL_DIR")]
    [Trait("Category", "ModelIntegration")]
    public async Task CachedWhisperModelRecognizesSpeechWithoutNetworkAccess()
    {
        var modelDirectory = Environment.GetEnvironmentVariable("TALKIES_TEST_WHISPER_MODEL_DIR")
            ?? throw new InvalidOperationException("Model integration attribute should require a model directory.");

        // Ensure first-run model acquisition is pinned and verified before offline recognition.
        var connectedStore = new WhisperModelStore(modelDirectory);
        var modelPath = await connectedStore.EnsureAvailableAsync("tiny");
        Assert.True(File.Exists(modelPath));

        using var networkDeniedClient = new HttpClient(new NetworkDeniedHandler());
        var offlineService = new WhisperNetTranscriptionService(new WhisperModelStore(modelDirectory, networkDeniedClient));
        var fixturePath = Path.Combine(AppContext.BaseDirectory, "Fixtures", "jfk.wav");
        Assert.True(File.Exists(fixturePath), $"Missing speech fixture: {fixturePath}");

        var result = await offlineService.TranscribeAsync(fixturePath, "tiny", "en", vadEnabled: false, filterEnabled: false);

        Assert.Contains("country", result.Text, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("ask not what your country", result.Text, StringComparison.OrdinalIgnoreCase);
    }

    private sealed class NetworkDeniedHandler : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) =>
            Task.FromException<HttpResponseMessage>(new InvalidOperationException($"Unexpected network request during offline ASR: {request.RequestUri}"));
    }
}
