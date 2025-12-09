# Windows Implementation - Quick Reference Guide

## 1. Dynamic Model Download

**Automatic model management - no manual configuration needed!**

```csharp
// Models are automatically downloaded from HuggingFace if missing
var result = await transcriber.TranscribeAsync(
    filePath: "audio.wav",
    model: "base",  // Automatically downloads if not cached
    language: "en",
    vadEnabled: true,
    filterEnabled: true
);
```

**Supported Models:**
- `tiny` (39M) - Fastest, lower accuracy
- `base` (74M) - Good balance
- `small` (244M) - Better accuracy
- `medium` (769M) - High accuracy
- `large` (2.9GB) - Highest accuracy

**Environment Variable Override:**
```csharp
// Set TALKIES_MODEL_PATH to use a custom model location
Environment.SetEnvironmentVariable("TALKIES_MODEL_PATH", "C:\\Models\\ggml-base.bin");
```

---

## 2. Export Formats

**Support for VTT, SRT, and TXT export formats**

```csharp
var result = await transcriber.TranscribeAsync(...);

// Export in different formats
string vtt = transcriber.ExportVtt(result.Segments);
string srt = transcriber.ExportSrt(result.Segments);
string txt = transcriber.ExportTxt(result.Segments);

// Save to files
File.WriteAllText("transcript.vtt", vtt);
File.WriteAllText("transcript.srt", srt);
File.WriteAllText("transcript.txt", txt);
```

**Format Comparison:**
| Format | Use Case | Example |
|--------|----------|---------|
| VTT | Web video subtitles | YouTube, HTML5 video |
| SRT | Video editor subtitles | Adobe, Final Cut, DaVinci |
| TXT | Plain text transcript | Processing, analysis |

---

## 3. Decoding Options

**Fine-tune transcription quality and speed**

```csharp
var options = new DecodingOptions
{
    Temperature = 0.0f,              // 0.0 = deterministic (best accuracy)
    TemperatureIncrementOnFallback = 0.2f,
    TemperatureFallbackCount = 5,
    SampleLength = 224,              // Audio sample length
    TopK = 5,                        // Beam search parameter
    UsePrefillPrompt = true,         // Use prompt cache
    UsePrefillCache = true,
    SkipSpecialTokens = true,
    WithoutTimestamps = false,       // Include timing info
    Verbose = false
};

var result = await transcriber.TranscribeAsync(
    filePath: "audio.wav",
    model: "base",
    language: "en",
    vadEnabled: true,
    filterEnabled: true,
    decodingOptions: options  // NEW parameter
);
```

**Temperature Tuning:**
- `0.0f` - Deterministic, most consistent
- `0.1-0.3f` - Slight variation, good balance
- `0.5f` - More creative, less accurate
- `1.0f+` - Very random, unreliable

---

## 4. Enhancement Modes

**5 specialized LLM enhancement modes**

```csharp
var enhancer = new OllamaEnhancer("http://localhost:11434", "llama2");

// Mode 1: Grammar & Clarity (DEFAULT)
enhancer.Mode = EnhancementMode.Grammar;
var cleaned = await enhancer.EnhanceAsync(text);
// Fixes grammar, spelling, clarity

// Mode 2: Technical Writing
enhancer.Mode = EnhancementMode.Technical;
var technical = await enhancer.EnhanceAsync(text);
// Code comments, documentation style

// Mode 3: Concise & Professional
enhancer.Mode = EnhancementMode.Concise;
var concise = await enhancer.EnhanceAsync(text);
// Remove filler, business-ready

// Mode 4: Creative Enhancement
enhancer.Mode = EnhancementMode.Creative;
var creative = await enhancer.EnhanceAsync(text);
// More engaging, flowing narrative

// Mode 5: AI Companion (NEW)
enhancer.Mode = EnhancementMode.Companion;
enhancer.Temperature = 0.7f;  // More creative
var friendly = await enhancer.EnhanceAsync(text);
// Warm, conversational tone
```

