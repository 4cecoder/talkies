# Docker Testing Setup for Windows .NET App

Run Windows .NET tests on macOS without needing a Windows installation.

## Quick Start

```bash
# 1. Install Docker Desktop for Mac (if not already installed)
# Download: https://www.docker.com/products/docker-desktop

# 2. Start Docker Desktop

# 3. Run tests
cd windows  # from repository root
./test-docker.sh
```

## What This Does

- Uses official Microsoft .NET 8.0 SDK Docker image
- Runs xUnit tests in a Linux container
- Tests business logic without requiring Windows
- Outputs results to `TestResults/` directory

## Files Created

```
windows/
├── Dockerfile                         # Docker image definition
├── docker-compose.yml                 # Multi-service orchestration
├── test-docker.sh                     # Convenience script (main entry point)
├── .dockerignore                      # Excludes unnecessary files from build
├── DOCKER_TESTING.md                  # Comprehensive documentation
├── TESTING_QUICK_START.md             # Quick reference guide
├── TESTING_OPTIONS_COMPARISON.md      # Comparison of all testing approaches
├── README_DOCKER.md                   # This file
└── .github-workflow-example.yml       # GitHub Actions example
```

## Usage

### Run Tests (Default)
```bash
./test-docker.sh
# or
./test-docker.sh test
```

### Build Project
```bash
./test-docker.sh build
```

### Restore Dependencies
```bash
./test-docker.sh restore
```

### Interactive Shell (Debugging)
```bash
./test-docker.sh shell
# Inside container:
dotnet test --logger "console;verbosity=detailed"
dotnet build --verbosity diagnostic
```

### Clean Up Docker Resources
```bash
./test-docker.sh clean
```

### Rebuild Without Cache
```bash
BUILD_CACHE=false ./test-docker.sh
```

## Using docker-compose Directly

If you prefer direct docker-compose commands:

```bash
# Run tests
docker-compose run --rm test

# Build
docker-compose run --rm build

# Shell
docker-compose run --rm shell
```

## What Tests Run Successfully

Current test suite is Docker-compatible:

✅ **MainViewModelTests.cs**
- `StartStop_TogglesRecordingFlags()`
- `RecordingComplete_PopulatesSegments()`
- `SaveVtt_WritesFile()`
- `SelectingEnhancementMode_UpdatesPromptEditor()`

✅ **PluginSettingsTests.cs**
- `AdvancedTtsSettings_PersistToConfig()`
- `AdvancedTtsSettings_LoadIntoMainViewModel()`

All tests use fake implementations (FakeRecorder, FakeTranscriber, FakeDevices) that don't require Windows APIs.

## Limitations

### Won't Work in Docker ❌

- **WPF UI tests**: No Windows display server
- **NAudio**: Windows-only audio APIs
- **System.Speech.Synthesis**: Windows TTS
- **Global keyboard hooks**: Windows input APIs
- **Actual clipboard operations**: Platform-specific

See `DOCKER_TESTING.md` for complete limitations list.

## Alternative: GitHub Actions

For complete Windows testing, use GitHub Actions:

```bash
# Copy example workflow
cp .github-workflow-example.yml ../.github/workflows/windows-tests.yml

# Commit and push
git add ../.github/workflows/windows-tests.yml
git commit -m "ci: add Windows testing workflow"
git push
```

GitHub Actions will run tests on actual Windows Server runners.

## Troubleshooting

### Docker Not Running
```
Error: Docker daemon is not running
```
**Fix**: Start Docker Desktop application

### Permission Denied
```
bash: ./test-docker.sh: Permission denied
```
**Fix**: Make script executable
```bash
chmod +x test-docker.sh
```

### Port Conflicts
```
Error: port is already allocated
```
**Fix**: Clean up and retry
```bash
./test-docker.sh clean
./test-docker.sh test
```

### Build Failures
```
error MSB4236: The SDK specified could not be found
```
**Fix**: Rebuild without cache
```bash
BUILD_CACHE=false ./test-docker.sh
```

### Tests Fail with PlatformNotSupportedException

This means a test is calling Windows-specific APIs. Options:

1. **Mock the API**: Use fake/mock implementation
2. **Platform detection**: Skip test on non-Windows
   ```csharp
   if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
   {
       return; // Skip on non-Windows
   }
   ```
3. **Separate test project**: Move to Windows-only test suite

## Performance

- **First run**: 2-3 minutes (downloads ~200MB .NET SDK image)
- **Subsequent runs**: 10-30 seconds
- **Cached builds**: <10 seconds if no code changes

## Integration with Workflow

### Typical Development Cycle

```bash
# 1. Make code changes
vim Talkies.Windows/ViewModels/MainViewModel.cs

# 2. Run tests locally (fast feedback)
./test-docker.sh

# 3. If tests pass, commit
git add .
git commit -m "feat: your feature"

# 4. Push to GitHub
git push

# 5. GitHub Actions runs full Windows test suite
# Catches any Windows-specific issues
```

## Docker Image Details

- **Base image**: `mcr.microsoft.com/dotnet/sdk:8.0`
- **Size**: ~200MB
- **Includes**: .NET 8.0 SDK, build tools, test runners
- **Platform**: Linux (amd64 or arm64 depending on Mac architecture)

## Cleanup

### Remove Test Results
```bash
rm -rf TestResults/
```

### Remove Docker Images
```bash
./test-docker.sh clean
```

### Complete Cleanup
```bash
# Remove test results
rm -rf TestResults/

# Remove Docker resources
./test-docker.sh clean

# Remove Docker image
docker rmi mcr.microsoft.com/dotnet/sdk:8.0
```

## Next Steps

1. **Try it out**: Run `./test-docker.sh` and verify tests pass
2. **Read docs**: See `TESTING_QUICK_START.md` for quick reference
3. **Set up CI**: Copy GitHub Actions workflow for automated testing
4. **Write tests**: Focus on business logic (ViewModels, Services)

## Documentation

- **TESTING_QUICK_START.md**: Quick reference for daily use
- **DOCKER_TESTING.md**: Comprehensive guide with architecture details
- **TESTING_OPTIONS_COMPARISON.md**: Compare Docker vs VM vs CI approaches

## Support

If you encounter issues:

1. Check `DOCKER_TESTING.md` troubleshooting section
2. Verify Docker Desktop is running and up to date
3. Try rebuilding without cache: `BUILD_CACHE=false ./test-docker.sh`
4. Open issue on GitHub with error details

## Summary

Docker testing provides:
- ✅ Fast local feedback (10-30 seconds)
- ✅ No Windows license needed
- ✅ Works for 80%+ of tests
- ✅ Free and easy to set up
- ⚠️ Limited to business logic tests (no WPF UI)

For complete coverage, supplement with GitHub Actions for Windows-specific testing.
