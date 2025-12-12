# Windows Implementation Integration Guide

## Overview

This guide helps developers integrate the enhanced Windows Talkies implementation into their applications.

## Prerequisites

- Visual Studio 2022 or later
- .NET 8.0 or later
- NAudio NuGet package
- Whisper.net NuGet package
- Windows 10 or later

## Project Structure

```
talkies_windows/
??? talkies.windows/
?   ??? services/
?   ?   ??? AudioRecorder.cs
?   ?   ??? TranscriptionService.cs
?   ?   ??? WhisperNetTranscriptionService.cs
?   ?   ??? Logger.cs
?   ?   ??? TextInjector.cs
?   ??? plugins/
?   ?   ??? OllamaEnhancer.cs
?   ??? models/
?   ?   ??? TranscriptSegment.cs
?   ??? viewmodels/
?       ??? MainViewModel.cs
??? models/                                # GGML models downloaded here
```


## Step-by-Step Integration

### Step 1: Install NuGet Dependencies

Add to your project:

```powershell
Install-Package NAudio
Install-Package Whisper.net
```

### Step 2: Reference the Services

In your code, add using statements:

```csharp
using Talkies.Windows.Services;
using Talkies.Windows.Models;
using Talkies.Windows.Plugins;
```

### Step 3: Initialize Audio Recording

```csharp
// Create audio recorder instance
IAudioRecorder recorder = new AudioRecorder();

// Subscribe to events
recorder.RecordingCompleted += (sender, args) =>
{
    Logger.Info($"Recording saved to {args.FilePath}");
};

recorder.LevelChanged += (sender, level) =>
{
    Console.WriteLine($"Audio level: {level:P}");
};

// Start recording on default device
recorder.Start();

// Or specify device ID
recorder.Start(deviceId: "device-id-here");

// Stop recording when ready
recorder.Stop();
```

### Step 4: Transcribe Audio

```csharp
// Create transcription service
ITranscriptionService transcriber = new WhisperNetTranscriptionService();

// Create decoding options (optional)
var decodingOptions = new DecodingOptions
{
    Temperature = 0.0f,
    TemperatureIncrementOnFallback = 0.2f,
    TemperatureFallbackCount = 5,
    SampleLength = 224,
    TopK = 5,
    UsePrefillPrompt = true,
    UsePrefillCache = true,
    SkipSpecialTokens = true,
    WithoutTimestamps = false,
    Verbose = false
};

// Transcribe audio file
var result = await transcriber.TranscribeAsync(
    filePath: "audio.wav",
    model: "base",  // tiny, base, small, medium, large
    language: "en",  // auto-detected if "auto"
    vadEnabled: true,
    filterEnabled: true,
    decodingOptions: decodingOptions  // Optional
);

// Access results
Console.WriteLine($"Text: {result.Text}");
Console.WriteLine($"Segments: {result.Segments.Count}");
Console.WriteLine($"Total Words: {result.TotalWords}");
Console.WriteLine($"Duration: {result.DurationSeconds:F1}s");
Console.WriteLine($"WPM: {result.WordsPerMinute}");
```

### Step 5: Export Transcript

```csharp
// Export in different formats
string vttContent = transcriber.ExportVtt(result.Segments);
string srtContent = transcriber.ExportSrt(result.Segments);
string txtContent = transcriber.ExportTxt(result.Segments);

// Save to files
File.WriteAllText("transcript.vtt", vttContent);
File.WriteAllText("transcript.srt", srtContent);
File.WriteAllText("transcript.txt", txtContent);

// Or use the built-in VTT from result
File.WriteAllText("transcript.vtt", result.Vtt);
```

### Step 6: Enhance Transcript with Ollama

```csharp
// Ensure Ollama is running: http://localhost:11434

// Create enhancer
var enhancer = new OllamaEnhancer(
    endpoint: "http://localhost:11434",
    model: "llama2"  // or any Ollama model
);

// Configure enhancement mode
enhancer.Mode = EnhancementMode.Grammar;  // or Technical, Concise, Creative, Companion
enhancer.Temperature = 0.3f;  // Adjust for creativity
enhancer.TopP = 0.9f;

// Enhance the transcript
string enhancedText = await enhancer.EnhanceAsync(result.Text);
Console.WriteLine($"Original: {result.Text}");
Console.WriteLine($"Enhanced: {enhancedText}");

// Or use custom system prompt
string customPrompt = "Rewrite this as a professional report.";
string customResult = await enhancer.EnhanceWithCustomPromptAsync(
    result.Text,
    customPrompt
);
```

