using System.IO;
using System.Net.Http;
using System.Text.Json;

namespace Talkies.Windows.Services;

internal sealed record ReleaseUpdate(string Version, Uri Url);

internal static class ReleaseUpdates
{
    internal static readonly Uri LatestUrl = new("https://github.com/4cecoder/talkies/releases/latest");
    private static readonly Uri ApiUrl = new("https://api.github.com/repos/4cecoder/talkies/releases/latest");
    private static readonly HttpClient Client = CreateClient();

    private static HttpClient CreateClient()
    {
        var client = new HttpClient { Timeout = TimeSpan.FromSeconds(8) };
        client.DefaultRequestHeaders.UserAgent.ParseAdd("Talkies-Windows");
        client.DefaultRequestHeaders.Accept.ParseAdd("application/vnd.github+json");
        return client;
    }

    internal static async Task<ReleaseUpdate?> CheckAsync(string currentVersion, CancellationToken cancellationToken = default)
    {
        using var response = await Client.GetAsync(ApiUrl, cancellationToken).ConfigureAwait(false);
        response.EnsureSuccessStatusCode();
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false));
        var root = document.RootElement;
        if (root.GetProperty("draft").GetBoolean() || root.GetProperty("prerelease").GetBoolean()) return null;
        var version = root.GetProperty("tag_name").GetString()?.TrimStart('v') ?? throw new InvalidDataException("Release version missing");
        var url = new Uri(root.GetProperty("html_url").GetString() ?? throw new InvalidDataException("Release URL missing"));
        if (url.Scheme != Uri.UriSchemeHttps || url.Host != "github.com" || !url.AbsolutePath.StartsWith("/4cecoder/talkies/releases/", StringComparison.Ordinal))
            throw new InvalidDataException("Release URL is outside the Talkies GitHub releases page");
        return Compare(version, currentVersion) > 0 ? new ReleaseUpdate(version, url) : null;
    }

    internal static int Compare(string left, string right)
    {
        static int[] Parts(string value) => value.Split('.').Select(part => int.TryParse(part, out var number) ? number : 0).ToArray();
        var a = Parts(left);
        var b = Parts(right);
        for (var i = 0; i < Math.Max(a.Length, b.Length); i++)
        {
            var result = (i < a.Length ? a[i] : 0).CompareTo(i < b.Length ? b[i] : 0);
            if (result != 0) return result;
        }
        return 0;
    }
}
