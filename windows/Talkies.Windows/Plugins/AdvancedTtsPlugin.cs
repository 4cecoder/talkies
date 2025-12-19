using System;
using System.Linq;
using System.Speech.Synthesis;
using System.Security;
using System.Threading.Tasks;

namespace Talkies.Windows.Plugins
{
    /// <summary>
    /// Enhanced text-to-speech plugin with configurable voices, speed, volume and pitch.
    /// </summary>
    public class AdvancedTtsPlugin : ITtsSynthesizer
    {
        private readonly SpeechSynthesizer _synth = new SpeechSynthesizer();
        private string _selectedVoice = "Microsoft Zira Desktop";
        private int _pitch = 0;

        public string Name => "Advanced TTS";
        public bool IsEnabled { get; set; } = true;

        /// <summary>
        /// Gets the list of available voices.
        /// </summary>
        public System.Collections.ObjectModel.ReadOnlyCollection<InstalledVoice> AvailableVoices
        {
            get => _synth.GetInstalledVoices();
        }

        /// <summary>
        /// Gets or sets the selected voice name.
        /// </summary>
        public string SelectedVoice
        {
            get => _selectedVoice;
            set
            {
                _selectedVoice = value ?? "Microsoft Zira Desktop";
                UpdateSelectedVoice();
            }
        }

        /// <summary>
        /// Gets or sets the speech rate (default: 0, normal speed).
        /// </summary>
        public int Rate { get; set; } = 0;

        /// <summary>
        /// Gets or sets the pitch adjustment (-20 to 20 => percentage shift).
        /// </summary>
        public int Pitch
        {
            get => _pitch;
            set => _pitch = Math.Max(-20, Math.Min(20, value));
        }

        /// <summary>
        /// Gets or sets the speech volume (0-100, default: 100).
        /// </summary>
        public int Volume { get; set; } = 100;

        public AdvancedTtsPlugin()
        {
            // Set default rate and volume
            _synth.Rate = Rate;
            _synth.Volume = Volume;
            UpdateSelectedVoice();
        }

        private void UpdateSelectedVoice()
        {
            try
            {
                var voice = AvailableVoices.FirstOrDefault(v => v.VoiceInfo.Name == _selectedVoice);
                if (voice != null)
                {
                    _synth.SelectVoice(_selectedVoice);
                }
                else if (AvailableVoices.Count > 0)
                {
                    // Fallback to first available voice
                    _selectedVoice = AvailableVoices[0].VoiceInfo.Name;
                    _synth.SelectVoice(_selectedVoice);
                }
            }
            catch
            {
                // Fallback to default system voice
                _synth.SelectVoice("Microsoft Zira Desktop");
            }
        }

        private static string BuildSsml(string text, int rate, int pitch, int volume)
        {
            // Clamp values to safe ranges
            var ratePercent = Math.Clamp(100 + (rate * 10), 20, 300); // -10..10 -> 0.2x..3x
            var pitchPercent = Math.Clamp(pitch * 5, -100, 100);      // -20..20 -> -100%..100%
            var safeVolume = Math.Clamp(volume, 0, 100);

            string Escape(string input) => System.Security.SecurityElement.Escape(input) ?? string.Empty;

            return $"""
<speak version="1.0" xml:lang="en-US">
  <prosody rate="{ratePercent}%" pitch="{pitchPercent}%" volume="{safeVolume}%">
    {Escape(text)}
  </prosody>
</speak>
""";
        }

        /// <summary>
        /// Synthesizes and plays the given text with current settings.
        /// </summary>
        public async Task SynthesizeAndPlayAsync(string text)
        {
            if (string.IsNullOrWhiteSpace(text))
                return;

            await Task.Run(() =>
            {
                try
                {
                    // Apply settings
                    _synth.Rate = Rate;
                    _synth.Volume = Volume;

                    var ssml = BuildSsml(text, Rate, Pitch, Volume);
                    _synth.SpeakSsml(ssml);
                }
                catch (Exception ex)
                {
                    Services.Logger.Error($"TTS synthesis failed: {ex.Message}");
                }
            });
        }

        /// <summary>
        /// Gets the current voice name for display.
        /// </summary>
        public string GetCurrentVoiceName()
        {
            try
            {
                return _synth.Voice.Name;
            }
            catch
            {
                return "Default Voice";
            }
        }
    }
}
