namespace Talkies.Windows.Models
{
    /// <summary>User-selected speech-recognition engine preference.</summary>
    public enum SpeechEngine
    {
        /// <summary>Phonon-2 for English (and unspecified) speech, Whisper otherwise or when Phonon-2 is unavailable.</summary>
        Automatic,

        /// <summary>Prefer Phonon-2; Whisper still handles non-English speech and Phonon-2 failures.</summary>
        Phonon2,

        /// <summary>Use Whisper only.</summary>
        Whisper
    }
}
