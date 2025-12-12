namespace Talkies.Windows.Models
{
    public class TranscriptSegment
    {
        public string Timestamp { get; set; } = "00:00:00.000";
        public string Text { get; set; } = string.Empty;
        public double Start { get; set; }
        public double End { get; set; }
    }
}
