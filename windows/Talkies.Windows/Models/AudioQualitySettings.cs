namespace Talkies.Windows.Models
{
    public enum AudioQualityPreset
    {
        Low,
        Medium,
        High,
        Studio,
        Custom
    }

    public enum AudioSampleRate
    {
        Rate16000 = 16000,
        Rate22050 = 22050,
        Rate44100 = 44100,
        Rate48000 = 48000
    }

    public enum AudioBitDepth
    {
        Bits16 = 16,
        Bits24 = 24
    }

    public enum AudioChannels
    {
        Mono = 1,
        Stereo = 2
    }

    public class AudioQualitySettings
    {
        public AudioQualityPreset Preset { get; set; } = AudioQualityPreset.High;
        public AudioSampleRate SampleRate { get; set; } = AudioSampleRate.Rate44100;
        public AudioBitDepth BitDepth { get; set; } = AudioBitDepth.Bits16;
        public AudioChannels Channels { get; set; } = AudioChannels.Mono;

        public int SampleRateHz => (int)SampleRate;
        public int BitsPerSample => (int)BitDepth;
        public int ChannelCount => (int)Channels;

        public static AudioQualitySettings FromPreset(AudioQualityPreset preset)
        {
            return preset switch
            {
                AudioQualityPreset.Low => new AudioQualitySettings
                {
                    Preset = AudioQualityPreset.Low,
                    SampleRate = AudioSampleRate.Rate16000,
                    BitDepth = AudioBitDepth.Bits16,
                    Channels = AudioChannels.Mono
                },
                AudioQualityPreset.Medium => new AudioQualitySettings
                {
                    Preset = AudioQualityPreset.Medium,
                    SampleRate = AudioSampleRate.Rate22050,
                    BitDepth = AudioBitDepth.Bits16,
                    Channels = AudioChannels.Mono
                },
                AudioQualityPreset.High => new AudioQualitySettings
                {
                    Preset = AudioQualityPreset.High,
                    SampleRate = AudioSampleRate.Rate44100,
                    BitDepth = AudioBitDepth.Bits16,
                    Channels = AudioChannels.Mono
                },
                AudioQualityPreset.Studio => new AudioQualitySettings
                {
                    Preset = AudioQualityPreset.Studio,
                    SampleRate = AudioSampleRate.Rate48000,
                    BitDepth = AudioBitDepth.Bits24,
                    Channels = AudioChannels.Stereo
                },
                _ => new AudioQualitySettings
                {
                    Preset = AudioQualityPreset.Custom,
                    SampleRate = AudioSampleRate.Rate44100,
                    BitDepth = AudioBitDepth.Bits16,
                    Channels = AudioChannels.Mono
                }
            };
        }

        public double GetEstimatedSizePerMinuteMB()
        {
            // Size in bytes: sampleRate * bitsPerSample * channels * 60 seconds / 8 / 1024 / 1024
            return (SampleRateHz * BitsPerSample * ChannelCount * 60.0) / 8.0 / 1024.0 / 1024.0;
        }

        public string GetEstimatedSizeDisplay()
        {
            double sizeMB = GetEstimatedSizePerMinuteMB();
            return $"~{sizeMB:F1} MB/min";
        }
    }
}