**Custom System Prompt:**
```csharp
string customPrompt = "You are a Shakespearean scholar. Rewrite this text as Shakespeare would.";
var result = await enhancer.EnhanceWithCustomPromptAsync(text, customPrompt);
```

**Temperature & Creativity:**
```csharp
enhancer.Temperature = 0.3f;  // Conservative, less creative
enhancer.Temperature = 0.7f;  // Balanced
enhancer.Temperature = 1.0f;  // Very creative, more variation
enhancer.TopP = 0.9f;         // Nucleus sampling parameter
```

---

## 5. Enhanced Logging

**Better visibility with color-coded logs**

```csharp
// Basic logging
Logger.Debug("Detailed info");
Logger.Info("General info");
Logger.Warn("Warning");
Logger.Error("Error");

// User-friendly messages
Logger.Status("Processing...");
Logger.Success("Completed successfully!");

// Operation tracking
Logger.OperationStart("Transcription");
try {
    // Do work
    Logger.OperationComplete("Transcription");
} catch (Exception ex) {
    Logger.OperationFailed("Transcription", ex.Message);
}
```

**Subscribe to Log Events:**
```csharp
Logger.LogMessage += (sender, args) =>
{
    Console.WriteLine($"[{args.Level}] {args.Message}");
};
```

**Log File Management:**
```csharp
string logPath = Logger.GetLogPath();
// C:\...\bin\Debug\net8.0-windows\talkies_win.log

Logger.ClearLog();  // Clear log file
```

**Console Output Colors:**
- Debug = Gray
- Info = White
- Warn = Yellow
- Error = Red

---

## 6. Text Injection with Accessibility

**Safe text insertion into active window**

```csharp
// Safe method returns bool
if (TextInjector.TryInsertText(text))
{
    Logger.Success("Text injected");
}
else
{
    Logger.Error("Injection failed");
}

// With per-character delay (for slow apps)
TextInjector.TryInsertText(text, delayMs: 50);

// Check if injection will work
if (TextInjector.CanInjectText())
{
    TextInjector.InsertText(text);
}

// Get accessibility info
string info = TextInjector.GetAccessibilityInfo();
/*
TextInjector Accessibility Information:
- IsAdmin: false
- CanInjectText: true
- Method: Windows SendInput API (UNICODE flag)
- Note: Some applications may require enabling...
*/
```

**Troubleshooting:**
- If injection fails on UWP apps, enable "Use the clipboard to paste" in Accessibility settings
- Some Electron apps need 10-50ms delay between characters
- Running as admin may help with restricted applications

---

## 7. Statistics

**Automatic calculation of transcript metrics**

```csharp
var result = await transcriber.TranscribeAsync(...);

// Access statistics
int totalWords = result.TotalWords;           // Total word count
double duration = result.DurationSeconds;    // Audio duration in seconds
int wpm = result.WordsPerMinute;             // Calculated words per minute

Console.WriteLine($"Words: {totalWords}, Duration: {duration:F1}s, WPM: {wpm}");
```

---

## 8. Complete Workflow Example

```csharp
public async Task TranscribeAndProcessAudio(string audioFile)
{
    Logger.OperationStart("Audio processing");
    
    try
    {
        // 1. Transcribe with custom decoding options
        var decodingOptions = new DecodingOptions 
        { 
            Temperature = 0.0f,
            Verbose = false 
        };
        
        var result = await transcriber.TranscribeAsync(
            filePath: audioFile,
            model: "base",
            language: "en",
            vadEnabled: true,
            filterEnabled: true,
            decodingOptions: decodingOptions);
        
        Logger.Success($"Transcription complete: {result.TotalWords} words, {result.WordsPerMinute} WPM");
        
        // 2. Enhance with LLM
        Logger.OperationStart("Text enhancement");
        var enhancer = new OllamaEnhancer("http://localhost:11434", "llama2");
        enhancer.Mode = EnhancementMode.Technical;
        string enhancedText = await enhancer.EnhanceAsync(result.Text);
        Logger.OperationComplete("Text enhancement");
        
        // 3. Export in multiple formats
        File.WriteAllText("output.vtt", result.Vtt);
        File.WriteAllText("output.srt", transcriber.ExportSrt(result.Segments));
        File.WriteAllText("output.txt", transcriber.ExportTxt(result.Segments));
        Logger.Success("Exports saved");
        
        // 4. Inject into active application
        Logger.OperationStart("Text injection");
        if (TextInjector.TryInsertText(enhancedText))
        {
            Logger.OperationComplete("Text injection");
        }
        else
        {
            Logger.Error("Could not inject text - check accessibility permissions");
        }
        
        Logger.OperationComplete("Audio processing");
    }
    catch (Exception ex)
    {
        Logger.OperationFailed("Audio processing", ex.Message);
    }
}
```

