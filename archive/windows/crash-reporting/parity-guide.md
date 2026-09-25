# Crash Reporting and Analytics Parity Guide for macOS

This guide outlines how to implement crash reporting and analytics on macOS, following the Windows C# implementation with all latest features.

## Implementation Approach

Create a similar `CrashReporter.cs` class in the macOS project, adapted for .NET/macOS specifics:

- **Log Files Location**: `~/Library/Logs/Talkies/` using `Environment.GetFolderPath(Environment.SpecialFolder.UserProfile) + "/Library/Logs/Talkies/"`
- **Crash Handling**: Use `AppDomain.CurrentDomain.UnhandledException` and `TaskScheduler.UnobservedTaskException` to save crash data to temp file
- **Background Monitor**: Run separate process to detect app crashes and send reports via HTTPS POST if enabled
- **Analytics**: Local event logging to JSON file with size limits, optional sending to validated endpoint
- **Privacy Consent**: One-time MessageBox prompt on first launch for consent, persisted in settings

## macOS-Specific Considerations

- Ensure proper permissions for writing to user logs directory (may require entitlements)
- Integrate with macOS Crash Reporter for system-level crash dumps
- Use NSApplicationDelegate for app lifecycle events
- For advanced reporting, consider HockeyApp SDK (requires API key, optional)
- Adapt UI for macOS (NSAlert for consent dialog)

## Crash Reporting Features

- **Data Included**: PC name, IP address, system specs (OS, processor count, etc.), exception details, stack trace, full log dump
- **Secure Sending**: HTTPS POST to configurable, validated endpoint (disabled by default)
- **Background Detection**: Monitor process survives app crashes to send reports only on abnormal exits
- **Normal Exit Handling**: Cleans up temp crash data on graceful shutdown, no false crash reports
- **Resource Management**: HttpClient disposal, log file rotation at 10MB

## Analytics Implementation

- Track events with PC name, IP, timestamp, data
- Local JSON logging with size limits; optional secure endpoint sending
- Privacy: One-time consent required, GDPR/CCPA compliant

## Integration Steps

1. **Update AppSettings.cs**:
```csharp
public bool CrashReportingEnabled { get; set; } = false;
public string CrashReportingEndpoint { get; set; } = string.Empty;
public bool CrashReportingPrivacyAccepted { get; set; } = false;
public TalkiesTeamConfig TalkiesTeamConfig { get; set; } = new();
```

2. **Initialize CrashReporter** in AppDelegate or main startup:
```csharp
using Talkies.MacOS.Services;
var settings = LoadSettings();
if (!settings.CrashReportingPrivacyAccepted)
{
    // Show NSAlert with privacy policy and ask for consent
    var alert = new NSAlert();
    alert.MessageText = "Privacy Consent";
    alert.InformativeText = File.ReadAllText("Resources/PrivacyPolicy.md") + "\n\nDo you consent to submit crash reports?";
    alert.AddButton("Yes");
    alert.AddButton("No");
    var result = alert.RunModal();
    settings.CrashReportingPrivacyAccepted = result == 1000; // Yes button
    if (settings.CrashReportingPrivacyAccepted) settings.CrashReportingEnabled = true;
    SaveSettings(settings);
}
var crashReporter = new CrashReporter(settings);
```

3. **Handle App Exit** in AppDelegate:
```csharp
public override void WillTerminate(NSNotification notification)
{
    crashReporter.OnNormalExit();
    Environment.ExitCode = 0;
}
```

4. **Track Events**:
```csharp
crashReporter.TrackEvent("app_started");
```

5. **Modify Main Method** for Monitor Mode:
```csharp
[STAThread]
public static void Main(string[] args)
{
    if (args.Length > 1 && args[0] == "monitor" && int.TryParse(args[1], out int pid))
    {
        CrashReporter.RunMonitorAsync(pid, settings).Wait();
        return;
    }
    NSApplication.Main(args);
}
```

6. **Start Monitor** in CrashReporter constructor:
```csharp
private void StartMonitor()
{
    Process.Start(new ProcessStartInfo
    {
        FileName = NSBundle.MainBundle.ExecutablePath,
        Arguments = $"monitor {Process.GetCurrentProcess().Id}",
        UseShellExecute = false,
        CreateNoWindow = true
    });
}
```

7. **Add Developer Menu** (if TalkiesTeamConfig.EnableSimulateCrashesModule):
```csharp
// In MainWindow, add NSMenuItem for Simulate Crash
var simulateItem = new NSMenuItem("Simulate Crash", (s, e) => throw new InvalidOperationException("Simulated crash"));
developerMenu.AddItem(simulateItem);
```

## Testing

- Unit tests for CrashReporter methods (endpoint validation, log limits, etc.)
- Integration tests for monitor process and HTTP sending
- Test normal vs crash exits, privacy consent workflow
- Test developer simulation module

## Free Crash Reporting Options (No API Keys Required)

1. **Local Logging Only**: Save crash dumps and logs locally for manual review
2. **Custom Webhook**: Send crash data to a self-hosted endpoint (requires server setup)
3. **GitHub Issues API**: Use GitHub's API to create issues from crashes (requires token, but can be user-provided)