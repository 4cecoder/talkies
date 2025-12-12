using System.Threading.Tasks;

namespace Talkies.Windows.Plugins
{
    public interface ITextEnhancer : IPlugin
    {
        Task<string> EnhanceAsync(string text);
    }
}
