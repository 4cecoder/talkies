using Talkies.Windows.Services;
using Xunit;

namespace Talkies.Windows.Tests.Services
{
    public class LocalModelEndpointTests
    {
        [Theory]
        [InlineData("http://localhost:11434", "/api/chat", "http://localhost:11434/api/chat")]
        [InlineData("http://localhost.:11434/ollama", "/api/tags", "http://localhost.:11434/ollama/api/tags")]
        [InlineData("http://127.42.1.9:1234", "/v1/models", "http://127.42.1.9:1234/v1/models")]
        [InlineData("http://[::1]:1234", "/v1/chat/completions", "http://[::1]:1234/v1/chat/completions")]
        public void TryCreateRequestUri_AcceptsLoopbackEndpoints(string endpoint, string route, string expected)
        {
            var accepted = LocalModelEndpoint.TryCreateRequestUri(endpoint, route, out var uri);

            Assert.True(accepted);
            Assert.Equal(expected, uri.AbsoluteUri);
        }

        [Theory]
        [InlineData("https://example.com:11434")]
        [InlineData("http://192.168.1.5:11434")]
        [InlineData("http://localhost.example.com:11434")]
        [InlineData("http://user@localhost:11434")]
        [InlineData("http://localhost:11434/?next=https://example.com")]
        [InlineData("ftp://localhost:11434")]
        [InlineData("not a url")]
        public void TryCreateRequestUri_RejectsRemoteOrUnsafeEndpoints(string endpoint)
        {
            Assert.False(LocalModelEndpoint.TryCreateRequestUri(endpoint, "/api/chat", out _));
        }
    }
}