---

## Configuration Checklist

- [ ] Models directory exists: `%USERPROFILE%\.talkies\models\`
- [ ] Ollama running (if using enhancement): `http://localhost:11434`
- [ ] Model downloaded for Ollama (e.g., `ollama pull llama2`)
- [ ] Accessibility permissions granted for text injection
- [ ] Log file writable: `bin/Debug/net8.0-windows/talkies_win.log`

---

## Performance Tips

1. **Model Selection**: Use "tiny" or "base" for real-time transcription
2. **Temperature**: Set to 0.0f for fastest, most consistent results
3. **Text Injection Delays**: Try 0ms first, increase if characters are missed
4. **LLM Enhancement**: Lower temperature (0.3f) for faster processing
5. **Logging**: Disable verbose logging in production

---

## Backward Compatibility

All enhancements are backward compatible:
- Existing code using old signatures works unchanged
- New parameters are optional with sensible defaults
- Logger methods are additive (no breaking changes)
- Export methods are new additions to the interface

---

## Troubleshooting

**Model download fails:**
- Check internet connection
- Verify HuggingFace is accessible
- Check disk space for large models
- Check logs: `Logger.GetLogPath()`

**Text injection doesn't work:**
- Verify window is in focus
- Check `CanInjectText()` returns true
- Try increasing `delayMs` parameter
- Check UAC permissions

**Enhancement returns original text:**
- Verify Ollama is running
- Check model exists: `ollama list`
- Check endpoint URL
- Review error logs

**Transcription is slow:**
- Use "tiny" model for faster processing
- Disable verbose logging
- Set Temperature to 0.0f
- Check system resources (CPU/RAM)

---

## API Reference

### DecodingOptions Properties
- `Temperature` (0.0-1.0+): Sampling randomness
- `TemperatureIncrementOnFallback` (0.1-0.5): Fallback increment
- `TemperatureFallbackCount` (1-10): Retry attempts
- `SampleLength` (100-500): Audio chunk size
- `TopK` (1-10): Beam search width
- `UsePrefillPrompt` (bool): Enable prompt cache
- `UsePrefillCache` (bool): Cache management
- `SkipSpecialTokens` (bool): Filter special tokens
- `WithoutTimestamps` (bool): Include timing
- `Verbose` (bool): Debug output

### EnhancementMode Values
- `Grammar` - Default, grammar & clarity
- `Technical` - Code & technical docs
- `Concise` - Business writing
- `Creative` - Engaging narrative
- `Companion` - Warm conversation

### Logger Methods
- `Debug()`, `Info()`, `Warn()`, `Error()`
- `Status()`, `Success()`
- `OperationStart()`, `OperationComplete()`, `OperationFailed()`
- `ClearLog()`, `GetLogPath()`

### TextInjector Methods
- `TryInsertText(text, delayMs)` → bool
- `InsertText(text)` → void (throws)
- `CanInjectText()` → bool
- `GetAccessibilityInfo()` → string

### Export Methods
- `ExportVtt(segments)` → string
- `ExportSrt(segments)` → string
- `ExportTxt(segments)` → string

---

## Resources

- **Project README**: `talkies/README.md`
- **Full Documentation**: `talkies_windows/docs/WINDOWS_ENHANCEMENTS.md`
- **Windows Roadmap**: `./windows_roadmap.md`
- **GUI Guide**: `talkies/GUI.md`
