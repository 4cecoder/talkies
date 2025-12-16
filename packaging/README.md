# Talkies Packaging

This directory contains packaging configuration and scripts for building distributable releases of Talkies across all supported platforms.

## Directory Structure

```
packaging/
├── README.md           # This file - packaging overview and documentation
├── macos/              # macOS-specific packaging (DMG, app bundle, notarization)
├── windows/            # Windows-specific packaging (MSI, installer, code signing)
└── shared/
    └── version.txt     # Single source of truth for application version
```

## Version Management

The application version is stored in `shared/version.txt` and serves as the single source of truth across all platforms. This ensures consistency in:

- GitHub release tags
- Application bundles and installers
- CI/CD workflows
- Platform-specific manifests

**Current Version**: See [`shared/version.txt`](./shared/version.txt)

### Updating the Version

1. Edit `shared/version.txt` with the new version number (semver format: `MAJOR.MINOR.PATCH`)
2. Commit the change
3. Create and push a git tag matching the version:
   ```bash
   VERSION=$(cat packaging/shared/version.txt)
   git tag -a "v$VERSION" -m "Release v$VERSION"
   git push origin "v$VERSION"
   ```
4. The GitHub Actions release workflow will automatically trigger

## Quick Start

### macOS

**Prerequisites**:
- macOS 15+ (Sequoia or later)
- Swift 6.0+
- Xcode Command Line Tools

**Build Release Binary**:
```bash
cd mac
swift build -c release
```

**Create Distribution Package**:
```bash
cd packaging/macos
./build.sh  # See macos/README.md for details (to be created)
```

**Output**: `.dmg` installer with notarized app bundle

### Windows

**Prerequisites**:
- Windows 10/11
- .NET 8.0 SDK
- (Optional) Inno Setup for installer creation
- (Optional) Code signing certificate

**Build Release Package** (all-in-one):
```powershell
cd packaging/windows
.\build-installer.ps1
```

This will:
- Build self-contained .NET 8 application
- Create single-file executable (~150MB with runtime)
- Optionally create Inno Setup installer
- Optionally code sign with traditional or Azure Trusted Signing
- Generate checksums and organize output

**Quick Build** (unsigned):
```powershell
.\build-installer.ps1
```

**Build with Signing**:
```powershell
# With traditional certificate
.\build-installer.ps1 -SigningCertificate "cert.pfx" -CertificatePassword "pass"

# With Azure Trusted Signing
.\build-installer.ps1 -UseAzureTrustedSigning -AzureMetadataFile "config\azure.json"
```

**Output**:
- `Talkies-1.0.0-win-x64.exe` - Standalone executable with embedded runtime
- `Talkies-Setup-1.0.0-win-x64.exe` - Inno Setup installer (if configured)

### Linux (Future)

Linux packaging will be added when the Tauri-based Linux application reaches production readiness. Planned formats:
- AppImage (universal)
- .deb (Debian/Ubuntu)
- .rpm (Fedora/RHEL)
- Flatpak (Flathub)

## CI/CD Integration

### GitHub Actions Release Workflow

The automated release workflow (`.github/workflows/release.yml`) handles:

1. **Version Detection**: Reads version from `packaging/shared/version.txt`
2. **Parallel Builds**: Builds macOS and Windows release binaries in parallel
3. **Artifact Creation**: Packages platform-specific installers/bundles
4. **GitHub Release**: Creates a release with all artifacts attached

**Trigger**: Push a git tag matching `v*` (e.g., `v0.1.0`)

**Workflow Steps**:
```
Tag Push (v*) → Read Version → Build macOS + Windows (parallel)
                                      ↓
                              Upload Artifacts
                                      ↓
                              Create GitHub Release
                                      ↓
                              Attach DMG + MSI
```

**Manual Trigger** (for testing):
```bash
gh workflow run release.yml
```

### Release Artifacts

Each GitHub release includes:

