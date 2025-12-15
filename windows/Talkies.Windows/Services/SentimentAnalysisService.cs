using System;
using System.Globalization;
using System.Linq;

namespace Talkies.Windows.Services
{
    /// <summary>
    /// Provides sentiment analysis capabilities using built-in .NET features.
    /// </summary>
    public class SentimentAnalysisService
    {
        private static readonly string[] PositiveWords = new[]
        {
            "good", "great", "excellent", "awesome", "wonderful", "fantastic",
            "amazing", "perfect", "love", "happy", "joy", "best", "success",
            "beautiful", "brilliant", "outstanding", "superb", "marvelous"
        };

        private static readonly string[] NegativeWords = new[]
        {
            "bad", "terrible", "awful", "horrible", "hate", "sad", "angry",
            "worst", "fail", "error", "problem", "issue", "broken", "wrong"
        };

        /// <summary>
        /// Analyzes the sentiment of the given text.
        /// </summary>
        public SentimentResult Analyze(string text)
        {
            if (string.IsNullOrWhiteSpace(text))
                return new SentimentResult { Score = 0, Label = "Neutral", Emoji = "😐" };

            // Normalize text
            string normalizedText = text.ToLower(CultureInfo.InvariantCulture);
            string[] words = normalizedText.Split(new[] { ' ', '\t', '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries);

            int positiveCount = 0;
            int negativeCount = 0;

            foreach (string word in words)
            {
                string cleanWord = RemovePunctuation(word);
                if (PositiveWords.Contains(cleanWord))
                    positiveCount++;
                else if (NegativeWords.Contains(cleanWord))
                    negativeCount++;
            }

            // Calculate score (-1 to 1)
            double total = positiveCount + negativeCount;
            double score = 0;

            if (total > 0)
            {
                score = ((positiveCount - negativeCount) / (double)total);
            }

            // Clamp score between -1 and 1
            score = Math.Clamp(score, -1.0, 1.0);

            return ClassifySentiment(score);
        }

        private static string RemovePunctuation(string text)
        {
            return new string(text.Where(c => !char.IsPunctuation(c)).ToArray());
        }

        private static SentimentResult ClassifySentiment(double score)
        {
            if (score > 0.5) return new SentimentResult { Score = score, Label = "Very Positive", Emoji = "🤩" };
            if (score > 0.1) return new SentimentResult { Score = score, Label = "Positive", Emoji = "🙂" };
            if (score < -0.5) return new SentimentResult { Score = score, Label = "Very Negative", Emoji = "🤬" };
            if (score < -0.1) return new SentimentResult { Score = score, Label = "Negative", Emoji = "🙁" };
            return new SentimentResult { Score = score, Label = "Neutral", Emoji = "😐" };
        }
    }

    /// <summary>
    /// Result of sentiment analysis.
    /// </summary>
    public class SentimentResult
    {
        /// <summary>
        /// Sentiment score from -1.0 (very negative) to 1.0 (very positive).
        /// </summary>
        public double Score { get; set; }

        /// <summary>
        /// Human-readable sentiment label.
        /// </summary>
        public string Label { get; set; } = "Neutral";

        /// <summary>
        /// Emoji representing the sentiment.
        /// </summary>
        public string Emoji { get; set; } = "😐";
    }
}
