using System.Collections.Generic;

namespace Talkies.Windows.Plugins
{
    public static class PluginManager
    {
        public static ITextEnhancer? TextEnhancer { get; set; }
        public static ITtsSynthesizer? TtsSynthesizer { get; set; }

        public static IEnumerable<IPlugin> All()
        {
            if (TextEnhancer != null) yield return TextEnhancer;
            if (TtsSynthesizer != null) yield return TtsSynthesizer;
        }
    }
}
