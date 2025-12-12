# Talkies Windows - Developer Guide

## Architecture Overview

### MVVM Architecture
The application follows the Model-View-ViewModel (MVVM) pattern:

```
┌─────────────────────────────────────────────┐
│           Views (XAML)                       │
│  MainWindow.xaml, Controls, etc.            │
├─────────────────────────────────────────────┤
│      ViewModels (Code-Behind Logic)         │
│  MainViewModel with INotifyPropertyChanged  │
├─────────────────────────────────────────────┤
│    Models, Services, Plugins (Data Layer)   │
│  TranscriptSegment, AppSettings, etc.      │
└─────────────────────────────────────────────┘
```

### Key Components

#### Services Layer
Services handle cross-cutting concerns:
- **AudioRecorder**: NAudio-based recording with device enumeration
- **WhisperNetTranscriptionService**: Audio transcription engine
- **AudioDeviceService**: Microphone device discovery
- **SettingsService**: JSON-based settings persistence
- **TranscriptExporter**: Multiple export format support
- **DialogHelper**: User feedback dialogs
- **HotkeyManager**: Global hotkey registration
- **TextInjector**: Windows text input injection
- **Logger**: Centralized logging

#### Plugins Layer
Plugin architecture for extensible functionality:
- **ILlmProvider**: Interface for LLM provider abstraction
- **OllamaEnhancer**: Ollama API implementation
- **LmStudioProvider**: OpenAI-compatible API implementation
- **PluginManager**: Plugin discovery and lifecycle
- **SystemSpeechTtsPlugin**: Windows text-to-speech

#### Models
Data structures for core functionality:
- **TranscriptSegment**: Single transcript entry with timing
- **AppSettings**: Application configuration
- **AudioDeviceInfo**: Microphone device information
- **RecordingCompletedEventArgs**: Recording completion data
- **LlmModel**: LLM model metadata

#### ViewModels
Business logic and state management:
- **MainViewModel**: Primary application state and commands
  - Implements INotifyPropertyChanged for data binding
  - Manages recording, transcription, and LLM operations
  - Coordinates between services and UI

#### UI Components
- **MainWindow**: Application shell and layout
- **WaveformVisualizer**: Real-time audio visualization control
- **BooleanToVisibilityConverter**: Standard WPF converter
- **BooleanInverterConverter**: Custom boolean negation converter

## Development Guidelines

### Coding Standards