### Step 7: Inject Text into Active Application

```csharp
// Check if text injection is possible
if (!TextInjector.CanInjectText())
{
    Console.WriteLine("Cannot inject text. Window not accessible.");
    Console.WriteLine(TextInjector.GetAccessibilityInfo());
    return;
}

// Safe injection with error handling
if (!TextInjector.TryInsertText(result.Text))
{
    Logger.Error("Text injection failed");
}
else
{
    Logger.Success("Text injected successfully");
}

// Injection with per-character delay (for slow applications)
TextInjector.TryInsertText(result.Text, delayMs: 50);

// Or use throwing version (not recommended)
try
{
    TextInjector.InsertText(result.Text);
}
catch (Exception ex)
{
    Logger.Error($"Injection failed: {ex.Message}");
}
```

### Step 8: Configure Logging

```csharp
// Subscribe to log events
Logger.LogMessage += (sender, args) =>
{
    Console.WriteLine($"[{args.Level}] {args.Timestamp:HH:mm:ss.fff} - {args.Message}");
};

// Use logging in your code
Logger.Status("Processing audio...");
Logger.OperationStart("Transcription");
try
{
    var result = await transcriber.TranscribeAsync(...);
    Logger.OperationComplete("Transcription");
    Logger.Success($"Transcription complete: {result.TotalWords} words");
}
catch (Exception ex)
{
    Logger.OperationFailed("Transcription", ex.Message);
}

// Get log file path
string logPath = Logger.GetLogPath();
Console.WriteLine($"Logs saved to: {logPath}");

// Clear log if needed
Logger.ClearLog();
```

## Complete Example: Full Workflow

```csharp
using Talkies.Windows.Services;
using Talkies.Windows.Models;
using Talkies.Windows.Plugins;

public class TalkiesExample
{
    public async Task RunFullWorkflow()
    {
        Logger.Status("Initializing Talkies...");

        // 1. Record audio
        Logger.OperationStart("Audio Recording");
        var recorder = new AudioRecorder();
        recorder.RecordingCompleted += OnRecordingCompleted;
        recorder.Start();
        
        Console.WriteLine("Recording... Press Enter to stop");
        Console.ReadLine();
        
        recorder.Stop();
        // Wait for RecordingCompleted event...
    }

    private async void OnRecordingCompleted(object? sender, RecordingCompletedEventArgs e)
    {
        Logger.OperationStart("Transcription");
        
        try
        {
            // 2. Transcribe
            ITranscriptionService transcriber = new WhisperNetTranscriptionService();
            
            var options = new DecodingOptions 
            { 
                Temperature = 0.0f,
                Verbose = true
            };
            
            var result = await transcriber.TranscribeAsync(
                e.FilePath,
                "base",
                "en",
                true,
                true,
                options
            );
            
            Logger.OperationComplete("Transcription");
            Logger.Success($"Transcribed: {result.TotalWords} words in {result.DurationSeconds:F1}s ({result.WordsPerMinute} WPM)");

            // 3. Enhance (if available)
            if (IsOllamaAvailable())
            {
                Logger.OperationStart("Enhancement");
                var enhancer = new OllamaEnhancer("http://localhost:11434", "llama2");
                enhancer.Mode = EnhancementMode.Technical;
                string enhanced = await enhancer.EnhanceAsync(result.Text);
                Logger.OperationComplete("Enhancement");
                
                result.Text = enhanced;
            }

            // 4. Export
            Logger.OperationStart("Export");
            File.WriteAllText("transcript.vtt", result.Vtt);
            File.WriteAllText("transcript.srt", transcriber.ExportSrt(result.Segments));
            File.WriteAllText("transcript.txt", transcriber.ExportTxt(result.Segments));
            Logger.OperationComplete("Export");

            // 5. Inject into active app
            if (TextInjector.CanInjectText())
            {
                Logger.OperationStart("Text Injection");
                if (TextInjector.TryInsertText(result.Text))
                {
                    Logger.OperationComplete("Text Injection");
                }
                else
                {
                    Logger.OperationFailed("Text Injection", "SendInput failed");
                }
            }

            Logger.Success("Workflow complete!");
        }
        catch (Exception ex)
        {
            Logger.OperationFailed("Workflow", ex.Message);
        }
    }

    private bool IsOllamaAvailable()
    {
        try
        {
            using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(1) };
            var response = client.GetAsync("http://localhost:11434/api/tags").Result;
            return response.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }
}
```

