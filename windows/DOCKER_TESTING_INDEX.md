# Docker Testing - Complete Documentation Index

This index helps you find the right documentation for your needs.

## I Want To...

### Get Started Quickly
- **[TESTING_QUICK_START.md](TESTING_QUICK_START.md)** - TL;DR guide with common commands

### Understand How It Works
- **[DOCKER_TESTING.md](DOCKER_TESTING.md)** - Comprehensive architecture and limitations

### Compare Testing Options
- **[TESTING_OPTIONS_COMPARISON.md](TESTING_OPTIONS_COMPARISON.md)** - Docker vs VM vs CI vs Wine

### Set Up for the First Time
- **[README_DOCKER.md](README_DOCKER.md)** - Installation and setup guide

### See What Was Created
- **[DOCKER_SETUP_SUMMARY.md](DOCKER_SETUP_SUMMARY.md)** - Implementation summary

---

## Documentation by Role

### Developer (Daily Use)
1. Start here: **[TESTING_QUICK_START.md](TESTING_QUICK_START.md)**
2. Keep handy: Common commands cheat sheet (see below)
3. Reference: **[README_DOCKER.md](README_DOCKER.md)** for troubleshooting

### Team Lead (Decision Making)
1. Read: **[TESTING_OPTIONS_COMPARISON.md](TESTING_OPTIONS_COMPARISON.md)**
2. Review: Cost analysis and decision matrix
3. Plan: Hybrid approach recommendation

### DevOps (CI/CD Setup)
1. Copy: **[.github-workflow-example.yml](.github-workflow-example.yml)** to `.github/workflows/`
2. Reference: **[DOCKER_TESTING.md](DOCKER_TESTING.md)** for GitHub Actions integration
3. Monitor: Test results in `TestResults/` directory

### New Team Member
1. Quick start: **[TESTING_QUICK_START.md](TESTING_QUICK_START.md)**
2. Install: Docker Desktop
3. Run: `./test-docker.sh`
4. Read: **[README_DOCKER.md](README_DOCKER.md)** for details

---

## Files Reference

### Executable Files
| File | Purpose | Usage |
|------|---------|-------|
| `test-docker.sh` | Main test script | `./test-docker.sh [command]` |
| `Makefile` | Make commands | `make test`, `make build` |

### Configuration Files
| File | Purpose | Edit? |
|------|---------|-------|
| `Dockerfile` | Docker image definition | Rarely (SDK version updates) |
| `docker-compose.yml` | Service orchestration | Rarely (add new services) |
| `.dockerignore` | Build exclusions | Rarely (exclude new patterns) |
| `.github-workflow-example.yml` | CI/CD template | Copy to `.github/workflows/` |

### Documentation Files
| File | Audience | Length |
|------|----------|--------|
| `TESTING_QUICK_START.md` | All developers | 2-3 min read |
| `README_DOCKER.md` | New users | 5-7 min read |
| `DOCKER_TESTING.md` | Deep dive | 15-20 min read |
| `TESTING_OPTIONS_COMPARISON.md` | Decision makers | 10-15 min read |
| `DOCKER_SETUP_SUMMARY.md` | Technical review | 5-8 min read |
| `DOCKER_TESTING_INDEX.md` | Navigation (this file) | 2 min read |

---

## Quick Command Reference

### Using test-docker.sh (Recommended)
```bash
./test-docker.sh           # Run tests
./test-docker.sh build     # Build project
./test-docker.sh restore   # Restore dependencies
./test-docker.sh shell     # Interactive shell
./test-docker.sh clean     # Clean up Docker
./test-docker.sh help      # Show help
```

### Using Makefile (Alternative)
```bash
make test                  # Run tests
make build                 # Build project
make shell                 # Interactive shell
make clean                 # Clean up
make help                  # Show all commands
```

### Using docker-compose Directly (Advanced)
```bash
docker-compose run --rm test     # Run tests
docker-compose run --rm build    # Build project
docker-compose run --rm shell    # Interactive shell
docker-compose down --rmi all    # Full cleanup
```

---

## Common Workflows

### Daily Development
```bash
# 1. Make code changes
vim Talkies.Windows/ViewModels/MainViewModel.cs

# 2. Run tests (fast)
./test-docker.sh

# 3. Commit if passing
git commit -am "feat: your feature"
```

### First Time Setup
```bash
# 1. Install Docker Desktop
# Download: https://www.docker.com/products/docker-desktop

# 2. Start Docker Desktop

# 3. Test it works
cd windows  # from repository root
./test-docker.sh
```

