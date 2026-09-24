using System;
using System.Net;
using System.Net.Http;

namespace Talkies.Windows.Services
{
    /// <summary>
    /// Builds inference request URIs only for services running on this device.
    /// </summary>
    public static class LocalModelEndpoint
    {
        /// <summary>
        /// Creates an endpoint URI for a local inference API route.
        /// Non-loopback hosts, credentials, query strings, and fragments are rejected.
        /// </summary>
        public static bool TryCreateRequestUri(string? endpoint, string route, out Uri requestUri)
        {
            requestUri = null!;
            if (string.IsNullOrWhiteSpace(endpoint) || !Uri.TryCreate(endpoint.Trim(), UriKind.Absolute, out var baseUri))
            {
                return false;
            }

            if ((baseUri.Scheme != Uri.UriSchemeHttp && baseUri.Scheme != Uri.UriSchemeHttps)
                || !string.IsNullOrEmpty(baseUri.UserInfo)
                || !string.IsNullOrEmpty(baseUri.Query)
                || !string.IsNullOrEmpty(baseUri.Fragment)
                || !IsLoopbackHost(baseUri.Host))
            {
                return false;
            }

            var normalizedBase = new Uri(baseUri.AbsoluteUri.TrimEnd('/') + "/", UriKind.Absolute);
            if (!Uri.TryCreate(normalizedBase, route.TrimStart('/'), out var candidate) || candidate is null)
            {
                return false;
            }

            requestUri = candidate;
            return true;
        }

        /// <summary>
        /// Creates a client that never follows redirects away from a local model server.
        /// </summary>
        public static HttpClient CreateClient(TimeSpan timeout)
        {
            return new HttpClient(new HttpClientHandler { AllowAutoRedirect = false })
            {
                Timeout = timeout
            };
        }

        private static bool IsLoopbackHost(string host)
        {
            if (host.Equals("localhost", StringComparison.OrdinalIgnoreCase)
                || host.Equals("localhost.", StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            return IPAddress.TryParse(host, out var address) && IPAddress.IsLoopback(address);
        }
    }
}
