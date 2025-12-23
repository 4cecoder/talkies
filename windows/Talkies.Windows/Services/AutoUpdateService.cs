using NetSparkleUpdater;
using NetSparkleUpdater.SignatureVerifiers;
using NetSparkleUpdater.UI.WPF;
using System.Reflection;
using Talkies.Windows.Models;

namespace Talkies.Windows.Services
{
    public class AutoUpdateService
    {
        private SparkleUpdater? _sparkle;
        private readonly AppSettings _settings;
        private readonly string _appcastUrl;

        public AutoUpdateService(AppSettings settings)
        {
            _settings = settings;

            // Determine appcast URL based on update channel
            _appcastUrl = _settings.UpdateChannel switch
            {
                "beta" => "https://github.com/yourorg/talkies/releases/latest/download/appcast-win-beta.xml",
                "nightly" => "https://github.com/yourorg/talkies/releases/latest/download/appcast-win-nightly.xml",
                _ => "https://github.com/yourorg/talkies/releases/latest/download/appcast-win.xml"
            };
        }

        public AppSettings Settings => _settings;

        public void Initialize()
        {
            // Get public key from environment variable or settings
            var publicKey = Environment.GetEnvironmentVariable("AUTO_UPDATE_PUBLIC_KEY") ?? _settings.AutoUpdatePublicKey ?? "";
            if (string.IsNullOrEmpty(publicKey))
            {
                Logger.Warn("Auto-update public key not configured. Updates will be disabled.");
                return;
            }

            _sparkle = new SparkleUpdater(
                _appcastUrl,
                new Ed25519Checker(NetSparkleUpdater.Enums.SecurityMode.Strict, publicKey)
            )
            {
                UIFactory = new UIFactory(),
                RelaunchAfterUpdate = true,
                CustomInstallerArguments = "/SILENT /CLOSEAPPLICATIONS",
                CheckServerFileName = false
            };

            // Check for updates silently on startup if enabled
            if (_settings.AutoCheckForUpdates)
            {
                _sparkle.StartLoop(true, false);
            }
        }

        public void CheckForUpdatesAtUserRequest()
        {
            _sparkle?.CheckForUpdatesAtUserRequest();
        }

        public void SetUpdateChannel(string channel)
        {
            _settings.UpdateChannel = channel;
            // TODO: Save settings and restart updater with new URL
        }

        public void Dispose()
        {
            _sparkle?.Dispose();
        }
    }
}