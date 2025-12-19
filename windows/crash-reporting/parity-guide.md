# Crash Reporting and Analytics Parity Guide for macOS

This guide outlines how to implement crash reporting and analytics on macOS, following the Windows C# implementation with background monitor process.

## Implementation Approach

Create a similar `CrashReporter.cs` class in the macOS project, adapted for .NET/macOS specifics:

- **Log Files Location**: `~/Library/Logs/Talkies/` using `Environment.GetFolderPath(Environment.SpecialFolder.UserProfile) + "/Library/Logs/Talkies/"`
- **Crash Handling**: Use `AppDomain.CurrentDomain.UnhandledException` and `TaskScheduler.UnobservedTaskException` to save crash data to temp file
- **Background Monitor**: Run separate process to detect app crashes and send reports via HTTPS POST if enabled
- **Analytics**: Local event logging to JSON file, optional sending to endpoint

## macOS-Specific Considerations

- Ensure proper permissions for writing to user logs directory (may require entitlements)
- Integrate with macOS Crash Reporter for system-level crash dumps
- Use NSApplicationDelegate for app lifecycle events
- For advanced reporting, consider HockeyApp SDK (requires API key, optional)

## Crash Reporting Features

- **Data Included**: PC name, IP address, system specs (OS, processor count, etc.), exception details, full log dump
- **Secure Sending**: HTTPS POST to configurable endpoint (disabled by default)
- **Background Detection**: Monitor process survives app crashes to send reports
- **Normal Exit Handling**: Cleans up temp crash data on graceful shutdown, no false crash reports

## Analytics Implementation

- Track events with PC name, IP, timestamp
- Local JSON logging; optional endpoint sending
- Privacy: Disabled by default, user opt-in required

## Integration Steps

1. **Initialize CrashReporter** in AppDelegate or main startup:
```csharp
using Talkies.MacOS.Services;
var settings = LoadSettings(); // Load AppSettings with CrashReportingEnabled, CrashReportingEndpoint
var crashReporter = new CrashReporter(settings);
```

2. **Handle App Exit** in AppDelegate:
```csharp
public override void WillTerminate(NSNotification notification)
{
    crashReporter.OnNormalExit();
    Environment.ExitCode = 0;
}
```

3. **Track Events**:
```csharp
crashReporter.TrackEvent("app_started");
```

4. **Modify Main Method** for Monitor Mode:
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

5. **Start Monitor** in CrashReporter constructor:
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

## Testing

- Unit tests for CrashReporter methods
- Integration tests for monitor process and HTTP sending
- Test normal vs crash exits

## Free Crash Reporting Options (No API Keys Required)

1. **Local Logging Only**: Save crash dumps and logs locally for manual review
2. **Custom Webhook**: Send crash data to a self-hosted endpoint (requires server setup)
3. **GitHub Issues API**: Use GitHub's API to create issues from crashes (requires token, but can be user-provided)