#### Naming Conventions
- **Classes**: PascalCase (e.g., `AudioRecorder`, `WhisperNetTranscriptionService`)
- **Methods**: PascalCase (e.g., `StartRecording()`, `TranscribeAsync()`)
- **Properties**: PascalCase (e.g., `IsRecording`, `SelectedModel`)
- **Private Fields**: _camelCase (e.g., `_recorder`, `_isRecording`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_RECORDING_LENGTH`)
- **Parameters**: camelCase (e.g., `filePath`, `transcriptionService`)

#### Code Organization
- One class per file (except nested/internal classes)
- Logical grouping of related methods
- XML documentation on public members
- Using statements organized and sorted

#### Async/Await Patterns
```csharp
// Good: Async operation returns Task
private async Task FetchLlmModelsAsync()
{
    try
    {
        var models = await _currentLlmProvider.FetchModelsAsync();
        // Process results
    }
    catch (Exception ex)
    {
        Logger.Error($"Error: {ex.Message}");
    }
}

// Bad: Don't use Fire-and-Forget without void event handlers
private async void BadAsync() { } // Only acceptable for event handlers

// Good: AsyncRelayCommand for async command execution
FetchModelsCommand = new AsyncRelayCommand(_ => FetchLlmModelsAsync());
```

#### Error Handling
```csharp
// Use try-catch with specific exception handling
try
{
    var result = await service.DoSomethingAsync();
}
catch (HttpRequestException ex)
{
    Logger.Error($"Connection failed: {ex.Message}");
    DialogHelper.ShowError("Error", "Connection failed");
}
catch (JsonException ex)
{
    Logger.Error($"Invalid response: {ex.Message}");
    DialogHelper.ShowError("Error", "Invalid server response");
}
catch (Exception ex)
{
    Logger.Error($"Unexpected error: {ex.Message}");
    DialogHelper.ShowError("Error", "An unexpected error occurred");
}
```

### XAML Best Practices

#### Binding Patterns
```xml
<!-- One-way binding (read-only) -->
<TextBlock Text="{Binding Status}" />

<!-- Two-way binding (read-write) -->
<TextBox Text="{Binding SearchText, UpdateSourceTrigger=PropertyChanged}" />

<!-- Command binding -->
<Button Command="{Binding SaveCommand}" />

<!-- Converter binding -->
<Button Visibility="{Binding IsLoading, Converter={StaticResource BooleanToVisibilityConverter}}" />

<!-- Conditional disable during async -->
<Button Command="{Binding FetchCommand}" 
        IsEnabled="{Binding IsFetching, Converter={StaticResource BooleanInverterConverter}}" />
```

#### Resource Management
- Define converters in App.xaml for global access
- Use StaticResource for brushes and styles
- Avoid hardcoded colors; use theme resources
- Keep XAML clean and readable (max 120 chars per line)

### ViewModel Patterns

#### Property Declaration
```csharp
public string SelectedModel 
{ 
    get => _selectedModel; 
    set 
    { 
        _selectedModel = value; 
        OnPropertyChanged(); 
    } 
}
private string _selectedModel = "base";
```

#### ObservableCollection Usage
```csharp
// For list bindings that update UI
public ObservableCollection<string> Models { get; } = new(
    new[] { "tiny", "base", "small", "medium", "large" }
);

// Clear and repopulate
AvailableLlmModels.Clear();
foreach (var model in fetchedModels)
{
    AvailableLlmModels.Add(model);
}
```

#### Command Implementation
```csharp
// Synchronous command
public ICommand SaveCommand { get; }

public MainViewModel()
{
    SaveCommand = new RelayCommand(
        execute: _ => SaveVtt(),
        canExecute: _ => CanSave
    );
}

// Asynchronous command
public ICommand FetchModelsCommand { get; }

public MainViewModel()
{
    FetchModelsCommand = new AsyncRelayCommand(
        execute: _ => FetchLlmModelsAsync(),
        canExecute: _ => !IsFetchingModels
    );
}
```

### Service Implementation

#### Dependency Injection
```csharp
// Constructor injection pattern
public class MainViewModel
{
    private readonly IAudioRecorder _recorder;
    private readonly ITranscriptionService _transcriber;

    public MainViewModel(
        IAudioRecorder recorder, 
        ITranscriptionService transcriber)
    {
        _recorder = recorder;
        _transcriber = transcriber;
    }
}
```

#### Async Service Methods
```csharp
public interface ILlmProvider
{
    Task<bool> IsAvailableAsync();
    Task<bool> FetchModelsAsync();
    Task<string> EnhanceAsync(string text, EnhancementMode mode);
}

// Implementation
public class OllamaEnhancer : ILlmProvider
{
    public async Task<bool> IsAvailableAsync()
    {
        try
        {
            using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
            var response = await client.GetAsync($"{Endpoint}/api/tags");
            return response.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }
}
```

## Adding New Features

### Adding a New Export Format

1. **Add method to TranscriptExporter**:
```csharp
public static string ExportToCustomFormat(IEnumerable<TranscriptSegment> segments)
{
    var sb = new StringBuilder();
    // Implementation
    return sb.ToString();
}
```

2. **Add command to MainViewModel**:
```csharp
public ICommand ExportCustomCommand { get; }

public MainViewModel()
{
    ExportCustomCommand = new RelayCommand(_ => ExportCustom(), _ => CanSave);
}

private void ExportCustom()
{
    if (Segments.Count == 0) return;
    
    try
    {
        var dialog = new System.Windows.Forms.SaveFileDialog
        {
            Filter = "Custom (*.custom)|*.custom|All Files (*.*)|*.*",
            DefaultExt = "custom",
            FileName = $"talkies_{DateTime.Now:yyyyMMdd_HHmmss}.custom"
        };

        if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK)
        {
            var content = TranscriptExporter.ExportToCustomFormat(Segments);
            TranscriptExporter.SaveToFile(dialog.FileName, content);
        }
    }
    catch (Exception ex)
    {
        Logger.Error($"Failed to export: {ex.Message}");
    }
}
```

3. **Add button to MainWindow.xaml**:
```xml
<Button Content="Export Custom" 
        Command="{Binding ExportCustomCommand}" 
        IsEnabled="{Binding CanSave}" 
        Height="32" 
        Padding="12,0"/>
```

### Adding a New LLM Provider

1. **Implement ILlmProvider**:
```csharp
public class CustomLlmProvider : ILlmProvider
{
    public string Endpoint { get; set; }
    public string SelectedModel { get; set; }
    public List<LlmModel> AvailableModels { get; private set; } = new();

    public async Task<bool> IsAvailableAsync()
    {
        // Check provider availability
    }

    public async Task<bool> FetchModelsAsync()
    {
        // Fetch and populate AvailableModels
    }

    public async Task<string> EnhanceAsync(string text, EnhancementMode mode)
    {
        // Perform text enhancement
    }
}
```

2. **Register in provider factory**:
```csharp
// In MainViewModel.FetchLlmModelsAsync()
if (SelectedLlmProvider == "Custom Provider")
{
    _currentLlmProvider = new CustomLlmProvider { Endpoint = LlmEndpoint };
}
```

3. **Add to UI provider dropdown**:
```csharp
public ObservableCollection<string> LlmProviders { get; } = new(
    new[] { "Ollama", "LM Studio", "Custom Provider" }
);
```

### Adding a New Enhancement Mode

1. **Add to EnhancementMode enum**:
```csharp
public enum EnhancementMode
{
    Grammar,
    Concise,
    Detailed,
    Creative,
    NewMode  // Add here
}
```

2. **Update provider implementations**:
```csharp
public async Task<string> EnhanceAsync(string text, EnhancementMode mode)
{
    var prompt = mode switch
    {
        EnhancementMode.Grammar => "Fix grammar and spelling",
        EnhancementMode.Concise => "Make concise",
        EnhancementMode.Detailed => "Add detail",
        EnhancementMode.Creative => "Rephrase creatively",
        EnhancementMode.NewMode => "Your prompt here",
        _ => "Enhance text"
    };
    // Execute with prompt
}
```

3. **UI automatically updates** via:
```csharp
public ObservableCollection<string> EnhancementModes { get; } = 
    new(Enum.GetNames(typeof(EnhancementMode)));
```

## Testing

### Unit Testing Structure
```csharp
[TestFixture]
public class TranscriptExporterTests
{
    [Test]
    public void ExportToSrt_WithSegments_ReturnsValidSrt()
    {
        // Arrange
        var segments = new List<TranscriptSegment>
        {
            new() { Text = "Hello", Start = 0, End = 2 }
        };

        // Act
        var result = TranscriptExporter.ExportToSrt(segments);

        // Assert
        Assert.That(result, Does.Contain("1"));
        Assert.That(result, Does.Contain("00:00:00,000 --> 00:00:02,000"));
        Assert.That(result, Does.Contain("Hello"));
    }
}
```

### Integration Testing
```csharp
[TestFixture]
public class LlmProviderIntegrationTests
{
    [Test]
    [Ignore("Requires running Ollama instance")]
    public async Task OllamaProvider_IsAvailable_ReturnsTrue()
    {
        // Arrange
        var provider = new OllamaEnhancer("http://localhost:11434", "");

        // Act
        var available = await provider.IsAvailableAsync();

        // Assert
        Assert.That(available, Is.True);
    }
}
```

### Manual Testing Checklist
- [ ] Recording starts/stops correctly
- [ ] Transcription accuracy with different models
- [ ] LLM provider fetches models successfully
- [ ] Enhancement produces reasonable output
- [ ] Export files are created with correct format
- [ ] Settings persist across app restart
- [ ] Error dialogs appear for connection failures
- [ ] UI remains responsive during operations
- [ ] Hotkeys work from background

## Performance Considerations

### Audio Processing
- Waveform updates: Consider throttling to 20-30Hz if UI lag detected
- Recording buffer size: Balance between responsiveness and CPU usage
- Audio device enumeration: Cache results, refresh on demand only

### Transcription
- Model loading: Time varies by model size (tiny: 20ms, large: 5s+)
- Batch processing: Group segments for efficiency
- Memory usage: Monitor with larger audio files

### LLM Enhancement
- Network requests: Add timeout to prevent UI freezing
- Model size: Larger models = slower enhancement (10s to 1+ min)
- Batch enhancement: Could enhance multiple transcripts in queue

### UI Rendering
- ObservableCollection updates: Batch adds/clears for large collections
- Binding cycles: Avoid circular bindings
- Resource cleanup: Proper disposal of services in Dispose()

## Debugging Tips

### Enable Verbose Logging
```csharp
// In Logger.cs
public static void Verbose(string message)
{
    #if DEBUG
    Console.WriteLine($"[VERBOSE] {message}");
    #endif
}
```

### Trace Provider Calls
```csharp
private async Task<bool> FetchLlmModelsAsync()
{
    Logger.OperationStart("Fetching LLM models");
    Logger.Verbose($"Provider: {SelectedLlmProvider}");
    Logger.Verbose($"Endpoint: {LlmEndpoint}");
    
    // Operation code
    
    Logger.OperationComplete("LLM model fetch");
}
```

### Watch Variable Inspector
```csharp
// Add debug breakpoint and inspect
var segments = Segments.ToList(); // Easy to inspect in debugger
var modelNames = AvailableLlmModels.Select(m => m.Name).ToList();
```

## Build & Deployment

### Build Process
```bash
# Using UV as per CLAUDE.md
uv run dotnet build

# Run tests
uv run dotnet test

# Publish
uv run dotnet publish -c Release -o ./publish
```

### Dependencies Management
- All packages specified in `.csproj` file
- NuGet packages managed by Visual Studio or dotnet CLI
- Keep dependencies up-to-date for security

### Version Management
- Semantic versioning (major.minor.patch)
- Update version in `.csproj` file
- Document breaking changes in CHANGELOG

## Security Considerations

### User Data
- Settings stored locally in AppData
- No cloud transmission without explicit user consent
- Audio recordings not uploaded unless explicitly saved

### Network Security
- HTTPS preferred for LLM provider endpoints
- Validate certificate on HTTPS connections
- Timeout on slow connections
- User confirmation for non-local endpoints

### Code Security
- No hardcoded credentials or API keys
- Validate user input before API calls
- Escape special characters in text injection
- Handle exceptions securely (don't leak sensitive data)

## Resources & References

- **WPF Documentation**: https://learn.microsoft.com/en-us/dotnet/desktop/wpf/
- **NAudio Documentation**: https://github.com/naudio/NAudio
- **Whisper.NET**: https://github.com/sandrefsun/Whisper.Net
- **Ollama API**: https://github.com/jmorganca/ollama/blob/main/docs/api.md
- **OpenAI API**: https://platform.openai.com/docs/api-reference
- **MVVM Pattern**: https://learn.microsoft.com/en-us/archive/msdn-magazine/2009/february/patterns-wpf-apps-with-the-model-view-viewmodel-design-pattern
- **Async/Await**: https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/concepts/async/

## Contributing

### Code Review Checklist
- [ ] Follows naming conventions
- [ ] Proper error handling
- [ ] No hardcoded values
- [ ] Async/await properly used
- [ ] UI bindings correct
- [ ] No memory leaks (proper Dispose)
- [ ] Logged appropriately
- [ ] Documented public API
- [ ] Unit tests included
- [ ] No breaking changes

### Pull Request Process
1. Create feature branch from main
2. Implement feature with tests
3. Run full build and test suite
4. Update documentation
5. Submit PR with description
6. Address review feedback
7. Squash commits if requested
8. Merge after approval

## Project Roadmap

### Current Version (1.0)
- ✅ Audio recording and transcription
- ✅ Multiple export formats
- ✅ LLM enhancement with multiple providers
- ✅ Settings persistence
- ✅ Waveform visualization

### Future Enhancements (2.0)
- [ ] Custom provider plugin system
- [ ] Real-time transcription (streaming)
- [ ] Batch processing
- [ ] Cloud storage integration
- [ ] Advanced audio processing (noise cancellation)
- [ ] Language detection and automatic selection
- [ ] Customizable enhancement prompts

### Long-term Vision (3.0+)
- [ ] Web-based UI
- [ ] Mobile client
- [ ] Collaborative transcription
- [ ] AI model fine-tuning
- [ ] Enterprise deployment options

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Maintainer**: Talkies Development Team