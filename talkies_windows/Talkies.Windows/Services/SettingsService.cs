using System;
using System.IO;
using Newtonsoft.Json;
using Talkies.Windows.Models;

namespace Talkies.Windows.Services
{
    public class SettingsService
    {
        private readonly string _path;

        public SettingsService()
        {
            var appdata = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            var dir = Path.Combine(appdata, "Talkies");
            Directory.CreateDirectory(dir);
            _path = Path.Combine(dir, "talkies_settings.json");
        }

        public AppSettings Load()
        {
            try
            {
                if (File.Exists(_path))
                {
                    var json = File.ReadAllText(_path);
                    var settings = JsonConvert.DeserializeObject<AppSettings>(json);
                    if (settings != null) return settings;
                }
            }
            catch
            {
                // ignore, fall back to defaults
            }
            return new AppSettings();
        }

        public void Save(AppSettings settings)
        {
            try
            {
                var json = JsonConvert.SerializeObject(settings, Formatting.Indented);
                File.WriteAllText(_path, json);
            }
            catch
            {
                // ignore errors silently for now
            }
        }
    }
}
