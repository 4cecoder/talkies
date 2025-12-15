# Quick Start: Testing Windows .NET App on macOS

## TL;DR

```bash
# One-time setup: Install Docker Desktop
# Download from: https://www.docker.com/products/docker-desktop

# Run tests
cd /Users/fource/bytecats/talkies/windows
./test-docker.sh
```

## Common Commands

```bash
# Run all tests
./test-docker.sh test

# Build the project
./test-docker.sh build

# Restore NuGet packages
./test-docker.sh restore

# Open interactive shell (for debugging)
./test-docker.sh shell

# Clean up Docker resources
./test-docker.sh clean
```

## What to Expect

### ✅ Will Work

- MainViewModel business logic tests
- Plugin settings persistence tests
- Service interface tests with mocks
- File I/O operations
- Configuration management

### ❌ Won't Work

- WPF UI rendering tests
- NAudio (audio recording) - requires Windows
- Windows Speech Synthesis
- Global keyboard hooks
- Windows-specific clipboard operations

## Current Test Suite Compatibility

**Good news!** The existing tests should work because:

1. `MainViewModelTests.cs` uses fake implementations:
   - `FakeRecorder` instead of real `NAudio`
   - `FakeTranscriber` instead of real `Whisper.net`
   - `FakeDevices` instead of real device enumeration

2. `PluginSettingsTests.cs` tests file-based settings:
   - Uses standard .NET File I/O (cross-platform)
   - No Windows-specific dependencies

## Workflow

### Local Development (macOS)
```bash
# 1. Make code changes
# 2. Run tests locally with Docker
./test-docker.sh

# 3. If tests pass, commit
git add .
git commit -m "your message"
```

### CI/CD (GitHub Actions)
- Push to GitHub
- Windows runner executes full test suite
- Catches Windows-specific issues
- See `.github-workflow-example.yml` for setup

## Troubleshooting

**Docker not running?**
```bash
# Start Docker Desktop app, then retry
./test-docker.sh
```

**Tests failing with PlatformNotSupportedException?**
- Test is calling Windows-specific API
- Add mocking or platform detection
- Or move to Windows-only test project

**Need to rebuild from scratch?**
```bash
BUILD_CACHE=false ./test-docker.sh
```

## Performance

- First run: ~2-3 minutes (downloads .NET image)
- Subsequent runs: ~10-30 seconds
- Much faster than booting a Windows VM!

## When to Use Each Approach

| Scenario | Tool | Why |
|----------|------|-----|
| Quick local testing | Docker | Fast, no Windows needed |
| Full integration tests | GitHub Actions | Real Windows environment |
| UI/WPF testing | Windows VM or CI | Requires actual Windows |
| Debugging Windows issues | Windows VM | Full platform access |

## Next Steps

1. **Try it**: Run `./test-docker.sh` and see the tests pass
2. **Set up CI**: Copy `.github-workflow-example.yml` to `.github/workflows/`
3. **Write more tests**: Focus on business logic that's platform-agnostic

## Questions?

See `DOCKER_TESTING.md` for comprehensive documentation including:
- Detailed architecture explanation
- Complete limitations list
- Alternative testing approaches
- Best practices and patterns