| Platform | Artifact | Format | Notes |
|----------|----------|--------|-------|
| macOS    | `Talkies-macOS-v{VERSION}.dmg` | DMG | Notarized app bundle for macOS 15+ |
| Windows  | `Talkies-Windows-v{VERSION}.msi` | MSI | Self-contained installer with .NET runtime |

### Environment Variables

The following secrets/variables are used in CI:

| Secret | Purpose | Required For |
|--------|---------|--------------|
| `GITHUB_TOKEN` | Create releases and upload assets | All workflows |
| `APPLE_DEVELOPER_ID` | Code signing certificate | macOS notarization (future) |
| `APPLE_TEAM_ID` | Apple Developer Team ID | macOS notarization (future) |
| `WINDOWS_CERT_PASSWORD` | Code signing certificate password | Windows signing (future) |

## Platform-Specific Details

### macOS Packaging (`macos/`)

See [`macos/README.md`](./macos/README.md) for detailed documentation on:
- App bundle structure
- Code signing with Apple Developer ID
- Notarization process
- DMG creation and customization
- Universal binary support (Apple Silicon + Intel)

### Windows Packaging (`windows/`)

See [`windows/README.md`](./windows/README.md) for detailed documentation on:
- MSIX, WiX (MSI), and Inno Setup installer options
- Self-contained publishing with .NET 8 runtime
- Code signing with traditional certificates or Azure Trusted Signing
- Automated build scripts (PowerShell)
- GitHub Actions CI/CD integration
- Multi-architecture support (x64, ARM64, x86)

**Quick Start**: See [`windows/QUICKSTART.md`](./windows/QUICKSTART.md) to create your first installer in 10 minutes

## Development Workflow

### Testing Packaging Locally

Before pushing a release tag, test packaging locally:

**macOS**:
```bash
cd packaging/macos
./build.sh --test  # Creates unsigned DMG for testing
```

**Windows**:
```bash
cd packaging/windows
.\build.ps1 -Test  # Creates unsigned MSI for testing
```

### Versioning Strategy

Talkies follows [Semantic Versioning 2.0.0](https://semver.org/):

- **MAJOR**: Incompatible API/data format changes (e.g., settings migration required)
- **MINOR**: New features, backward-compatible
- **PATCH**: Bug fixes, backward-compatible

Examples:
- `0.1.0` - Initial beta release
- `0.2.0` - Added LLM enhancement features
- `0.2.1` - Fixed audio recording bug
- `1.0.0` - First stable release

### Pre-release Versions

For alpha/beta/rc releases, append a suffix:
- `0.1.0-alpha.1`
- `0.2.0-beta.2`
- `1.0.0-rc.1`

These will be marked as pre-releases in GitHub.

## Troubleshooting

### Release Workflow Fails

1. **Check version format**: Must be valid semver (e.g., `0.1.0`, not `v0.1.0`)
2. **Verify tag format**: Git tag must start with `v` (e.g., `v0.1.0`)
3. **Review build logs**: Check GitHub Actions logs for platform-specific errors
4. **Test locally**: Run packaging scripts on your development machine first

### Version Mismatch

If platform-specific manifests show different versions:

1. Update `packaging/shared/version.txt`
2. Sync platform manifests:
   - macOS: `Package.swift` (if applicable)
   - Windows: `Talkies.Windows.csproj` `<Version>` tag
3. Commit and re-tag

### Artifact Upload Issues

- Ensure artifact paths in `.github/workflows/release.yml` match actual output locations
- Check `retention-days` settings (currently 1 day for release artifacts)
- Verify `actions/upload-artifact` and `actions/download-artifact` versions are compatible

## Contributing

When adding new platforms or packaging features:

1. Create a platform-specific subdirectory (e.g., `linux/`)
2. Add a platform-specific `README.md` with detailed instructions
3. Update this main README with quick start steps
4. Add the platform to the release workflow (`.github/workflows/release.yml`)
5. Test the full release process end-to-end

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [macOS Code Signing Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [WiX Toolset Documentation](https://wixtoolset.org/docs/)
- [Semantic Versioning Specification](https://semver.org/)