## Configuration Options

### Audio Recording

```csharp
var recorder = new AudioRecorder();

// Default device
recorder.Start();

// Specific device
var devices = new AudioDeviceService().GetCaptureDevices();
recorder.Start(devices[0].Id);
```

### Transcription Models

| Model | Size | Speed | Accuracy | VRAM | Best For |
|-------|------|-------|----------|------|----------|
| tiny | 39MB | ⚡⚡⚡ | Low | 1GB | Demo, testing |
| base | 74MB | ⚡⚡ | Medium | 1GB | Real-time |
| small | 244MB | ⚡ | High | 2GB | Offline |
| medium | 769MB | 🐌 | Very High | 5GB | Archival |
| large | 2.9GB | 🐌🐌 | Excellent | 10GB | Batch |

### Enhancement Modes

```csharp
enum EnhancementMode
{
    Grammar,      // Default: Fix grammar and clarity
    Technical,    // For code and technical docs
    Concise,      // For business writing
    Creative,     // For narrative content
    Companion     // For warm, conversational tone
}
```

### Decoding Options Tuning

**For Best Accuracy:**
```csharp
var options = new DecodingOptions
{
    Temperature = 0.0f,           // Deterministic
    TemperatureFallbackCount = 5, // Retry with higher temps
    TopK = 10,                    // Wider beam search
    UsePrefillPrompt = true,      // Use cached prompts
    WithoutTimestamps = false     // Include timing
};
```

**For Speed:**
```csharp
var options = new DecodingOptions
{
    Temperature = 0.5f,
    TemperatureFallbackCount = 1,
    TopK = 5,
    SampleLength = 112,           // Smaller chunks
    Verbose = false
};
```

**For Balanced Performance:**
```csharp
var options = new DecodingOptions
{
    Temperature = 0.3f,
    TemperatureFallbackCount = 3,
    TopK = 5,
    Verbose = false
};
```

## Troubleshooting

### Model Download Issues

**Problem:** Download fails or is very slow

```csharp
// Check internet connection
try
{
    using var client = new HttpClient();
    var response = await client.GetAsync("https://huggingface.co");
    Logger.Info($"HuggingFace accessible: {response.IsSuccessStatusCode}");
}
catch (Exception ex)
{
    Logger.Error($"Cannot reach HuggingFace: {ex.Message}");
}

// Monitor download progress in logs
Logger.GetLogPath();  // Check the log file for "Download progress" messages
```

### Text Injection Issues

```csharp
// Diagnose the problem
string diagnostics = TextInjector.GetAccessibilityInfo();
Console.WriteLine(diagnostics);

// Try with delay
if (!TextInjector.TryInsertText(text, delayMs: 50))
{
    // Try with more delay for slow applications
    TextInjector.TryInsertText(text, delayMs: 100);
}
```

### Ollama Enhancement Issues

```csharp
// Verify Ollama is running
try
{
    var enhancer = new OllamaEnhancer("http://localhost:11434", "llama2");
    string test = await enhancer.EnhanceAsync("test");
    Logger.Success("Ollama is working");
}
catch (Exception ex)
{
    Logger.Error($"Ollama not available: {ex.Message}");
}
```

### Audio Recording Issues

```csharp
// Check available devices
var deviceService = new AudioDeviceService();
var devices = deviceService.GetCaptureDevices();

foreach (var device in devices)
{
    Logger.Info($"Device: {device.Name} (ID: {device.Id})");
}

// Start with specific device
recorder.Start(devices[0].Id);
```

## Performance Tuning

### For Real-Time Transcription

```csharp
var options = new DecodingOptions
{
    Temperature = 0.5f,
    TopK = 5,
    SampleLength = 112
};

var result = await transcriber.TranscribeAsync(
    audioFile, "tiny", "auto", true, true, options);
```

### For Batch Processing

