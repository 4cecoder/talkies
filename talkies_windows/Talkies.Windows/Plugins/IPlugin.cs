namespace Talkies.Windows.Plugins
{
    public interface IPlugin
    {
        string Name { get; }
        bool IsEnabled { get; set; }
    }
}
