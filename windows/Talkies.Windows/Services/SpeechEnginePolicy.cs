using System;
using System.Collections.Generic;
using Talkies.Windows.Models;

namespace Talkies.Windows.Services
{
    /// <summary>Pure ordering rules for the local recognizer chain.</summary>
    public static class SpeechEnginePolicy
    {
        public const string Phonon2Id = "phonon2";
        public const string WhisperId = "whisper";

        /// <summary>
        /// Phonon-2 is English-only. "auto" (no language chosen) is treated as English because the
        /// user explicitly installed the English-only engine; choosing any other language routes to Whisper.
        /// </summary>
        public static bool IsPhonon2Language(string? language)
        {
            if (string.IsNullOrWhiteSpace(language)) return true;
            var value = language.Trim();
            return value.Equals("auto", StringComparison.OrdinalIgnoreCase)
                || value.Equals("en", StringComparison.OrdinalIgnoreCase)
                || value.StartsWith("en-", StringComparison.OrdinalIgnoreCase)
                || value.StartsWith("en_", StringComparison.OrdinalIgnoreCase);
        }

        /// <summary>Returns recognizer ids in the order they should be tried. Whisper is always last.</summary>
        public static IReadOnlyList<string> Order(SpeechEngine engine, string? language)
        {
            if (engine == SpeechEngine.Whisper || !IsPhonon2Language(language))
                return new[] { WhisperId };
            return new[] { Phonon2Id, WhisperId };
        }
    }
}
