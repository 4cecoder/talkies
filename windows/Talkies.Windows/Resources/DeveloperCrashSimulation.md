# Developer Crash Simulation Module

This module allows developers to test the crash reporting functionality by simulating crashes.

## Enabling the Module

To enable the crash simulation module, manually edit the `config.json` file in your Talkies settings directory (usually `~/.talkies/config.json` or `%USERPROFILE%\.talkies\config.json`).

Add the following key to the JSON:

```json
{
  "TalkiesTeamConfig": {
    "EnableSimulateCrashesModule": true
  }
}
```

The full config might look like:

```json
{
  "Model": "tiny",
  "Language": "auto",
  "CrashReportingEnabled": true,
  "CrashReportingEndpoint": "https://your-endpoint.com/crash",
  "CrashReportingPrivacyAccepted": true,
  "TalkiesTeamConfig": {
    "EnableSimulateCrashesModule": true
  }
}
```

## Using the Module

Once enabled:

1. Restart the Talkies application.
2. Look for a "Developer" menu in the main window.
3. Click "Developer" > "Simulate Crash".
4. The application will throw a simulated exception, triggering the crash reporting process.
5. Check the crash logs and monitor if the report is sent (if endpoint is configured).

## What Happens

- A `InvalidOperationException` with message "Simulated crash for testing crash reporting." is thrown.
- The crash reporter catches it and logs to `crash.log`.
- If crash reporting is enabled and endpoint is valid, the background monitor will send the report after app termination.
- Normal exit handling ensures simulated crashes don't affect real usage.

## Testing

Use this to verify:
- Crash detection works
- Logs are written correctly
- Background monitor sends reports
- Analytics tracking (if enabled)
- UI remains stable during crash simulation

## Security Note

This module is only enabled when manually edited in the config file, ensuring it's not accidentally triggered in production.