### Troubleshooting
```bash
# Docker not running?
# -> Start Docker Desktop

# Tests failing?
# -> Check test output in console

# Build issues?
# -> Rebuild without cache
BUILD_CACHE=false ./test-docker.sh

# Still broken?
# -> Open shell and investigate
./test-docker.sh shell
# Inside shell: dotnet build --verbosity diagnostic
```

### CI/CD Setup
```bash
# 1. Copy workflow template
cp .github-workflow-example.yml ../.github/workflows/windows-tests.yml

# 2. Commit
git add ../.github/workflows/windows-tests.yml
git commit -m "ci: add Windows testing workflow"

# 3. Push
git push

# 4. Check GitHub Actions tab
```

---

## Key Concepts

### What Works ✅
- ViewModel unit tests
- Service layer tests
- Business logic tests
- Mock/fake implementations
- File I/O operations
- Configuration management

### What Doesn't Work ❌
- WPF UI rendering
- Windows audio APIs (NAudio)
- Windows TTS
- Keyboard hooks
- Platform-specific clipboard
- Actual hardware access

### Why Use Docker?
- Fast feedback (10-30s)
- No Windows needed
- Free solution
- Consistent environment
- Works for ~80% of tests

### When to Use Alternatives?
- **GitHub Actions**: CI/CD, 100% coverage
- **Windows VM**: UI testing, debugging
- **Split Projects**: Large test suites

---

## Architecture Overview

```
┌─────────────────────────────────────────┐
│ macOS Development Machine               │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ Docker Desktop                    │  │
│  │                                   │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │ Linux Container             │  │  │
│  │  │                             │  │  │
│  │  │  .NET SDK 8.0               │  │  │
│  │  │  ├─ Build                   │  │  │
│  │  │  ├─ Restore                 │  │  │
│  │  │  └─ Test (xUnit)            │  │  │
│  │  │                             │  │  │
│  │  │  Mounted Volumes:           │  │  │
│  │  │  └─ /app ← windows/         │  │  │
│  │  └─────────────────────────────┘  │  │
│  │                                   │  │
│  │  Output:                          │  │
│  │  └─ TestResults/ ← Host machine  │  │
│  └───────────────────────────────────┘  │
│                                         │
│  Run via:                               │
│  └─ ./test-docker.sh                    │
└─────────────────────────────────────────┘
```

---

## Support & Resources

### Documentation Priority
1. **Just want to run tests?** → [TESTING_QUICK_START.md](TESTING_QUICK_START.md)
2. **Setting up for first time?** → [README_DOCKER.md](README_DOCKER.md)
3. **Need to understand limitations?** → [DOCKER_TESTING.md](DOCKER_TESTING.md)
4. **Choosing between approaches?** → [TESTING_OPTIONS_COMPARISON.md](TESTING_OPTIONS_COMPARISON.md)
5. **Reviewing the implementation?** → [DOCKER_SETUP_SUMMARY.md](DOCKER_SETUP_SUMMARY.md)

### External Resources
- [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop)
- [.NET 8.0 Documentation](https://learn.microsoft.com/en-us/dotnet/core/whats-new/dotnet-8)
- [xUnit Documentation](https://xunit.net/)
- [GitHub Actions for .NET](https://docs.github.com/en/actions/automating-builds-and-tests/building-and-testing-net)

### Getting Help
1. Check relevant documentation file (see priority list above)
2. Look at troubleshooting section in README_DOCKER.md
3. Try rebuilding: `BUILD_CACHE=false ./test-docker.sh`
4. Open shell for investigation: `./test-docker.sh shell`

---

## What's Next?

### Immediate (First Run)
- [ ] Install Docker Desktop
- [ ] Run `./test-docker.sh`
- [ ] Verify tests pass

### Short Term (This Week)
- [ ] Set up GitHub Actions workflow
- [ ] Add CI badge to README
- [ ] Document team workflow

### Long Term (As Needed)
- [ ] Consider Windows VM for UI testing
- [ ] Split test projects if suite grows large
- [ ] Add code coverage reporting

---

## Summary

This Docker testing setup provides:

1. **Fast local testing** without Windows (10-30s)
2. **Zero cost** for business logic tests
3. **Easy setup** (10 minutes)
4. **Good coverage** (~80% of current tests)
5. **CI/CD ready** (GitHub Actions template included)

**Recommended approach:**
- Local development: Use Docker
- CI/CD: Use GitHub Actions
- Special needs: Add Windows VM as needed

Start with **[TESTING_QUICK_START.md](TESTING_QUICK_START.md)** and you'll be running tests in minutes!
