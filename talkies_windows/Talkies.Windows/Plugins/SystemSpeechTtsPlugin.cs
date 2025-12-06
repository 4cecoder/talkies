using System.Speech.Synthesis;
using System.Threading.Tasks;

namespace Talkies.Windows.Plugins
{
    public class SystemSpeechTtsPlugin : ITtsSynthesizer
    {
        public string Name => "System.Speech";
        public bool IsEnabled { get; set; } = true;

        public Task SynthesizeAndPlayAsync(string text)
        {
            return Task.Run(() =>
            {
                using var synth = new SpeechSynthesizer();
                synth.Speak(text);
            });
        }
    }
}
