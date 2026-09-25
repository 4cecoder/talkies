# Developer Crash Simulation Module

This module allows developers to verify that crash diagnostics are written to local files without network transmission.

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

## Using the Module

Once enabled:

1. Restart the Talkies application.
2. Look for a "Developer" menu in the main window.
3. Click "Developer" > "Simulate Crash".
4. The application will throw a simulated exception, triggering the local crash logger.
5. Check `%LOCALAPPDATA%\Talkies\logs\crash.log` for the new entry.

## What Happens

- A `InvalidOperationException` with message "Simulated crash for testing local crash logging." is thrown.
- The unhandled-exception logger records it to the local `crash.log`.
- The diagnostic entry is stored locally and is never transmitted by Talkies.

## Testing

Use this to verify:
- Crash detection works
- Logs are written correctly
- UI remains stable during crash simulation

## Security Note

This module is only enabled when manually edited in the config file, ensuring it's not accidentally triggered in production.