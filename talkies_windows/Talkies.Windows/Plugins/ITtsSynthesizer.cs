using System.Threading.Tasks;

namespace Talkies.Windows.Plugins
{
    public interface ITtsSynthesizer : IPlugin
    {
        Task SynthesizeAndPlayAsync(string text);
    }
}