```csharp
var options = new DecodingOptions
{
    Temperature = 0.0f,
    TopK = 10,
    SampleLength = 224,
    UsePrefillPrompt = true,
    Verbose = true
};

foreach (var file in audioFiles)
{
    var result = await transcriber.TranscribeAsync(
        file, "large", "auto", true, true, options);
    // Process result...
}
```

### For Low-Resource Systems

```csharp
var options = new DecodingOptions
{
    Temperature = 0.7f,
    TopK = 3,
    SampleLength = 100
};

var result = await transcriber.TranscribeAsync(
    audioFile, "tiny", "auto", false, false, options);
```

## Best Practices

1. **Always check capabilities before using features**
   ```csharp
   if (TextInjector.CanInjectText()) { /* ... */ }
   ```

2. **Use try-catch for external services**
   ```csharp
   try
   {
       var enhanced = await enhancer.EnhanceAsync(text);
   }
   catch (Exception ex)
   {
       Logger.Error($"Enhancement failed: {ex.Message}");
       // Use original text as fallback
   }
   ```

3. **Monitor logging for debugging**
   ```csharp
   Logger.LogMessage += (s, args) => DebugWindow.Log($"{args.Level}: {args.Message}");
   ```

4. **Clean up resources properly**
   ```csharp
   using var recorder = new AudioRecorder();
   using var transcriber = new WhisperNetTranscriptionService();
   ```

5. **Provide user feedback during long operations**
   ```csharp
   Logger.Status("Downloading model... This may take a few minutes");
   // User sees progress in logs
   ```

## API Reference

### Logger
- `Logger.Debug(message)` - Debug output
- `Logger.Info(message)` - Informational
- `Logger.Warn(message)` - Warnings
- `Logger.Error(message)` - Errors
- `Logger.Status(message)` - User status
- `Logger.Success(message)` - Success confirmation
- `Logger.OperationStart(name)` - Operation beginning
- `Logger.OperationComplete(name)` - Operation succeeded
- `Logger.OperationFailed(name, reason)` - Operation failed
- `Logger.LogMessage` - Event for UI subscription
- `Logger.GetLogPath()` - Get log file location
- `Logger.ClearLog()` - Clear log file

### TextInjector
- `TextInjector.InsertText(text)` - Inject text (throws)
- `TextInjector.TryInsertText(text, delayMs)` - Safe inject
- `TextInjector.CanInjectText()` - Permission check
- `TextInjector.GetAccessibilityInfo()` - Diagnostic info

### TranscriptionService
- `TranscribeAsync(...)` - Transcribe audio
- `ExportVtt(segments)` - WebVTT format
- `ExportSrt(segments)` - SubRip format
- `ExportTxt(segments)` - Plain text format

### OllamaEnhancer
- `EnhanceAsync(text)` - Enhance with current mode
- `EnhanceWithCustomPromptAsync(text, prompt)` - Custom prompt
- `Mode` - Get/set enhancement mode
- `Temperature` - Adjust creativity
- `TopP` - Nucleus sampling parameter

### DecodingOptions Properties
All are optional with sensible defaults:
- `Temperature` - Sampling randomness
- `TemperatureIncrementOnFallback` - Fallback step
- `TemperatureFallbackCount` - Retry count
- `SampleLength` - Audio chunk size
- `TopK` - Beam width
- `UsePrefillPrompt` - Enable prompt cache
- `UsePrefillCache` - Cache mode
- `SkipSpecialTokens` - Filter special chars
- `WithoutTimestamps` - Exclude timing
- `Verbose` - Debug output

## Next Steps

1. Review the **WINDOWS_ENHANCEMENTS.md** for detailed documentation
2. Check **WINDOWS_QUICK_REFERENCE.md** for quick lookups
3. Examine example implementations in `ViewModels/MainViewModel.cs`
4. Run tests in `talkies_windows/talkies.windows.tests/` project
5. Deploy to production with monitoring

## Support

- **Documentation**: `WINDOWS_ENHANCEMENTS.md`
- **Quick Reference**: `WINDOWS_QUICK_REFERENCE.md`
- **Implementation Summary**: `IMPLEMENTATION_SUMMARY.md`
- **Log File**: Check `talkies_win.log` in application directory
- **Issues**: Review Logger output and error messages

## License

Same as Talkies project - MIT License

---

**Last Updated**: December 2024
**Version**: 1.0
**Status**: Production Ready