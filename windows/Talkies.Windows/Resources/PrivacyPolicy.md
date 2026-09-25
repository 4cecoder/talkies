# Local crash diagnostics

Talkies does not send crash reports, analytics, audio, or transcript text to a server. On Windows, unhandled exception details are written locally to `%LOCALAPPDATA%\Talkies\logs\crash.log`, with two rotated copies retained. These diagnostic files may include exception messages and stack traces. You can inspect or delete them at any time.
