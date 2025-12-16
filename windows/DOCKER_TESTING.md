# Docker-based Testing for Windows .NET App on macOS

This document explains how to run the Talkies Windows .NET tests on macOS using Docker.

## Overview

The Talkies Windows application is built with .NET 8.0 targeting Windows (`net8.0-windows`) and uses WPF for UI. However, the test suite primarily tests business logic (ViewModels, Services) using fake/mock implementations, which means most tests can run on Linux containers without requiring Windows.

## Prerequisites

- **Docker Desktop** for Mac (download from https://www.docker.com/products/docker-desktop)
- Docker Desktop must be running before executing tests

## Quick Start

### Run Tests
```bash
cd windows  # from repository root
./test-docker.sh
```

### Other Commands
```bash
./test-docker.sh build      # Build the project
./test-docker.sh restore    # Restore dependencies
./test-docker.sh shell      # Open interactive shell
./test-docker.sh clean      # Clean up Docker resources
./test-docker.sh help       # Show help
```

### Using docker-compose Directly
```bash
# Run tests
docker-compose run --rm test

# Build project
docker-compose run --rm build

# Open shell for manual commands
docker-compose run --rm shell
```

## How It Works

### Architecture

1. **Dockerfile**: Uses Microsoft's official .NET 8.0 SDK image (`mcr.microsoft.com/dotnet/sdk:8.0`)
2. **docker-compose.yml**: Defines services for testing, building, restoring, and debugging
3. **test-docker.sh**: Convenience script that wraps Docker commands with nice output and error handling

### What Gets Tested

The Docker setup runs xUnit tests that cover:

- **MainViewModelTests**: ViewModel logic for recording, transcription, and UI state
- **PluginSettingsTests**: Settings persistence and plugin configuration

All tests use fake implementations (`FakeRecorder`, `FakeTranscriber`, `FakeDevices`) that don't depend on Windows-specific APIs.

### Volume Mounts

The `docker-compose.yml` mounts:
- Source code directories (for live updates)
- `TestResults/` directory (for test output files)

## Limitations

### What WILL Work ✅

- **Unit tests for business logic**: ViewModels, Services, Models
- **Tests using interfaces and mocks**: IAudioRecorder, ITranscriptionService, etc.
- **File I/O tests**: Reading/writing configuration, exporting transcripts
- **State management tests**: Plugin settings, app configuration
- **Algorithm tests**: Text processing, format conversion

### What WON'T Work ❌

1. **WPF UI Components**:
   - Cannot render WPF controls (WPF requires Windows)
   - No access to `System.Windows.Controls`, `System.Windows.Media`, etc.
   - Cannot test actual XAML rendering or visual tree

2. **Windows-Specific APIs**:
   - `NAudio` (audio recording): Requires Windows audio APIs
   - `System.Speech.Synthesis`: Windows-only TTS
   - `System.Management`: Windows Management Instrumentation (WMI)
   - Global keyboard hooks for hotkeys

3. **Platform Integration**:
   - Cannot test clipboard operations with `System.Windows.Clipboard`
   - Cannot test Windows Forms integration
   - Cannot test actual audio device enumeration

### Current Test Status

**Good news**: The existing test suite (`MainViewModelTests.cs`, `PluginSettingsTests.cs`) is well-designed and should run successfully in Docker because:

- Tests use fake/mock implementations of Windows-specific services
- No direct WPF component testing
- ViewModels are tested via their public interfaces
- File operations use standard .NET I/O (cross-platform)

## Alternative Testing Approaches

If Docker limitations become problematic, consider:

### 1. GitHub Actions (Recommended)

Run tests on Windows runners in CI/CD:

```yaml
name: Windows Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: 8.0.x
      - name: Restore dependencies
        run: dotnet restore
      - name: Build
        run: dotnet build --no-restore
      - name: Test
        run: dotnet test --no-build --verbosity normal
```

**Pros**: Real Windows environment, free for public repos
**Cons**: Slower feedback loop (CI takes time)

### 2. Windows VM (Parallels/VMware)

Run Windows in a VM on macOS:

```bash
# In Windows VM
cd path/to/talkies/windows
dotnet test
```

**Pros**: Full Windows environment, local testing
**Cons**: Expensive (license costs), resource-intensive

### 3. Wine + .NET

Attempt to run Windows .NET apps via Wine:

```bash
# Not recommended - complex setup, poor compatibility
```

**Pros**: No VM needed
**Cons**: Unreliable, many compatibility issues, not worth the effort

### 4. Separate Test Projects

Split tests into two projects:

- `Talkies.Windows.UnitTests.csproj`: Business logic (cross-platform)
- `Talkies.Windows.IntegrationTests.csproj`: Windows-only integration tests

```xml
<!-- UnitTests.csproj - runs on macOS via Docker -->
<TargetFramework>net8.0</TargetFramework>

<!-- IntegrationTests.csproj - runs on Windows only -->
<TargetFramework>net8.0-windows</TargetFramework>
<UseWPF>true</UseWPF>
```

**Pros**: Fast local testing of business logic, clear separation
**Cons**: Requires refactoring, maintaining two test projects

## Test Results Output

Test results are saved to `windows/TestResults/` (from repository root) with:

- TRX format (Visual Studio test results)
- Console output with detailed verbosity

You can view TRX files with:
- Visual Studio Code with "Test Explorer" extension
- Manual inspection (XML format)

## Troubleshooting

### Docker Not Running
```
Error: Docker daemon is not running
Please start Docker Desktop
```
**Solution**: Launch Docker Desktop application

### Build Errors
```
error MSB4236: The SDK 'Microsoft.NET.Sdk' specified could not be found
```
**Solution**: Rebuild without cache: `BUILD_CACHE=false ./test-docker.sh`

### Port Conflicts
```
Error: port is already allocated
```
**Solution**: This shouldn't happen (tests don't use ports), but run `./test-docker.sh clean` if needed

### Test Failures Due to Windows Dependencies

If tests fail with:
```
System.PlatformNotSupportedException: Operation is not supported on this platform
```

This indicates a test is calling Windows-specific APIs. Solutions:
1. Mock the Windows API call
2. Add platform detection: `if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))`
3. Move test to Windows-only test project

## Performance Notes

- **First run**: Slower (~2-3 minutes) - downloads .NET SDK image (~200MB)
- **Subsequent runs**: Fast (~10-30 seconds) - uses cached image
- **Build cache**: Enabled by default, disable with `BUILD_CACHE=false`

## Best Practices

1. **Run tests locally**: Use Docker for quick feedback during development
2. **Run full suite on CI**: Use GitHub Actions for comprehensive Windows testing
3. **Keep tests platform-agnostic**: Design tests to work cross-platform when possible
4. **Use dependency injection**: Makes mocking Windows-specific services easier

## Integration with Project Workflow

### During Development (macOS)
```bash
# Make code changes
# Run tests quickly
./test-docker.sh

# If tests pass, commit
git add .
git commit -m "feat: new feature"
```

### Before Merging (CI/CD)
```bash
# GitHub Actions runs full Windows test suite
# Catches Windows-specific issues
# Blocks merge if tests fail
```

## Conclusion

Docker provides a **good enough** solution for testing Talkies Windows business logic on macOS:

- Fast local feedback loop
- No Windows license needed
- Works for ~80% of current tests
- Should be supplemented with GitHub Actions for full coverage

For true end-to-end Windows testing including UI, audio, and platform integration, use GitHub Actions with Windows runners as the source of truth.
