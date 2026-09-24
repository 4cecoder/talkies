using System;
using System.Collections.Generic;
using System.Linq;

namespace Talkies.Windows.Models;

/// <summary>Normalizes user vocabulary for local Whisper prompt conditioning.</summary>
public static class LocalVocabulary
{
    public static List<string> Normalize(IEnumerable<string>? terms)
    {
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var normalizedTerms = new List<string>();
        foreach (var term in terms ?? Enumerable.Empty<string>())
        {
            if (term is null) continue;
            var normalized = term.Trim();
            if (!string.IsNullOrWhiteSpace(normalized) && seen.Add(normalized))
            {
                normalizedTerms.Add(normalized);
            }
        }
        return normalizedTerms;
    }

    public static string ToPrompt(IEnumerable<string>? terms)
    {
        const int maximumCharacters = 400;
        var acceptedTerms = new List<string>();
        var promptLength = 0;
        foreach (var term in Normalize(terms))
        {
            var extraLength = term.Length + (acceptedTerms.Count == 0 ? 0 : 2);
            if (promptLength + extraLength > maximumCharacters) break;
            acceptedTerms.Add(term);
            promptLength += extraLength;
        }
        return string.Join(", ", acceptedTerms);
    }
}
