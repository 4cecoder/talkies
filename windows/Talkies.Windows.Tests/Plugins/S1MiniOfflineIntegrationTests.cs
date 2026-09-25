using System;
using System.IO;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using Talkies.Windows.Plugins;
using Talkies.Windows.Services;
using Xunit;

namespace Talkies.Windows.Tests.Plugins;

public sealed class S1MiniOfflineIntegrationTests
{
    [ModelIntegrationFact("TALKIES_TEST_S1_MINI_MODEL_DIR")]
    [Trait("Category", "ModelIntegration")]
    public async Task VerifiedModelCleansTranscriptWithoutNetworkAccess()
    {
        var modelDirectory = Environment.GetEnvironmentVariable("TALKIES_TEST_S1_MINI_MODEL_DIR");
        Assert.False(string.IsNullOrWhiteSpace(modelDirectory));

        // Provision or verify the pinned weights and attribution files before the offline run.
        var onlineStore = new S1MiniModelStore(modelDirectory);
        var modelPath = await onlineStore.EnsureInstalledAsync();
        Assert.True(File.Exists(Path.Combine(Path.GetDirectoryName(modelPath)!, "LICENSE")));
        Assert.True(File.Exists(Path.Combine(Path.GetDirectoryName(modelPath)!, "NOTICE")));

        using var networkDeniedClient = new HttpClient(new NetworkDeniedHandler());
        using var provider = new S1MiniProvider(new S1MiniModelStore(modelDirectory, networkDeniedClient));
        const string transcript = "so um i need to like send the the report by uh friday no wait make that thursday";

        var cleaned = await provider.EnhanceAsync(transcript, EnhancementMode.Grammar);

        Assert.Contains("send the report", cleaned, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("Thursday", cleaned, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("Friday", cleaned, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("um", cleaned, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("the the", cleaned, StringComparison.OrdinalIgnoreCase);
    }

    private sealed class NetworkDeniedHandler : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) =>
            Task.FromException<HttpResponseMessage>(new InvalidOperationException($"Unexpected network request during offline inference: {request.RequestUri}"));
    }
}

public sealed class ModelIntegrationFactAttribute : FactAttribute
{
    public ModelIntegrationFactAttribute(string modelDirectoryVariable)
    {
        if (Environment.GetEnvironmentVariable("TALKIES_RUN_MODEL_TESTS") != "1" ||
            string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(modelDirectoryVariable)))
            Skip = $"Set TALKIES_RUN_MODEL_TESTS=1 and {modelDirectoryVariable} to run this pinned model integration test.";
    }
}
